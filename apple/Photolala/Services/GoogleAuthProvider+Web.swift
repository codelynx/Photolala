//
//  GoogleAuthProvider+Web.swift
//  Photolala
//
//  Web-based authentication fallback for Google Sign-In
//

import Foundation
import AuthenticationServices

extension GoogleAuthProvider {
	/// Store the current authentication session to keep it alive
	private static var currentAuthSession: ASWebAuthenticationSession?
	
	/// Store the current OAuth state for verification
	private static var currentOAuthState: String?
	
	/// Store the continuation for the OAuth flow
	private static var oauthContinuation: CheckedContinuation<AuthCredential, Error>?
	
	/// Use web-based OAuth flow as fallback when native SDK fails
	func signInWithWebFlow() async throws -> AuthCredential {
		
		// OAuth 2.0 parameters
		let clientID = GoogleOAuthConfiguration.clientID
		let redirectURI = GoogleOAuthConfiguration.redirectURI
		let responseType = "code"
		let scope = "openid profile email"
		
		// Generate state for security
		let state = UUID().uuidString
		
		// Build authorization URL
		var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
		components.queryItems = [
			URLQueryItem(name: "client_id", value: clientID),
			URLQueryItem(name: "redirect_uri", value: redirectURI),
			URLQueryItem(name: "response_type", value: responseType),
			URLQueryItem(name: "scope", value: scope),
			URLQueryItem(name: "state", value: state),
			URLQueryItem(name: "access_type", value: "offline")
			// Removed prompt=select_account to avoid forcing account selection
		]
		
		guard let authURL = components.url else {
			throw AuthError.unknownError("Failed to build authorization URL")
		}
		
		
		#if os(macOS)
		// On macOS, ASWebAuthenticationSession has issues opening the browser
		// Use direct browser opening instead
		return try await withCheckedThrowingContinuation { continuation in
			// Store the state and continuation for callback handling
			GoogleAuthProvider.currentOAuthState = state
			GoogleAuthProvider.oauthContinuation = continuation
			
			// Open the OAuth URL in the default browser
			Task { @MainActor in
				NSWorkspace.shared.open(authURL)
			}
		}
		#else
		// On iOS, use ASWebAuthenticationSession which works reliably
		return try await withCheckedThrowingContinuation { continuation in
			Task { @MainActor in
				let session = ASWebAuthenticationSession(
					url: authURL,
					callbackURLScheme: redirectURI.components(separatedBy: ":").first!
				) { callbackURL, error in
					// Clear the stored session
					GoogleAuthProvider.currentAuthSession = nil
					if let error = error {
							continuation.resume(throwing: AuthError.authenticationFailed(reason: error.localizedDescription))
						return
					}
					
					guard let callbackURL = callbackURL else {
						continuation.resume(throwing: AuthError.unknownError("No callback URL"))
						return
					}
					
					
					// Extract authorization code from callback
					guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
						  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
						continuation.resume(throwing: AuthError.unknownError("No authorization code in callback"))
						return
					}
					
					// Exchange code for tokens
					Task {
						do {
							let credential = try await self.exchangeCodeForTokens(code: code, clientID: clientID, redirectURI: redirectURI)
							continuation.resume(returning: credential)
						} catch {
							continuation.resume(throwing: error)
						}
					}
				}
				
				session.prefersEphemeralWebBrowserSession = true
				
				// Store the session to keep it alive
				GoogleAuthProvider.currentAuthSession = session
				
				let started = session.start()
				
				if !started {
					GoogleAuthProvider.currentAuthSession = nil
					continuation.resume(throwing: AuthError.unknownError("Failed to start authentication session"))
				}
			}
		}
		#endif
	}
	
	/// Exchange authorization code for tokens
	private func exchangeCodeForTokens(code: String, clientID: String, redirectURI: String) async throws -> AuthCredential {
		
		let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
		var request = URLRequest(url: tokenURL)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		
		// Token request parameters
		let parameters = [
			"code": code,
			"client_id": clientID,
			"client_secret": "", // Not required for installed apps
			"redirect_uri": redirectURI,
			"grant_type": "authorization_code"
		]
		
		let bodyString = parameters
			.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
			.joined(separator: "&")
		
		request.httpBody = bodyString.data(using: .utf8)
		
		let (data, _) = try await URLSession.shared.data(for: request)
		
		// Parse token response
		guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let idToken = json["id_token"] as? String else {
			throw AuthError.unknownError("Failed to parse token response")
		}
		
		// Decode ID token to get user info
		let userInfo = try decodeJWT(idToken)
		
		
		return AuthCredential(
			provider: .google,
			providerID: userInfo["sub"] as? String ?? "",
			email: userInfo["email"] as? String,
			fullName: userInfo["name"] as? String,
			photoURL: userInfo["picture"] as? String,
			idToken: idToken,
			accessToken: json["access_token"] as? String
		)
	}
	
	/// Decode JWT token to extract user info
	private func decodeJWT(_ token: String) throws -> [String: Any] {
		let segments = token.components(separatedBy: ".")
		guard segments.count > 1 else {
			throw AuthError.unknownError("Invalid JWT format")
		}
		
		let base64 = segments[1]
			.replacingOccurrences(of: "-", with: "+")
			.replacingOccurrences(of: "_", with: "/")
		
		let padded = base64.padding(toLength: ((base64.count + 3) / 4) * 4,
									withPad: "=",
									startingAt: 0)
		
		guard let data = Data(base64Encoded: padded),
			  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			throw AuthError.unknownError("Failed to decode JWT")
		}
		
		return json
	}
	
	/// Handle OAuth callback URL
	static func handleOAuthCallback(_ url: URL) async {
		
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			oauthContinuation?.resume(throwing: AuthError.unknownError("Invalid callback URL"))
			oauthContinuation = nil
			currentOAuthState = nil
			return
		}
		
		// Verify state parameter
		let state = components.queryItems?.first(where: { $0.name == "state" })?.value
		guard state == currentOAuthState else {
			oauthContinuation?.resume(throwing: AuthError.unknownError("OAuth state mismatch"))
			oauthContinuation = nil
			currentOAuthState = nil
			return
		}
		
		// Extract authorization code
		guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
			oauthContinuation?.resume(throwing: AuthError.unknownError("No authorization code in callback"))
			oauthContinuation = nil
			currentOAuthState = nil
			return
		}
		
		
		// Exchange code for tokens
		do {
			let credential = try await GoogleAuthProvider.shared.exchangeCodeForTokens(
				code: code,
				clientID: GoogleOAuthConfiguration.clientID,
				redirectURI: GoogleOAuthConfiguration.redirectURI
			)
			
			oauthContinuation?.resume(returning: credential)
		} catch {
			oauthContinuation?.resume(throwing: error)
		}
		
		// Clean up
		oauthContinuation = nil
		currentOAuthState = nil
	}
}


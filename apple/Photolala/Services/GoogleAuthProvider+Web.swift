//
//  GoogleAuthProvider+Web.swift
//  Photolala
//
//  Web-based authentication fallback for Google Sign-In
//

import Foundation
import AuthenticationServices

extension GoogleAuthProvider {
	/// Use web-based OAuth flow as fallback when native SDK fails
	func signInWithWebFlow() async throws -> AuthCredential {
		print("[GoogleAuthProvider] Starting web-based authentication flow")
		
		// OAuth 2.0 parameters
		let clientID = "105828093997-m35e980noaks5ahke5ge38q76rgq2bik.apps.googleusercontent.com"
		let redirectURI = "com.googleusercontent.apps.105828093997-m35e980noaks5ahke5ge38q76rgq2bik:/oauth2redirect"
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
		
		print("[GoogleAuthProvider] Opening web authentication with URL: \(authURL)")
		
		// Use ASWebAuthenticationSession for the OAuth flow
		return try await withCheckedThrowingContinuation { continuation in
			Task { @MainActor in
				let session = ASWebAuthenticationSession(
					url: authURL,
					callbackURLScheme: "com.googleusercontent.apps.105828093997-m35e980noaks5ahke5ge38q76rgq2bik"
				) { callbackURL, error in
					if let error = error {
						print("[GoogleAuthProvider] Web auth error: \(error)")
						continuation.resume(throwing: AuthError.authenticationFailed(reason: error.localizedDescription))
						return
					}
					
					guard let callbackURL = callbackURL else {
						continuation.resume(throwing: AuthError.unknownError("No callback URL"))
						return
					}
					
					print("[GoogleAuthProvider] Received callback URL: \(callbackURL)")
					
					// Extract authorization code from callback
					guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
						  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
						continuation.resume(throwing: AuthError.unknownError("No authorization code in callback"))
						return
					}
					
					// Exchange code for tokens
					Task {
						do {
							let credential = try await self.exchangeCodeForTokens(code: code, redirectURI: redirectURI)
							continuation.resume(returning: credential)
						} catch {
							continuation.resume(throwing: error)
						}
					}
				}
				
				#if os(macOS)
				let context = GoogleAuthPresentationContext()
				session.presentationContextProvider = context
				#endif
				
				session.prefersEphemeralWebBrowserSession = true
				session.start()
			}
		}
	}
	
	/// Exchange authorization code for tokens
	private func exchangeCodeForTokens(code: String, redirectURI: String) async throws -> AuthCredential {
		print("[GoogleAuthProvider] Exchanging authorization code for tokens")
		
		let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
		var request = URLRequest(url: tokenURL)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		
		// Token request parameters
		let parameters = [
			"code": code,
			"client_id": "105828093997-m35e980noaks5ahke5ge38q76rgq2bik.apps.googleusercontent.com",
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
		
		print("[GoogleAuthProvider] Successfully obtained user info from web flow")
		
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
}

#if os(macOS)
// Helper class for presentation context
@MainActor
class GoogleAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
	func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first!
	}
}
#endif
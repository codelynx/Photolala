//
//  GoogleSignInCoordinator.swift
//  Photolala
//
//  Manages Google OAuth 2.0 sign-in flow with PKCE and nonce
//

import Foundation
import AuthenticationServices
import CryptoKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Actor that coordinates the Google Sign-In flow
actor GoogleSignInCoordinator {
	// MARK: - State
	private var currentState: String?
	private var currentCodeVerifier: String?
	private var currentNonce: String?
	private var authContinuation: CheckedContinuation<URL, Error>?

	// Session must be stored on MainActor since ASWebAuthenticationSession is MainActor-isolated
	@MainActor
	private static var currentAuthSession: ASWebAuthenticationSession?

	// For browser fallback on macOS - also MainActor-isolated for thread safety
	@MainActor
	private static var browserContinuation: CheckedContinuation<URL, Error>?
	@MainActor
	private static var browserState: String?
	@MainActor
	private static var isSignInInProgress = false

	// MARK: - Public Methods

	/// Performs the complete Google Sign-In flow
	func performSignIn() async throws -> GoogleCredential {
		// 1. Generate PKCE parameters
		let codeVerifier = generateCodeVerifier()
		let codeChallenge = generateCodeChallenge(from: codeVerifier)

		// 2. Generate state for CSRF protection
		let state = UUID().uuidString

		// 3. Generate nonce for replay protection
		let nonce = randomNonceString()

		// Store state for verification
		currentState = state
		currentCodeVerifier = codeVerifier
		currentNonce = nonce

		// 4. Build authorization URL with PKCE and nonce
		let authEndpoint = GoogleOAuthConfiguration.authorizationEndpoint
		guard var components = URLComponents(string: authEndpoint) else {
			throw GoogleSignInError.invalidAuthorizationResponse
		}

		let clientID = GoogleOAuthConfiguration.clientID
		let redirectURI = GoogleOAuthConfiguration.redirectURI
		let scopes = GoogleOAuthConfiguration.scopes

		components.queryItems = [
			URLQueryItem(name: "client_id", value: clientID),
			URLQueryItem(name: "redirect_uri", value: redirectURI),
			URLQueryItem(name: "response_type", value: "code"),
			URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
			URLQueryItem(name: "state", value: state),
			URLQueryItem(name: "code_challenge", value: codeChallenge),
			URLQueryItem(name: "code_challenge_method", value: "S256"),
			URLQueryItem(name: "nonce", value: nonce),
			URLQueryItem(name: "access_type", value: "offline"),
			URLQueryItem(name: "prompt", value: "select_account")
		]

		guard let authURL = components.url else {
			throw GoogleSignInError.invalidAuthorizationResponse
		}

		// 5. Present authentication session
		let callbackURL = try await presentAuthenticationSession(url: authURL)

		// 6. Parse callback and verify state
		guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
			throw GoogleSignInError.invalidAuthorizationResponse
		}

		// Verify state to prevent CSRF
		let queryState = components.queryItems?.first(where: { $0.name == "state" })?.value
		guard queryState == currentState else {
			throw GoogleSignInError.stateMismatch
		}

		// Check for errors
		if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
			if error == "access_denied" {
				throw GoogleSignInError.userCancelled
			}
			throw GoogleSignInError.tokenExchangeFailed(error)
		}

		// Extract authorization code
		guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
			throw GoogleSignInError.noAuthorizationCode
		}

		// 7. Exchange code for tokens using stored code verifier
		guard let storedCodeVerifier = currentCodeVerifier else {
			throw GoogleSignInError.invalidAuthorizationResponse
		}

		let tokens = try await exchangeCodeForTokens(
			code: code,
			codeVerifier: storedCodeVerifier
		)

		// 8. Verify ID token with nonce check
		guard let storedNonce = currentNonce else {
			throw GoogleSignInError.invalidAuthorizationResponse
		}

		let verifiedToken = try await verifyIDToken(
			tokens.idToken,
			expectedNonce: storedNonce
		)

		// Clear state after successful flow
		currentState = nil
		currentCodeVerifier = nil
		currentNonce = nil

		// 9. Return credential
		return GoogleCredential(
			idToken: verifiedToken.idToken,
			accessToken: tokens.accessToken,
			claims: verifiedToken.claims
		)
	}

	// MARK: - Private Methods

	private func presentAuthenticationSession(url: URL) async throws -> URL {
		#if os(macOS)
		// On macOS, try ASWebAuthenticationSession first, fall back to browser if it fails
		// First check if we should just use browser fallback directly
		let useBrowserFallback = true // ASWebAuthenticationSession is unreliable on macOS

		if useBrowserFallback {
			// Skip ASWebAuthenticationSession entirely and use browser
			print("=========================================")
			print("[GoogleSignIn] Using browser fallback for macOS")
			print("[GoogleSignIn] State: \(self.currentState ?? "nil")")
			print("=========================================")

			return try await withCheckedThrowingContinuation { continuation in
				Task { @MainActor in
					// Check if sign-in is already in progress
					if Self.isSignInInProgress {
						print("[GoogleSignIn] ⚠️ Sign-in already in progress, ignoring duplicate request")
						continuation.resume(throwing: GoogleSignInError.userCancelled)
						return
					}

					// Mark sign-in as in progress
					Self.isSignInInProgress = true

					// Store state for browser-based flow
					await Self.storeBrowserState(self.currentState, continuation: continuation)

					// Open in default browser
					print("[GoogleSignIn] Opening URL in default browser...")
					print("[GoogleSignIn] URL starts with: \(String(url.absoluteString.prefix(100)))...")
					let opened = NSWorkspace.shared.open(url)
					print("[GoogleSignIn] Browser open result: \(opened)")

					if !opened {
						print("[GoogleSignIn] ❌ Failed to open browser")
						Self.isSignInInProgress = false
						continuation.resume(throwing: GoogleSignInError.webAuthenticationUnavailable)
						return
					}

					print("[GoogleSignIn] Waiting for OAuth callback...")
					// The continuation will be resumed when handleOAuthCallback is called
				}
			}
		} else {
			// Legacy path - kept for reference but not used
			return try await withCheckedThrowingContinuation { continuation in
				Task { @MainActor in
					// First, store the continuation synchronously on the actor
					await self.storeAuthContinuation(continuation)

					// Now create and configure the session on MainActor
					let redirectURI = GoogleOAuthConfiguration.redirectURI
					let callbackScheme = redirectURI.components(separatedBy: ":").first
					let session = ASWebAuthenticationSession(
						url: url,
						callbackURLScheme: callbackScheme
					) { callbackURL, error in
						// Handle completion - this closure is called on an arbitrary queue
						// We need to handle it without assuming any particular executor
						if let error = error {
							if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
								Task {
									await self.finishAuthSession(result: .failure(GoogleSignInError.userCancelled))
								}
							} else {
								Task {
									await self.finishAuthSession(result: .failure(error))
								}
							}
						} else if let callbackURL = callbackURL {
							Task {
								await self.finishAuthSession(result: .success(callbackURL))
							}
						} else {
							Task {
								await self.finishAuthSession(result: .failure(GoogleSignInError.invalidAuthorizationResponse))
							}
						}
					}

					let preferEphemeral = GoogleOAuthConfiguration.preferEphemeralSession
					session.presentationContextProvider = MacAuthenticationPresentationContext.shared
					session.prefersEphemeralWebBrowserSession = preferEphemeral

					// Store the session before starting it (on MainActor)
					Self.currentAuthSession = session

					// Start the session and use browser fallback if it fails
					if !session.start() {
						// ASWebAuthenticationSession failed, use browser fallback
						Self.currentAuthSession = nil

						// Store state for browser-based flow
						await Self.storeBrowserState(self.currentState, continuation: continuation)

						// Open in default browser
						NSWorkspace.shared.open(url)

						// The continuation will be resumed when handleOAuthCallback is called
					}
				}
			}
		}
		#else
		// On iOS, use ASWebAuthenticationSession (works reliably)
		return try await withCheckedThrowingContinuation { continuation in
			Task { @MainActor in
				// First, store the continuation synchronously on the actor
				await self.storeAuthContinuation(continuation)

				// Now create and configure the session on MainActor
				let redirectURI = GoogleOAuthConfiguration.redirectURI
				let callbackScheme = redirectURI.components(separatedBy: ":").first
				let session = ASWebAuthenticationSession(
					url: url,
					callbackURLScheme: callbackScheme
				) { callbackURL, error in
					// Handle completion - this closure is called on an arbitrary queue
					// We need to handle it without assuming any particular executor
					if let error = error {
						if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
							Task {
								await self.finishAuthSession(result: .failure(GoogleSignInError.userCancelled))
							}
						} else {
							Task {
								await self.finishAuthSession(result: .failure(error))
							}
						}
					} else if let callbackURL = callbackURL {
						Task {
							await self.finishAuthSession(result: .success(callbackURL))
						}
					} else {
						Task {
							await self.finishAuthSession(result: .failure(GoogleSignInError.invalidAuthorizationResponse))
						}
					}
				}

				let preferEphemeral = GoogleOAuthConfiguration.preferEphemeralSession
				session.presentationContextProvider = IOSAuthenticationPresentationContext.shared
				session.prefersEphemeralWebBrowserSession = preferEphemeral

				// Store the session before starting it (on MainActor)
				Self.currentAuthSession = session

				// Start the session and handle failure through centralized method
				if !session.start() {
					await self.finishAuthSession(result: .failure(GoogleSignInError.webAuthenticationUnavailable))
				}
			}
		}
		#endif
	}

	private func storeAuthContinuation(_ continuation: CheckedContinuation<URL, Error>) {
		authContinuation = continuation
	}

	private func finishAuthSession(result: Result<URL, Error>) {
		// Get and immediately clear the continuation to prevent double-resume
		guard let continuation = authContinuation else { return }
		authContinuation = nil

		// Also clear the session on MainActor
		Task { @MainActor in
			Self.currentAuthSession = nil
		}

		// Now safe to resume the continuation
		switch result {
		case .success(let url):
			continuation.resume(returning: url)
		case .failure(let error):
			continuation.resume(throwing: error)
		}
	}

	private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> TokenResponse {
		let tokenEndpoint = GoogleOAuthConfiguration.tokenEndpoint
		var request = URLRequest(url: URL(string: tokenEndpoint)!)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

		let redirectURI = GoogleOAuthConfiguration.redirectURI
		let clientID = GoogleOAuthConfiguration.clientID

		let parameters = [
			"grant_type": "authorization_code",
			"code": code,
			"redirect_uri": redirectURI,
			"client_id": clientID,
			"code_verifier": codeVerifier
		]

		request.httpBody = formEncode(parameters).data(using: .utf8)

		let (data, response) = try await URLSession.shared.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse,
			  httpResponse.statusCode == 200 else {
			if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			   let error = errorData["error"] as? String {
				throw GoogleSignInError.tokenExchangeFailed(error)
			}
			throw GoogleSignInError.tokenExchangeFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
		}

		// Parse JSON manually to avoid Codable isolation issues
		guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let idToken = json["id_token"] as? String,
			  let accessToken = json["access_token"] as? String else {
			throw GoogleSignInError.tokenExchangeFailed("Invalid response format")
		}

		// Handle expires_in as either Int or floating-point NSNumber
		let expiresIn: Int
		if let expiresInInt = json["expires_in"] as? Int {
			expiresIn = expiresInInt
		} else if let expiresInNumber = json["expires_in"] as? NSNumber {
			expiresIn = expiresInNumber.intValue
		} else if let expiresInDouble = json["expires_in"] as? Double {
			expiresIn = Int(expiresInDouble)
		} else {
			// Default to 1 hour if not provided
			expiresIn = 3600
		}

		let refreshToken = json["refresh_token"] as? String

		return TokenResponse(
			idToken: idToken,
			accessToken: accessToken,
			refreshToken: refreshToken,
			expiresIn: expiresIn
		)
	}

	private func verifyIDToken(_ idToken: String, expectedNonce: String) async throws -> VerifiedToken {
		// Parse JWT components
		let parts = idToken.split(separator: ".")
		guard parts.count == 3 else {
			throw GoogleSignInError.invalidIDToken
		}

		// Decode header to get key ID
		guard let headerData = Data(base64URLEncoded: String(parts[0])),
			  let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
			  let keyID = header["kid"] as? String else {
			throw GoogleSignInError.missingKeyID
		}

		// Get public key from cache
		let publicKey = try await GooglePublicKeyCache.shared.getKey(for: keyID)

		// Verify signature
		let signedData = "\(parts[0]).\(parts[1])".data(using: .utf8)!
		guard let signatureData = Data(base64URLEncoded: String(parts[2])) else {
			throw GoogleSignInError.invalidSignature
		}

		// Create SecKey from public key data
		let attributes: [String: Any] = [
			kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
			kSecAttrKeyClass as String: kSecAttrKeyClassPublic
		]

		guard let secKey = SecKeyCreateWithData(publicKey as CFData, attributes as CFDictionary, nil) else {
			throw GoogleSignInError.invalidSignature
		}

		// Verify signature using SecKeyVerifySignature
		let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
		guard SecKeyVerifySignature(secKey, algorithm, signedData as CFData, signatureData as CFData, nil) else {
			throw GoogleSignInError.invalidSignature
		}

		// Decode and validate claims
		guard let payloadData = Data(base64URLEncoded: String(parts[1])),
			  let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
			throw GoogleSignInError.invalidIDToken
		}

		// Parse claims
		let claims = try parseGoogleClaims(from: payload)

		// Validate issuer
		guard claims.issuer == "https://accounts.google.com" || claims.issuer == "accounts.google.com" else {
			throw GoogleSignInError.invalidIssuer
		}

		// Validate audience (handle both string and array formats)
		// The ID token audience should match the client ID used in the auth request
		let clientID = GoogleOAuthConfiguration.clientID
		if let aud = payload["aud"] as? String {
			guard aud == clientID else {
				throw GoogleSignInError.invalidAudience
			}
		} else if let audArray = payload["aud"] as? [String] {
			guard audArray.contains(clientID) else {
				throw GoogleSignInError.invalidAudience
			}
		} else {
			throw GoogleSignInError.invalidAudience
		}

		// Validate expiration
		let now = Date()
		guard claims.expiration > now else {
			throw GoogleSignInError.tokenExpired
		}

		// Validate issued at (with 60 second tolerance)
		guard claims.issuedAt <= now.addingTimeInterval(60) else {
			throw GoogleSignInError.invalidIssuedAt
		}

		// Validate nonce
		guard claims.nonce == expectedNonce else {
			throw GoogleSignInError.nonceMismatch
		}

		return VerifiedToken(idToken: idToken, claims: claims)
	}

	private func parseGoogleClaims(from payload: [String: Any]) throws -> GoogleJWTClaims {
		guard let sub = payload["sub"] as? String,
			  let iss = payload["iss"] as? String,
			  let exp = payload["exp"] as? TimeInterval,
			  let iat = payload["iat"] as? TimeInterval else {
			throw GoogleSignInError.invalidIDToken
		}

		// Handle audience as either string or array
		let audience: String
		if let aud = payload["aud"] as? String {
			audience = aud
		} else if let audArray = payload["aud"] as? [String], !audArray.isEmpty {
			audience = audArray[0]  // Take first element for primary audience
		} else {
			throw GoogleSignInError.invalidAudience
		}

		return GoogleJWTClaims(
			subject: sub,
			email: payload["email"] as? String,
			emailVerified: payload["email_verified"] as? Bool,
			name: payload["name"] as? String,
			picture: payload["picture"] as? String,
			issuer: iss,
			audience: audience,
			expiration: Date(timeIntervalSince1970: exp),
			issuedAt: Date(timeIntervalSince1970: iat),
			nonce: payload["nonce"] as? String
		)
	}

	// MARK: - PKCE Helpers

	private func generateCodeVerifier() -> String {
		var buffer = [UInt8](repeating: 0, count: 32)
		_ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
		return Data(buffer).base64URLEncodedString()
	}

	private func generateCodeChallenge(from verifier: String) -> String {
		let data = verifier.data(using: .utf8)!
		let hash = SHA256.hash(data: data)
		return Data(hash).base64URLEncodedString()
	}

	private func randomNonceString() -> String {
		var buffer = [UInt8](repeating: 0, count: 32)
		_ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
		let nonce = Data(buffer).base64URLEncodedString()
		return nonce
	}

	// MARK: - Browser Fallback Support (macOS)

	@MainActor
	private static func storeBrowserState(_ state: String?, continuation: CheckedContinuation<URL, Error>) {
		browserState = state
		browserContinuation = continuation
	}

	/// Handle OAuth callback URL from browser redirect
	@MainActor
	public static func handleOAuthCallback(_ url: URL) async {
		print("[GoogleSignIn] Handling OAuth callback: \(url.absoluteString)")

		// Clear the in-progress flag when we're done
		defer {
			isSignInInProgress = false
		}

		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			print("[GoogleSignIn] ❌ Failed to parse callback URL")
			browserContinuation?.resume(throwing: GoogleSignInError.invalidAuthorizationResponse)
			browserContinuation = nil
			browserState = nil
			return
		}

		// Verify state parameter
		let state = components.queryItems?.first(where: { $0.name == "state" })?.value
		print("[GoogleSignIn] Callback state: \(state ?? "nil"), Expected: \(browserState ?? "nil")")

		guard state == browserState else {
			print("[GoogleSignIn] ❌ State mismatch in callback")
			browserContinuation?.resume(throwing: GoogleSignInError.stateMismatch)
			browserContinuation = nil
			browserState = nil
			return
		}

		// Check for errors
		if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
			print("[GoogleSignIn] ❌ OAuth error: \(error)")
			if error == "access_denied" {
				browserContinuation?.resume(throwing: GoogleSignInError.userCancelled)
			} else {
				browserContinuation?.resume(throwing: GoogleSignInError.tokenExchangeFailed(error))
			}
			browserContinuation = nil
			browserState = nil
			return
		}

		// Success - resume with the callback URL
		print("[GoogleSignIn] ✓ OAuth callback successful, resuming flow")
		browserContinuation?.resume(returning: url)

		// Clean up
		browserContinuation = nil
		browserState = nil
	}

	// MARK: - Form Encoding

	private func formEncode(_ parameters: [String: String]) -> String {
		let allowedCharacters = CharacterSet(
			charactersIn: "abcdefghijklmnopqrstuvwxyz" +
						  "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
						  "0123456789-._~"
		)

		return parameters.map { key, value in
			let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? key
			let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
			return "\(encodedKey)=\(encodedValue)"
		}.joined(separator: "&")
	}
}

// MARK: - Supporting Types

struct TokenResponse: Sendable {
	let idToken: String
	let accessToken: String
	let refreshToken: String?
	let expiresIn: Int
}

struct GoogleJWTClaims: Sendable {
	let subject: String        // sub
	let email: String?
	let emailVerified: Bool?
	let name: String?
	let picture: String?
	let issuer: String         // iss
	let audience: String       // aud (or first element if array)
	let expiration: Date       // exp
	let issuedAt: Date         // iat
	let nonce: String?         // nonce claim for replay protection
}

struct VerifiedToken: Sendable {
	let idToken: String
	let claims: GoogleJWTClaims
}

struct GoogleCredential: Sendable {
	let idToken: String
	let accessToken: String
	let claims: GoogleJWTClaims
}

// MARK: - Presentation Context

#if os(iOS)
final class IOSAuthenticationPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
	static let shared = IOSAuthenticationPresentationContext()

	func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		let foregroundScene = UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.first { $0.activationState == .foregroundActive }

		guard let scene = foregroundScene,
		      let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
			fatalError("Unable to find a foreground window for authentication presentation")
		}
		return window
	}
}
#elseif os(macOS)
final class MacAuthenticationPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
	static let shared = MacAuthenticationPresentationContext()

	func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		// Try to find existing key window
		if let keyWindow = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
			return keyWindow
		}

		// Try any existing window
		if let firstWindow = NSApplication.shared.windows.first {
			return firstWindow
		}

		// Create temporary window for authentication (like Photolala1 did)
		let window = NSWindow(
			contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		window.title = "Sign in with Google"
		window.center()
		window.makeKeyAndOrderFront(nil)

		return window
	}
}
#endif

// MARK: - Data Extensions

extension Data {
	nonisolated init?(base64URLEncoded string: String) {
		var base64 = string
			.replacingOccurrences(of: "-", with: "+")
			.replacingOccurrences(of: "_", with: "/")

		// Add padding if needed
		while base64.count % 4 != 0 {
			base64.append("=")
		}

		self.init(base64Encoded: base64)
	}

	nonisolated func base64URLEncodedString() -> String {
		return base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")
	}
}

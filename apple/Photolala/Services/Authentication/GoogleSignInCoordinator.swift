//
//  GoogleSignInCoordinator.swift
//  Photolala
//
//  Simplified Google OAuth 2.0 sign-in flow with browser-based authentication
//

import Foundation
import CryptoKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Simplified Google Sign-In coordinator that uses browser-based flow
@MainActor
final class GoogleSignInCoordinator {
	// MARK: - Properties

	private var authorizationContinuation: CheckedContinuation<GoogleCredential, Error>?
	private var currentState: String?
	private var currentNonce: String?
	private var currentCodeVerifier: String?

	// Shared instance for handling callbacks
	private static var activeCoordinator: GoogleSignInCoordinator?

	// MARK: - Public Methods

	/// Performs the Google Sign-In flow
	func performSignIn() async throws -> GoogleCredential {
		// Ensure only one sign-in at a time
		guard GoogleSignInCoordinator.activeCoordinator == nil else {
			throw GoogleSignInError.signInAlreadyInProgress
		}

		// Set this instance as active
		GoogleSignInCoordinator.activeCoordinator = self

		defer {
			// Clean up when done
			if GoogleSignInCoordinator.activeCoordinator === self {
				GoogleSignInCoordinator.activeCoordinator = nil
			}
		}

		return try await withCheckedThrowingContinuation { continuation in
			self.authorizationContinuation = continuation

			do {
				try startOAuthFlow()
			} catch {
				continuation.resume(throwing: error)
				self.authorizationContinuation = nil
			}
		}
	}

	// MARK: - OAuth Flow

	private func startOAuthFlow() throws {
		// Generate PKCE parameters
		let codeVerifier = generateCodeVerifier()
		let codeChallenge = generateCodeChallenge(from: codeVerifier)

		// Generate state and nonce
		let state = UUID().uuidString
		let nonce = generateNonce()

		// Store for later verification
		self.currentState = state
		self.currentNonce = nonce
		self.currentCodeVerifier = codeVerifier

		// Build authorization URL
		guard let authURL = buildAuthorizationURL(
			codeChallenge: codeChallenge,
			state: state,
			nonce: nonce
		) else {
			throw GoogleSignInError.invalidConfiguration
		}

		// Open in browser
		openInBrowser(authURL)
	}

	private func buildAuthorizationURL(codeChallenge: String, state: String, nonce: String) -> URL? {
		var components = URLComponents(string: GoogleOAuthConfiguration.authorizationEndpoint)
		components?.queryItems = [
			URLQueryItem(name: "client_id", value: GoogleOAuthConfiguration.clientID),
			URLQueryItem(name: "redirect_uri", value: GoogleOAuthConfiguration.redirectURI),
			URLQueryItem(name: "response_type", value: "code"),
			URLQueryItem(name: "scope", value: GoogleOAuthConfiguration.scopes.joined(separator: " ")),
			URLQueryItem(name: "state", value: state),
			URLQueryItem(name: "code_challenge", value: codeChallenge),
			URLQueryItem(name: "code_challenge_method", value: "S256"),
			URLQueryItem(name: "nonce", value: nonce),
			URLQueryItem(name: "access_type", value: "offline"),
			URLQueryItem(name: "prompt", value: "select_account")
		]
		return components?.url
	}

	private func openInBrowser(_ url: URL) {
		print("[GoogleSignIn] Opening OAuth URL in browser")
		#if os(macOS)
		NSWorkspace.shared.open(url)
		#else
		UIApplication.shared.open(url)
		#endif
	}

	// MARK: - Callback Handling

	/// Handles OAuth callback from the browser
	static func handleCallback(_ url: URL) {
		print("[GoogleSignIn] Received callback: \(url)")

		guard let coordinator = activeCoordinator else {
			print("[GoogleSignIn] No active coordinator to handle callback")
			return
		}

		Task { @MainActor in
			await coordinator.processCallback(url)
		}
	}

	private func processCallback(_ url: URL) async {
		do {
			// Parse the callback URL
			guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
				throw GoogleSignInError.invalidAuthorizationResponse
			}

			// Check for error
			if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
				if error == "access_denied" {
					throw GoogleSignInError.userCancelled
				}
				throw GoogleSignInError.authorizationFailed(error)
			}

			// Verify state
			let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
			guard returnedState == currentState else {
				throw GoogleSignInError.stateMismatch
			}

			// Get authorization code
			guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
				throw GoogleSignInError.noAuthorizationCode
			}

			// Exchange code for tokens
			let tokens = try await exchangeCodeForTokens(code: code)

			// Verify ID token
			let verifiedToken = try await verifyIDToken(tokens.idToken, expectedNonce: currentNonce!)

			// Create credential
			let credential = GoogleCredential(
				idToken: verifiedToken.idToken,
				accessToken: tokens.accessToken,
				claims: verifiedToken.claims
			)

			// Resume with success
			authorizationContinuation?.resume(returning: credential)
			authorizationContinuation = nil

		} catch {
			print("[GoogleSignIn] Error processing callback: \(error)")
			authorizationContinuation?.resume(throwing: error)
			authorizationContinuation = nil
		}

		// Clean up
		currentState = nil
		currentNonce = nil
		currentCodeVerifier = nil
	}

	// MARK: - Token Exchange

	private func exchangeCodeForTokens(code: String) async throws -> TokenResponse {
		guard let codeVerifier = currentCodeVerifier else {
			throw GoogleSignInError.invalidState
		}

		var request = URLRequest(url: URL(string: GoogleOAuthConfiguration.tokenEndpoint)!)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

		let parameters = [
			"grant_type": "authorization_code",
			"code": code,
			"redirect_uri": GoogleOAuthConfiguration.redirectURI,
			"client_id": GoogleOAuthConfiguration.clientID,
			"code_verifier": codeVerifier
		]

		request.httpBody = parameters
			.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
			.joined(separator: "&")
			.data(using: .utf8)

		let (data, response) = try await URLSession.shared.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse,
		      httpResponse.statusCode == 200 else {
			if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			   let error = json["error"] as? String {
				throw GoogleSignInError.tokenExchangeFailed(error)
			}
			throw GoogleSignInError.tokenExchangeFailed("Unknown error")
		}

		guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
		      let idToken = json["id_token"] as? String,
		      let accessToken = json["access_token"] as? String else {
			throw GoogleSignInError.invalidTokenResponse
		}

		let refreshToken = json["refresh_token"] as? String
		let expiresIn = (json["expires_in"] as? Int) ?? 3600

		return TokenResponse(
			idToken: idToken,
			accessToken: accessToken,
			refreshToken: refreshToken,
			expiresIn: expiresIn
		)
	}

	// MARK: - Token Verification

	private func verifyIDToken(_ idToken: String, expectedNonce: String) async throws -> VerifiedToken {
		// Parse JWT
		let parts = idToken.split(separator: ".")
		guard parts.count == 3 else {
			throw GoogleSignInError.invalidIDToken
		}

		// Decode header for key ID
		guard let headerData = Data(base64URLEncoded: String(parts[0])),
		      let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
		      let keyID = header["kid"] as? String else {
			throw GoogleSignInError.missingKeyID
		}

		// Get public key
		let publicKey = try await GooglePublicKeyCache.shared.getKey(for: keyID)

		// Verify signature
		let signedData = "\(parts[0]).\(parts[1])".data(using: .utf8)!
		guard let signatureData = Data(base64URLEncoded: String(parts[2])) else {
			throw GoogleSignInError.invalidSignature
		}

		let attributes: [String: Any] = [
			kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
			kSecAttrKeyClass as String: kSecAttrKeyClassPublic
		]

		guard let secKey = SecKeyCreateWithData(publicKey as CFData, attributes as CFDictionary, nil) else {
			throw GoogleSignInError.invalidSignature
		}

		let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
		guard SecKeyVerifySignature(secKey, algorithm, signedData as CFData, signatureData as CFData, nil) else {
			throw GoogleSignInError.invalidSignature
		}

		// Parse and validate claims
		guard let payloadData = Data(base64URLEncoded: String(parts[1])),
		      let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
			throw GoogleSignInError.invalidIDToken
		}

		let claims = try parseClaims(from: payload)

		// Validate claims
		guard claims.issuer == "https://accounts.google.com" || claims.issuer == "accounts.google.com" else {
			throw GoogleSignInError.invalidIssuer
		}

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

		let now = Date()
		guard claims.expiration > now else {
			throw GoogleSignInError.tokenExpired
		}

		// Validate issued at time (iat) - should not be in the future
		// Allow 60 seconds tolerance for clock skew
		let iatTolerance: TimeInterval = 60
		if claims.issuedAt > now.addingTimeInterval(iatTolerance) {
			throw GoogleSignInError.invalidIssuedAt
		}

		guard claims.nonce == expectedNonce else {
			throw GoogleSignInError.nonceMismatch
		}

		return VerifiedToken(idToken: idToken, claims: claims)
	}

	private func parseClaims(from payload: [String: Any]) throws -> GoogleJWTClaims {
		guard let sub = payload["sub"] as? String,
		      let iss = payload["iss"] as? String,
		      let exp = payload["exp"] as? TimeInterval,
		      let iat = payload["iat"] as? TimeInterval else {
			throw GoogleSignInError.invalidIDToken
		}

		let audience: String
		if let aud = payload["aud"] as? String {
			audience = aud
		} else if let audArray = payload["aud"] as? [String], !audArray.isEmpty {
			audience = audArray[0]
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

	private func generateNonce() -> String {
		var buffer = [UInt8](repeating: 0, count: 32)
		_ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
		return Data(buffer).base64URLEncodedString()
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

// MARK: - Data Extension for Base64URL

extension Data {
	nonisolated init?(base64URLEncoded string: String) {
		var base64 = string
			.replacingOccurrences(of: "-", with: "+")
			.replacingOccurrences(of: "_", with: "/")

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
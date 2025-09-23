//
//  GoogleOAuthConfiguration.swift
//  Photolala
//
//  Configuration for Google OAuth across all Apple platforms
//

import Foundation

/// Configuration for Google OAuth
struct GoogleOAuthConfiguration {
	// Use the Web Client ID for server-side verification
	nonisolated static let webClientID = "75309194504-p2sfktq2ju97ataogb1e5fkl70cj2jg3.apps.googleusercontent.com"

	// Use iOS client ID for all Apple platforms (works better with ASWebAuthenticationSession)
	nonisolated static let clientID = "75309194504-g1a4hr3pc68301vuh21tibauh9ar1nkv.apps.googleusercontent.com"

	// OAuth redirect URI - must match exactly what's configured in Google Console
	nonisolated static var redirectURI: String {
		// For iOS OAuth client, the redirect URI format is:
		// com.googleusercontent.apps.{CLIENT_ID}:/oauth2redirect/google
		// where CLIENT_ID is the full ID before ".apps.googleusercontent.com"
		let clientIDPrefix = clientID.components(separatedBy: ".apps.googleusercontent.com").first ?? ""
		return "com.googleusercontent.apps.\(clientIDPrefix):/oauth2redirect/google"
	}

	// URL Scheme for handling OAuth callbacks
	// IMPORTANT: This must match the URL scheme registered in Info.plist under CFBundleURLSchemes
	nonisolated static var urlScheme: String {
		// Extract the client ID prefix (before ".apps.googleusercontent.com")
		let clientIDPrefix = clientID.components(separatedBy: ".apps.googleusercontent.com").first ?? ""
		return "com.googleusercontent.apps.\(clientIDPrefix)"
	}

	// OAuth 2.0 endpoints
	nonisolated static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
	nonisolated static let tokenEndpoint = "https://oauth2.googleapis.com/token"

	// Scopes
	nonisolated static let scopes = [
		"openid",
		"email",
		"profile"
	]

	// Additional configuration
	nonisolated static let hostedDomain: String? = nil  // Set to restrict to specific domain
	nonisolated static let loginHint: String? = nil     // Pre-fill email address

	// Platform-specific configuration
	#if os(iOS)
	nonisolated static let preferEphemeralSession = false  // Use persistent session on iOS
	#elseif os(macOS)
	nonisolated static let preferEphemeralSession = false  // Use persistent session on macOS too
	#endif
}

// MARK: - Helper Methods
extension GoogleOAuthConfiguration {
	/// Generate OAuth authorization URL
	nonisolated static func authorizationURL(state: String, codeChallenge: String? = nil) -> URL? {
		var components = URLComponents(string: authorizationEndpoint)

		var queryItems = [
			URLQueryItem(name: "client_id", value: clientID),
			URLQueryItem(name: "redirect_uri", value: redirectURI),
			URLQueryItem(name: "response_type", value: "code"),
			URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
			URLQueryItem(name: "state", value: state),
			URLQueryItem(name: "access_type", value: "offline"),
			URLQueryItem(name: "prompt", value: "select_account")
		]

		if let codeChallenge = codeChallenge {
			queryItems.append(URLQueryItem(name: "code_challenge", value: codeChallenge))
			queryItems.append(URLQueryItem(name: "code_challenge_method", value: "S256"))
		}

		if let hostedDomain = hostedDomain {
			queryItems.append(URLQueryItem(name: "hd", value: hostedDomain))
		}

		if let loginHint = loginHint {
			queryItems.append(URLQueryItem(name: "login_hint", value: loginHint))
		}

		components?.queryItems = queryItems
		return components?.url
	}
}
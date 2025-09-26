//
//  OAuthTokens.swift
//  Photolala
//
//  OAuth tokens for authentication flow
//

import Foundation

struct OAuthTokens: Sendable {
	let idToken: String
	let accessToken: String?
	let provider: String
	let nonce: String?
	let authorizationCode: String?
	let userIdentifier: String

	// Additional OAuth data
	let email: String?
	let displayName: String?
	let expiresAt: Date?

	// For Google OAuth
	init(googleIdToken: String, accessToken: String, email: String?, name: String?, subject: String) {
		self.idToken = googleIdToken
		self.accessToken = accessToken
		self.provider = "google"
		self.nonce = nil
		self.authorizationCode = nil
		self.userIdentifier = subject
		self.email = email
		self.displayName = name
		self.expiresAt = nil
	}

	// For Apple OAuth
	init(appleIdentityToken: String, authorizationCode: String?, nonce: String?, userIdentifier: String) {
		self.idToken = appleIdentityToken
		self.accessToken = nil
		self.provider = "apple"
		self.nonce = nonce
		self.authorizationCode = authorizationCode
		self.userIdentifier = userIdentifier
		self.email = nil  // Apple doesn't always provide email
		self.displayName = nil  // Apple doesn't provide display name
		self.expiresAt = nil
	}
}
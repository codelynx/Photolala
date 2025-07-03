import Foundation
import AuthenticationServices

struct AuthCredential {
	let provider: AuthProvider
	let providerID: String
	let email: String?
	let fullName: String?
	let photoURL: String?
	let identityToken: Data?
	let authorizationCode: Data?
	
	// Google Sign In properties
	let idToken: String?
	let accessToken: String?
	
	// For Apple Sign In
	init(appleCredential: ASAuthorizationAppleIDCredential) {
		self.provider = .apple
		self.providerID = appleCredential.user
		self.email = appleCredential.email
		self.fullName = appleCredential.fullName?.formatted()
		self.photoURL = nil
		self.identityToken = appleCredential.identityToken
		self.authorizationCode = appleCredential.authorizationCode
		self.idToken = nil
		self.accessToken = nil
	}
	
	// For Google Sign In
	init(provider: AuthProvider, providerID: String, email: String?, fullName: String?, photoURL: String?, idToken: String?, accessToken: String?) {
		self.provider = provider
		self.providerID = providerID
		self.email = email
		self.fullName = fullName
		self.photoURL = photoURL
		self.identityToken = nil
		self.authorizationCode = nil
		self.idToken = idToken
		self.accessToken = accessToken
	}
}
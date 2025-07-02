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
	
	// For Apple Sign In
	init(appleCredential: ASAuthorizationAppleIDCredential) {
		self.provider = .apple
		self.providerID = appleCredential.user
		self.email = appleCredential.email
		self.fullName = appleCredential.fullName?.formatted()
		self.photoURL = nil
		self.identityToken = appleCredential.identityToken
		self.authorizationCode = appleCredential.authorizationCode
	}
	
	// For Google Sign In (placeholder for Phase 2)
	init(googleUser: Any) {
		// TODO: Implement in Phase 2
		self.provider = .google
		self.providerID = ""
		self.email = nil
		self.fullName = nil
		self.photoURL = nil
		self.identityToken = nil
		self.authorizationCode = nil
	}
}
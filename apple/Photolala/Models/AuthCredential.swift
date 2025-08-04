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
		
		// Extract the actual Apple ID from the JWT's sub field for cross-platform consistency
		// The appleCredential.user is a relay ID that differs from the JWT sub field
		if let identityToken = appleCredential.identityToken,
		   let jwtString = String(data: identityToken, encoding: .utf8) {
			// Decode JWT to extract the sub field
			if let sub = Self.extractSubFromJWT(jwtString) {
				self.providerID = sub
			} else {
				// Fallback to relay ID if JWT parsing fails
				self.providerID = appleCredential.user
			}
		} else {
			// Fallback to relay ID if no identity token
			self.providerID = appleCredential.user
		}
		
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
	
	// Helper method to extract sub field from JWT
	private static func extractSubFromJWT(_ jwt: String) -> String? {
		// Split JWT into parts
		let parts = jwt.split(separator: ".")
		guard parts.count == 3 else { return nil }
		
		// Decode the payload (middle part)
		let payload = String(parts[1])
		
		// Add padding if needed for base64 decoding
		let paddedPayload = payload.padding(toLength: ((payload.count + 3) / 4) * 4,
		                                    withPad: "=",
		                                    startingAt: 0)
		
		guard let payloadData = Data(base64Encoded: paddedPayload),
		      let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
		      let sub = json["sub"] as? String else {
			return nil
		}
		
		
		return sub
	}
}
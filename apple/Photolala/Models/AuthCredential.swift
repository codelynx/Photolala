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
		
		// Apple only provides email and name on first authorization
		// On subsequent sign-ins, these will be nil in the credential
		// BUT we can extract email from the JWT identity token
		
		// Try to get email from credential first, then from JWT
		var extractedEmail = appleCredential.email
		if let identityToken = appleCredential.identityToken,
		   let jwtString = String(data: identityToken, encoding: .utf8) {
			// Log JWT payload for debugging
			if let payload = Self.decodeJWTPayload(jwtString) {
				print("[AuthCredential] JWT payload contains: \(payload.keys.joined(separator: ", "))")
				if let jwtEmail = payload["email"] as? String {
					print("[AuthCredential] JWT contains email: \(jwtEmail)")
					if extractedEmail == nil {
						extractedEmail = jwtEmail
						print("[AuthCredential] Using email from JWT since credential.email is nil")
					}
				}
			}
		}
		self.email = extractedEmail
		
		// Format the name, but treat empty strings as nil
		let formattedName = appleCredential.fullName?.formatted()
		self.fullName = (formattedName?.isEmpty ?? true) ? nil : formattedName
		
		self.photoURL = nil
		self.identityToken = appleCredential.identityToken
		self.authorizationCode = appleCredential.authorizationCode
		self.idToken = nil
		self.accessToken = nil
		
		// Debug logging
		print("[AuthCredential] Apple Sign In - email: \(self.email ?? "nil"), fullName: \(self.fullName ?? "nil")")
		print("[AuthCredential] Apple Sign In - fullName components: \(appleCredential.fullName?.debugDescription ?? "nil")")
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
		let payload = decodeJWTPayload(jwt)
		return payload?["sub"] as? String
	}
	
	// Helper method to extract email from JWT
	private static func extractEmailFromJWT(_ jwt: String) -> String? {
		let payload = decodeJWTPayload(jwt)
		return payload?["email"] as? String
	}
	
	// Generic JWT payload decoder
	private static func decodeJWTPayload(_ jwt: String) -> [String: Any]? {
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
		      let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
			return nil
		}
		
		return json
	}
}
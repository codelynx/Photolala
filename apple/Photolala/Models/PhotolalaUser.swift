import Foundation

struct PhotolalaUser: Codable, Sendable {
	let id: UUID
	let appleUserID: String?
	let googleUserID: String?
	let email: String?
	let displayName: String
	let createdAt: Date
	let updatedAt: Date

	var hasAppleProvider: Bool { appleUserID != nil }
	var hasGoogleProvider: Bool { googleUserID != nil }

	enum CodingKeys: String, CodingKey {
		case id = "user_id"
		case appleUserID = "apple_user_id"
		case googleUserID = "google_user_id"
		case email
		case displayName = "display_name"
		case createdAt = "created_at"
		case updatedAt = "updated_at"
	}
}

struct AuthResult: Codable, Sendable {
	let user: PhotolalaUser
	let credentials: STSCredentials
	let isNewUser: Bool

	enum CodingKeys: String, CodingKey {
		case user
		case credentials
		case isNewUser = "is_new_user"
	}
}
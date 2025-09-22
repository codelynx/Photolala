import Foundation

struct STSCredentials: Codable, Sendable {
	let accessKeyId: String
	let secretAccessKey: String
	let sessionToken: String
	let expiration: Date

	nonisolated var isExpired: Bool {
		Date() >= expiration
	}

	nonisolated var timeUntilExpiry: TimeInterval {
		expiration.timeIntervalSince(Date())
	}

	enum CodingKeys: String, CodingKey {
		case accessKeyId = "access_key_id"
		case secretAccessKey = "secret_access_key"
		case sessionToken = "session_token"
		case expiration
	}
}
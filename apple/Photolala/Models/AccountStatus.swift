import Foundation

enum AccountStatus: Codable, Sendable {
	case active
	case scheduledForDeletion(deleteDate: Date)
	case deleted(deletedDate: Date)

	enum CodingKeys: String, CodingKey {
		case status
		case deleteDate
		case deletedDate
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let status = try container.decode(String.self, forKey: .status)

		switch status {
		case "active":
			self = .active
		case "scheduled_for_deletion":
			let deleteDate = try container.decode(Date.self, forKey: .deleteDate)
			self = .scheduledForDeletion(deleteDate: deleteDate)
		case "deleted":
			let deletedDate = try container.decode(Date.self, forKey: .deletedDate)
			self = .deleted(deletedDate: deletedDate)
		default:
			throw DecodingError.dataCorrupted(.init(
				codingPath: container.codingPath,
				debugDescription: "Unknown account status: \(status)"
			))
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		switch self {
		case .active:
			try container.encode("active", forKey: .status)
		case .scheduledForDeletion(let deleteDate):
			try container.encode("scheduled_for_deletion", forKey: .status)
			try container.encode(deleteDate, forKey: .deleteDate)
		case .deleted(let deletedDate):
			try container.encode("deleted", forKey: .status)
			try container.encode(deletedDate, forKey: .deletedDate)
		}
	}
}

@preconcurrency struct UserStatusFile: Codable, Sendable {
	let accountStatus: AccountStatus
	let lastModified: Date
	let canCancel: Bool
	let accessLevel: AccessLevel

	enum AccessLevel: String, Codable, Sendable {
		case full = "full"
		case readOnly = "read_only"
		case none = "none"
	}
}


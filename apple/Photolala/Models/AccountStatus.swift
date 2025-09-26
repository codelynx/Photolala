import Foundation

enum AccountStatus: Codable, Sendable {
	case active
	case scheduledForDeletion(deleteDate: Date)
	// Note: No 'deleted' case - when deleted, status.json is removed entirely

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
		}
	}
}

/// Minimal status.json structure - Phase 1
struct UserStatusFile: Codable, Sendable {
	let accountStatus: String  // "active" or "scheduled_for_deletion"
	let deleteDate: Date?       // Only present when scheduled_for_deletion
	let lastModified: Date

	/// Helper to get typed status
	nonisolated var typedStatus: AccountStatus {
		switch accountStatus {
		case "active":
			return .active
		case "scheduled_for_deletion":
			if let deleteDate = deleteDate {
				return .scheduledForDeletion(deleteDate: deleteDate)
			}
			return .active // Fallback if malformed
		default:
			return .active // Unknown status = treat as active
		}
	}

	/// Helper to check if cancellation is allowed
	nonisolated var canCancel: Bool {
		return accountStatus == "scheduled_for_deletion"
	}

	/// Create status file from typed enum
	nonisolated init(status: AccountStatus, lastModified: Date = Date()) {
		self.lastModified = lastModified
		switch status {
		case .active:
			self.accountStatus = "active"
			self.deleteDate = nil
		case .scheduledForDeletion(let date):
			self.accountStatus = "scheduled_for_deletion"
			self.deleteDate = date
		}
	}
}


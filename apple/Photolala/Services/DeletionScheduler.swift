import Foundation
import OSLog

actor DeletionScheduler {
	private let logger = Logger(subsystem: "com.photolala", category: "DeletionScheduler")
	private let s3Service: S3Service
	private let environment: AWSEnvironment

	/// Grace period in seconds based on environment
	var gracePeriodSeconds: TimeInterval {
		switch environment {
		case .development:
			return 180 // 3 minutes
		case .staging:
			return 259200 // 3 days
		case .production:
			return 2592000 // 30 days
		}
	}

	init(s3Service: S3Service, environment: AWSEnvironment) {
		self.s3Service = s3Service
		self.environment = environment
	}

	/// Schedule account deletion with grace period
	func scheduleAccountDeletion(user: PhotolalaUser) async throws {
		let scheduledDate = Date()
		let deleteDate = scheduledDate.addingTimeInterval(gracePeriodSeconds)

		logger.info("Scheduling deletion for user \(user.id) at \(deleteDate)")

		// Note: Identity mappings remain unchanged during scheduling
		// They will be deleted when the grace period expires

		// Create scheduled deletion entry
		let dateKey = ISO8601DateFormatter().string(from: deleteDate).prefix(10) // YYYY-MM-DD
		let deletionKey = "scheduled-deletions/\(dateKey)/\(user.id.uuidString).json"

		struct ScheduledDeletionData: Codable {
			let userId: String
			let email: String?
			let appleId: String?
			let googleId: String?
			let scheduledAt: Date
			let deleteOn: Date
		}

		let deletionData = ScheduledDeletionData(
			userId: user.id.uuidString,
			email: user.email,
			appleId: user.appleUserID,
			googleId: user.googleUserID,
			scheduledAt: scheduledDate,
			deleteOn: deleteDate
		)

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let data = try encoder.encode(deletionData)

		try await s3Service.putObject(
			key: deletionKey,
			data: data,
			contentType: "application/json"
		)

		// Update user status file
		let status = UserStatusFile(
			status: .scheduledForDeletion(deleteDate: deleteDate)
		)

		try await s3Service.writeUserStatus(status, for: user.id.uuidString)

		logger.info("Account deletion scheduled for user \(user.id)")
	}

	/// Cancel scheduled deletion
	func cancelScheduledDeletion(user: PhotolalaUser) async throws {
		// Read current status to get deletion date
		guard let currentStatus = try await s3Service.getUserStatus(for: user.id.uuidString),
			  case .scheduledForDeletion(let deleteDate) = currentStatus.typedStatus else {
			throw DeletionError.notScheduledForDeletion
		}

		logger.info("Cancelling deletion for user \(user.id)")

		// Note: Identity mappings remain unchanged (they were never modified)

		// Remove from scheduled deletions
		let dateKey = ISO8601DateFormatter().string(from: deleteDate).prefix(10)
		let deletionKey = "scheduled-deletions/\(dateKey)/\(user.id.uuidString).json"

		do {
			try await s3Service.deleteObject(key: deletionKey)
		} catch {
			logger.warning("Failed to remove scheduled deletion entry: \(error)")
		}

		// Update user status to active
		let status = UserStatusFile(
			status: .active
		)

		try await s3Service.writeUserStatus(status, for: user.id.uuidString)

		logger.info("Account deletion cancelled for user \(user.id)")
	}

	/// Expedite deletion (development only)
	func expediteDeletion(user: PhotolalaUser) async throws {
		guard environment == .development else {
			throw DeletionError.notAllowedInEnvironment
		}

		logger.info("Expediting deletion for user \(user.id) (dev only)")

		// Delete all user data using the comprehensive method
		// This includes photos, thumbnails, catalogs, user data, AND identity mappings
		// Note: deleteAllUserData also removes status.json (under users/ prefix)
		try await s3Service.deleteAllUserData(userID: user.id.uuidString)
		logger.info("Deleted all data including identity mappings for user \(user.id)")

		// Note: After this point, the account no longer exists
		// The user can sign up again with the same identity if desired

		logger.info("Account deleted immediately for user \(user.id)")
	}
}

enum DeletionError: LocalizedError {
	case notScheduledForDeletion
	case notAllowedInEnvironment
	case invalidState

	var errorDescription: String? {
		switch self {
		case .notScheduledForDeletion:
			return "Account is not scheduled for deletion"
		case .notAllowedInEnvironment:
			return "This operation is not allowed in the current environment"
		case .invalidState:
			return "Invalid account state for this operation"
		}
	}
}
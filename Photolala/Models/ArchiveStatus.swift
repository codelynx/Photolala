import Foundation

/// Represents the archive status of a photo in S3
enum ArchiveStatus: String, CaseIterable {
	case standard = "STANDARD"
	case deepArchive = "DEEP_ARCHIVE"
	case glacier = "GLACIER"
	case intelligentTiering = "INTELLIGENT_TIERING"
	
	/// Whether the photo is immediately accessible
	var isImmediatelyAccessible: Bool {
		switch self {
		case .standard, .intelligentTiering:
			return true
		case .deepArchive, .glacier:
			return false
		}
	}
	
	/// User-friendly display name
	var displayName: String {
		switch self {
		case .standard:
			return "Available"
		case .deepArchive:
			return "Archived"
		case .glacier:
			return "Cold Storage"
		case .intelligentTiering:
			return "Smart Storage"
		}
	}
	
	/// Icon to display for this status
	var icon: String {
		switch self {
		case .standard, .intelligentTiering:
			return "" // No icon for available photos
		case .deepArchive, .glacier:
			return "❄️"
		}
	}
	
	/// Estimated retrieval time in hours
	var retrievalHours: ClosedRange<Int>? {
		switch self {
		case .standard, .intelligentTiering:
			return nil // Immediate access
		case .glacier:
			return 3...5 // Expedited retrieval
		case .deepArchive:
			return 12...48 // Standard retrieval
		}
	}
}

/// Represents a photo retrieval request
struct PhotoRetrieval: Identifiable {
	let id = UUID()
	let photoMD5: String
	let requestedAt: Date
	let estimatedReadyAt: Date
	let status: RetrievalStatus
	
	enum RetrievalStatus {
		case pending
		case inProgress(percentComplete: Double)
		case completed
		case failed(error: String)
	}
}

/// Tracks the lifecycle of an archived photo
struct ArchivedPhotoInfo {
	let md5: String
	let archivedDate: Date
	let storageClass: ArchiveStatus
	let lastAccessedDate: Date?
	let isPinned: Bool // User wants to keep this photo always available
	let retrieval: PhotoRetrieval?
	
	/// Time remaining before photo re-archives (if retrieved)
	var daysUntilReArchive: Int? {
		guard storageClass.isImmediatelyAccessible,
		      let lastAccessed = lastAccessedDate else { return nil }
		
		let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: lastAccessed)!
		let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: thirtyDaysLater).day ?? 0
		
		return max(0, daysRemaining)
	}
	
	/// Whether photo is about to re-archive
	var isExpiringSoon: Bool {
		guard let days = daysUntilReArchive else { return false }
		return days <= 7
	}
}
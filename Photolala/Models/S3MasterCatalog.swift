import Foundation

/// S3 master catalog that tracks upload dates and storage classes
struct S3MasterCatalog: Codable {
	struct PhotoInfo: Codable {
		let uploadDate: Date
		let storageClass: String
		let archiveDate: Date?
		let lastAccessed: Date?
	}
	
	let version: Int
	let userId: String
	let lastUpdated: Date
	let photos: [String: PhotoInfo] // MD5 -> PhotoInfo
	
	/// Get storage class as enum
	func storageClass(for md5: String) -> S3StorageClass {
		guard let info = photos[md5] else { return .standard }
		return S3StorageClass(rawValue: info.storageClass) ?? .standard
	}
}

/// S3 storage classes
enum S3StorageClass: String, Codable {
	case standard = "STANDARD"
	case standardIA = "STANDARD_IA"
	case intelligentTiering = "INTELLIGENT_TIERING"
	case deepArchive = "DEEP_ARCHIVE"
	
	var isArchived: Bool {
		self == .deepArchive
	}
	
	var displayName: String {
		switch self {
		case .standard:
			return "Standard"
		case .standardIA:
			return "Infrequent Access"
		case .intelligentTiering:
			return "Intelligent Tiering"
		case .deepArchive:
			return "Deep Archive"
		}
	}
	
	var retrievalTime: String? {
		switch self {
		case .deepArchive:
			return "12-48 hours"
		default:
			return nil
		}
	}
}
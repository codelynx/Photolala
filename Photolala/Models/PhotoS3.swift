import Foundation

/// Photo model for S3 browser, combining catalog data with S3 metadata
struct PhotoS3: Identifiable, Hashable {
	// From .photolala catalog (CSV fields)
	var id: String { md5 }  // Conformance to Identifiable
	let md5: String
	let filename: String
	let size: Int64
	let photoDate: Date     // When photo was taken
	let modified: Date      // File modification date
	let width: Int?
	let height: Int?
	let applePhotoID: String?  // Apple Photos Library ID if backed up from Photos app
	
	// From S3 master catalog (JSON)
	let uploadDate: Date?
	let storageClass: S3StorageClass
	
	// User context (injected from app)
	let userId: String
	
	// Computed properties
	var photoKey: String {
		"photos/\(userId)/\(md5).dat"
	}
	
	var thumbnailKey: String {
		"thumbnails/\(userId)/\(md5).dat"
	}
	
	#if DEBUG
	// For testing, provide alternative keys without userId in path
	var testPhotoKey: String {
		"photos/test/\(md5).jpg"
	}
	
	var testThumbnailKey: String {
		"thumbnails/test/\(md5)_thumb.jpg"
	}
	#endif
	
	var isArchived: Bool {
		storageClass == .deepArchive
	}
	
	var formattedSize: String {
		ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
	}
	
	var aspectRatio: Double? {
		guard let width = width, let height = height, height > 0 else { return nil }
		return Double(width) / Double(height)
	}
	
	// Initialize from catalog entry and S3 info
	init(from catalogEntry: PhotolalaCatalogService.CatalogEntry, 
		 s3Info: S3MasterCatalog.PhotoInfo?,
		 userId: String) {
		self.md5 = catalogEntry.md5
		self.filename = catalogEntry.filename
		self.size = catalogEntry.size
		self.photoDate = catalogEntry.photodate
		self.modified = catalogEntry.modified
		self.width = catalogEntry.width
		self.height = catalogEntry.height
		self.applePhotoID = catalogEntry.applePhotoID
		self.userId = userId
		
		self.uploadDate = s3Info?.uploadDate
		self.storageClass = s3Info.map { S3StorageClass(rawValue: $0.storageClass) ?? .standard } ?? .standard
	}
	
	// Initialize from CatalogPhotoEntry (SwiftData) and S3 info
	init(from catalogEntry: CatalogPhotoEntry,
		 s3Info: S3MasterCatalog.PhotoInfo?,
		 userId: String) {
		self.md5 = catalogEntry.md5
		self.filename = catalogEntry.filename
		self.size = catalogEntry.fileSize
		self.photoDate = catalogEntry.photoDate
		self.modified = catalogEntry.fileModifiedDate
		self.width = catalogEntry.pixelWidth
		self.height = catalogEntry.pixelHeight
		self.applePhotoID = catalogEntry.applePhotoID
		self.userId = userId
		
		self.uploadDate = s3Info?.uploadDate
		self.storageClass = s3Info.map { S3StorageClass(rawValue: $0.storageClass) ?? .standard } ?? .standard
	}
	
	// Hashable conformance
	func hash(into hasher: inout Hasher) {
		hasher.combine(md5)
	}
	
	static func == (lhs: PhotoS3, rhs: PhotoS3) -> Bool {
		lhs.md5 == rhs.md5
	}
}

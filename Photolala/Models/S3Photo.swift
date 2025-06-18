import Foundation

/// Photo model for S3 browser, combining catalog data with S3 metadata
struct S3Photo: Identifiable, Hashable {
	// From .photolala catalog (CSV fields)
	var id: String { md5 }  // Conformance to Identifiable
	let md5: String
	let filename: String
	let size: Int64
	let photoDate: Date     // When photo was taken
	let modified: Date      // File modification date
	let width: Int?
	let height: Int?
	
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
		self.photoDate = catalogEntry.photoDate
		self.modified = catalogEntry.modified
		self.width = catalogEntry.width
		self.height = catalogEntry.height
		self.userId = userId
		
		self.uploadDate = s3Info?.uploadDate
		self.storageClass = s3Info.map { S3StorageClass(rawValue: $0.storageClass) ?? .standard } ?? .standard
	}
	
	// Hashable conformance
	func hash(into hasher: inout Hasher) {
		hasher.combine(md5)
	}
	
	static func == (lhs: S3Photo, rhs: S3Photo) -> Bool {
		lhs.md5 == rhs.md5
	}
}
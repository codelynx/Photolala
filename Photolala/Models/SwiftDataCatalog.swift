//
//  SwiftDataCatalog.swift
//  Photolala
//
//  SwiftData models for local catalog implementation
//

import SwiftData
import Foundation

@Model
final class PhotoCatalog {
	// Identity
	var directoryUUID: String
	var directoryPath: String

	// Metadata
	var version: String = "6.0"
	var createdDate: Date
	var modifiedDate: Date
	
	// Relationships - 16 separate shards
	@Relationship(deleteRule: .cascade) var shard0: CatalogShard?
	@Relationship(deleteRule: .cascade) var shard1: CatalogShard?
	@Relationship(deleteRule: .cascade) var shard2: CatalogShard?
	@Relationship(deleteRule: .cascade) var shard3: CatalogShard?
	@Relationship(deleteRule: .cascade) var shard4: CatalogShard?
	@Relationship(deleteRule: .cascade) var shard5: CatalogShard?
	@Relationship(deleteRule: .cascade) var shard6: CatalogShard?
	@Relationship(deleteRule: .cascade) var shard7: CatalogShard?
	@Relationship(deleteRule: .cascade) var shard8: CatalogShard?
	@Relationship(deleteRule: .cascade) var shard9: CatalogShard?
	@Relationship(deleteRule: .cascade) var shardA: CatalogShard?
	@Relationship(deleteRule: .cascade) var shardB: CatalogShard?
	@Relationship(deleteRule: .cascade) var shardC: CatalogShard?
	@Relationship(deleteRule: .cascade) var shardD: CatalogShard?
	@Relationship(deleteRule: .cascade) var shardE: CatalogShard?
	@Relationship(deleteRule: .cascade) var shardF: CatalogShard?

	// Sync metadata
	var lastS3SyncDate: Date?
	var s3ManifestETag: String? // S3 manifest ETag for change detection

	init(directoryPath: String) {
		self.directoryUUID = UUID().uuidString
		self.directoryPath = directoryPath
		self.createdDate = Date()
		self.modifiedDate = Date()
		
		// Initialize 16 empty shards
		self.shard0 = CatalogShard(index: 0, catalog: self)
		self.shard1 = CatalogShard(index: 1, catalog: self)
		self.shard2 = CatalogShard(index: 2, catalog: self)
		self.shard3 = CatalogShard(index: 3, catalog: self)
		self.shard4 = CatalogShard(index: 4, catalog: self)
		self.shard5 = CatalogShard(index: 5, catalog: self)
		self.shard6 = CatalogShard(index: 6, catalog: self)
		self.shard7 = CatalogShard(index: 7, catalog: self)
		self.shard8 = CatalogShard(index: 8, catalog: self)
		self.shard9 = CatalogShard(index: 9, catalog: self)
		self.shardA = CatalogShard(index: 10, catalog: self)
		self.shardB = CatalogShard(index: 11, catalog: self)
		self.shardC = CatalogShard(index: 12, catalog: self)
		self.shardD = CatalogShard(index: 13, catalog: self)
		self.shardE = CatalogShard(index: 14, catalog: self)
		self.shardF = CatalogShard(index: 15, catalog: self)
	}
	
	// Computed property for total photo count
	var photoCount: Int {
		var total = 0
		total += shard0?.photoCount ?? 0
		total += shard1?.photoCount ?? 0
		total += shard2?.photoCount ?? 0
		total += shard3?.photoCount ?? 0
		total += shard4?.photoCount ?? 0
		total += shard5?.photoCount ?? 0
		total += shard6?.photoCount ?? 0
		total += shard7?.photoCount ?? 0
		total += shard8?.photoCount ?? 0
		total += shard9?.photoCount ?? 0
		total += shardA?.photoCount ?? 0
		total += shardB?.photoCount ?? 0
		total += shardC?.photoCount ?? 0
		total += shardD?.photoCount ?? 0
		total += shardE?.photoCount ?? 0
		total += shardF?.photoCount ?? 0
		return total
	}
	
	// Get shard for a given MD5
	func shard(for md5: String) -> CatalogShard? {
		guard let firstChar = md5.first,
			  let hexValue = Int(String(firstChar), radix: 16) else {
			return nil
		}
		
		// Direct access by index - no searching needed
		switch hexValue {
		case 0: return shard0
		case 1: return shard1
		case 2: return shard2
		case 3: return shard3
		case 4: return shard4
		case 5: return shard5
		case 6: return shard6
		case 7: return shard7
		case 8: return shard8
		case 9: return shard9
		case 10: return shardA
		case 11: return shardB
		case 12: return shardC
		case 13: return shardD
		case 14: return shardE
		case 15: return shardF
		default: return nil
		}
	}
	
	// Get all shards
	var allShards: [CatalogShard] {
		[shard0, shard1, shard2, shard3, shard4, shard5, shard6, shard7,
		 shard8, shard9, shardA, shardB, shardC, shardD, shardE, shardF]
			.compactMap { $0 }
	}
}

@Model
final class CatalogShard {
	// Identity
	var index: Int // 0-15
	
	// Content
	@Relationship(deleteRule: .cascade)
	var entries: [CatalogPhotoEntry]? = []
	
	// Sync tracking
	var isModified: Bool = false
	var lastModifiedDate: Date?
	var lastS3SyncDate: Date?
	var s3Checksum: String? // SHA256 of shard content on S3
	
	// Statistics
	var photoCount: Int = 0
	
	// Relationships
	var catalog: PhotoCatalog?
	
	init(index: Int, catalog: PhotoCatalog? = nil) {
		self.index = index
		self.catalog = catalog
	}
	
	// Mark shard as modified
	func markModified() {
		self.isModified = true
		self.lastModifiedDate = Date()
	}
	
	// Clear modification flag after successful sync
	func clearModified() {
		self.isModified = false
		self.lastS3SyncDate = Date()
	}
}

@Model
final class CatalogPhotoEntry {
	// Core fields (synced to S3)
	@Attribute(.unique) var md5: String
	var filename: String
	var fileSize: Int64
	var photoDate: Date
	var fileModifiedDate: Date
	var pixelWidth: Int?
	var pixelHeight: Int?
	var applePhotoID: String? // Only for Apple Photos source

	// Extended metadata (local only)
	var cameraMake: String?
	var cameraModel: String?
	var orientation: Int?
	var gpsLatitude: Double?
	var gpsLongitude: Double?
	var aperture: Double?
	var shutterSpeed: String?
	var iso: Int?
	var focalLength: Double?

	// Backup status (local only)
	var isStarred: Bool = false
	var backupStatus: BackupStatus = BackupStatus.notBackedUp
	var lastBackupAttempt: Date?
	var backupError: String?

	// Cached display values
	var cachedThumbnailDate: Date?
	var cachedPreviewDate: Date?

	// Relationships
	var shard: CatalogShard? // Direct relationship to shard

	// Required initializer for SwiftData
	init(md5: String, filename: String, fileSize: Int64, photoDate: Date, fileModifiedDate: Date) {
		self.md5 = md5
		self.filename = filename
		self.fileSize = fileSize
		self.photoDate = photoDate
		self.fileModifiedDate = fileModifiedDate
	}
	
	// Computed properties
	var shardIndex: Int {
		guard let firstChar = md5.first,
			  let hexValue = Int(String(firstChar), radix: 16) else {
			return 0
		}
		return hexValue
	}

	// CSV export support
	var csvLine: String {
		let widthStr = pixelWidth.map(String.init) ?? ""
		let heightStr = pixelHeight.map(String.init) ?? ""
		let photodateStr = String(Int(photoDate.timeIntervalSince1970))
		let modifiedStr = String(Int(fileModifiedDate.timeIntervalSince1970))
		let applePhotoIDStr = applePhotoID ?? ""

		let escapedFilename = filename.contains(",") || filename.contains("\"")
			? "\"\(filename.replacingOccurrences(of: "\"", with: "\"\""))\""
			: filename

		return "\(md5),\(escapedFilename),\(fileSize),\(photodateStr),\(modifiedStr),\(widthStr),\(heightStr),\(applePhotoIDStr)"
	}
}

// Backup status enum (reused from existing code)
enum BackupStatus: Int, Codable {
	case notBackedUp = 0
	case queued = 1
	case uploading = 2
	case uploaded = 3
	case error = 4
}

// CatalogEntry for CSV parsing (compatible with existing PhotolalaCatalogService)
struct CatalogEntry {
	let md5: String
	let filename: String
	let size: Int64
	let photodate: Date
	let modified: Date
	let width: Int?
	let height: Int?
	let applePhotoID: String?
	
	// Parse from CSV line (implementation from existing PhotolalaCatalogService)
	init?(csvLine: String) {
		let scanner = Scanner(string: csvLine)
		scanner.charactersToBeSkipped = nil
		
		// Parse MD5
		guard let md5 = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")) else { return nil }
		_ = scanner.scanCharacter() // consume comma
		
		// Parse filename (handle quoted values)
		let filename: String
		let currentIndex = scanner.currentIndex
		if scanner.scanCharacter() == "\"" {
			// Quoted filename - scan until closing quote
			var quotedValue = ""
			while !scanner.isAtEnd {
				if let chunk = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "\"")) {
					quotedValue += chunk
				}
				if scanner.scanCharacter() == "\"" {
					// Check if it's an escaped quote
					if scanner.scanCharacter() == "\"" {
						quotedValue += "\""
					} else {
						// End of quoted value
						_ = scanner.scanCharacter() // consume comma
						break
					}
				}
			}
			filename = quotedValue
		} else {
			// Unquoted filename - need to backtrack since we consumed a character
			scanner.currentIndex = currentIndex
			guard let value = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")) else { return nil }
			filename = value
			_ = scanner.scanCharacter() // consume comma
		}
		
		// Parse remaining fields
		guard let sizeStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")),
			  let size = Int64(sizeStr) else { return nil }
		_ = scanner.scanCharacter()
		
		guard let photodateStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")),
			  let photodateTimestamp = TimeInterval(photodateStr) else { return nil }
		_ = scanner.scanCharacter()
		
		guard let modifiedStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")),
			  let modifiedTimestamp = TimeInterval(modifiedStr) else { return nil }
		_ = scanner.scanCharacter()
		
		// Optional width
		let widthStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")) ?? ""
		let width = widthStr.isEmpty ? nil : Int(widthStr)
		
		// Optional height and applePhotoID
		let height: Int?
		let applePhotoID: String?
		
		if scanner.scanCharacter() != nil { // consume comma if present
			// Height field exists
			let heightStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",\n")) ?? ""
			height = heightStr.isEmpty ? nil : Int(heightStr)
			
			// Check for optional applePhotoID (v6.0 format)
			if scanner.scanCharacter() != nil { // consume comma if present
				let applePhotoIDStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "\n")) ?? ""
				applePhotoID = applePhotoIDStr.isEmpty ? nil : applePhotoIDStr
			} else {
				applePhotoID = nil
			}
		} else {
			// No comma after width, so no height or applePhotoID
			height = nil
			applePhotoID = nil
		}
		
		self.md5 = md5
		self.filename = filename
		self.size = size
		self.photodate = Date(timeIntervalSince1970: photodateTimestamp)
		self.modified = Date(timeIntervalSince1970: modifiedTimestamp)
		self.width = width
		self.height = height
		self.applePhotoID = applePhotoID
	}
}
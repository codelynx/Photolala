//
//  PhotoDigestEntry.swift
//  Photolala
//
//  Level 2 Cache: Maps content MD5 to photo metadata and thumbnail reference
//

import Foundation
import SwiftData

/// SwiftData model for Level 2 cache: Content MD5 → Photo metadata
@Model
final class PhotoDigestEntry {
	/// Unique content MD5 hash
	@Attribute(.unique) let contentMD5: String
	
	// MARK: - File Metadata
	
	/// Original filename
	let filename: String
	
	/// File size in bytes
	let fileSize: Int64
	
	/// Image dimensions
	let pixelWidth: Int?
	let pixelHeight: Int?
	
	/// Photo dates
	let creationDate: Date?
	let modificationDate: Date?
	
	// MARK: - EXIF Metadata
	
	/// Camera information
	let cameraMake: String?
	let cameraModel: String?
	let lensModel: String?
	
	/// Photo settings
	let fNumber: Double?
	let exposureTime: Double?
	let isoSpeed: Int?
	let focalLength: Double?
	
	/// GPS location
	let latitude: Double?
	let longitude: Double?
	let altitude: Double?
	
	/// Orientation (EXIF value 1-8)
	let orientation: Int?
	
	// MARK: - Thumbnail Reference
	
	/// Whether thumbnail exists on disk
	let hasThumbnail: Bool
	
	/// Thumbnail file size in bytes
	let thumbnailSize: Int?
	
	/// Thumbnail dimensions (usually 256x256 or smaller)
	let thumbnailWidth: Int?
	let thumbnailHeight: Int?
	
	// MARK: - Cache Management
	
	/// When this entry was created
	let createdDate: Date
	
	/// When this entry was last accessed
	var lastAccessDate: Date
	
	/// Initialize a new photo digest entry
	init(contentMD5: String,
		 filename: String,
		 fileSize: Int64,
		 pixelWidth: Int? = nil,
		 pixelHeight: Int? = nil,
		 creationDate: Date? = nil,
		 modificationDate: Date? = nil,
		 cameraMake: String? = nil,
		 cameraModel: String? = nil,
		 lensModel: String? = nil,
		 fNumber: Double? = nil,
		 exposureTime: Double? = nil,
		 isoSpeed: Int? = nil,
		 focalLength: Double? = nil,
		 latitude: Double? = nil,
		 longitude: Double? = nil,
		 altitude: Double? = nil,
		 orientation: Int? = nil,
		 hasThumbnail: Bool = false,
		 thumbnailSize: Int? = nil,
		 thumbnailWidth: Int? = nil,
		 thumbnailHeight: Int? = nil) {
		
		self.contentMD5 = contentMD5
		self.filename = filename
		self.fileSize = fileSize
		self.pixelWidth = pixelWidth
		self.pixelHeight = pixelHeight
		self.creationDate = creationDate
		self.modificationDate = modificationDate
		self.cameraMake = cameraMake
		self.cameraModel = cameraModel
		self.lensModel = lensModel
		self.fNumber = fNumber
		self.exposureTime = exposureTime
		self.isoSpeed = isoSpeed
		self.focalLength = focalLength
		self.latitude = latitude
		self.longitude = longitude
		self.altitude = altitude
		self.orientation = orientation
		self.hasThumbnail = hasThumbnail
		self.thumbnailSize = thumbnailSize
		self.thumbnailWidth = thumbnailWidth
		self.thumbnailHeight = thumbnailHeight
		self.createdDate = Date()
		self.lastAccessDate = Date()
	}
	
	/// Update access time when entry is used
	func touch() {
		self.lastAccessDate = Date()
	}
	
	/// Get the URL for the thumbnail file
	var thumbnailURL: URL {
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let photolalaDir = cacheDir.appendingPathComponent("com.electricwoods.photolala")
		let thumbnailsDir = photolalaDir.appendingPathComponent("thumbnails")
		
		// Use first 2 characters of MD5 for sharding
		let shard = String(contentMD5.prefix(2))
		let shardDir = thumbnailsDir.appendingPathComponent(shard)
		
		return shardDir.appendingPathComponent("\(contentMD5).jpg")
	}
	
	/// Check if thumbnail file exists on disk
	var thumbnailExists: Bool {
		FileManager.default.fileExists(atPath: thumbnailURL.path)
	}
}
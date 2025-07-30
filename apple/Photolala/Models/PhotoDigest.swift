//
//  PhotoDigest.swift
//  Photolala
//
//  Unified thumbnail and metadata representation
//

import Foundation
import SwiftUI

/// Unified representation of a photo's thumbnail and metadata
struct PhotoDigest: Codable {
	let md5Hash: String
	let thumbnailData: Data
	let metadata: PhotoMetadata
	
	/// Get thumbnail image
	var thumbnail: XImage? {
		XImage(data: thumbnailData)
	}
}

/// Photo metadata information
struct PhotoMetadata: Codable {
	let filename: String
	let fileSize: Int64
	let pixelWidth: Int?
	let pixelHeight: Int?
	let creationDate: Date?
	let modificationTimestamp: Int  // Unix seconds
	
	/// Get modification date from timestamp
	var modificationDate: Date {
		Date(timeIntervalSince1970: TimeInterval(modificationTimestamp))
	}
}

// MARK: - Cache Key Generation

/// File identity for Level 1 cache
struct FileIdentityKey {
	let pathMD5: String
	let fileSize: Int64
	let modificationTimestamp: Int
	
	init(path: String, fileSize: Int64, modificationDate: Date) {
		self.pathMD5 = path.normalizedPath.lowercased().md5Hash
		self.fileSize = fileSize
		self.modificationTimestamp = Int(modificationDate.timeIntervalSince1970)
	}
	
	/// Cache key for Level 1 lookup
	var cacheKey: String {
		"\(pathMD5)|\(fileSize)|\(modificationTimestamp)"
	}
}

// MARK: - String Extensions

extension String {
	/// Get normalized path (resolves symlinks, ~, etc.)
	var normalizedPath: String {
		return (self as NSString).standardizingPath
	}
	
	/// Compute MD5 hash of string
	var md5Hash: String {
		// Use existing MD5 extension from project
		return self.md5
	}
}
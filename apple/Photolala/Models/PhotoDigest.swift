//
//  PhotoDigest.swift
//  Photolala
//
//  Unified thumbnail and metadata representation
//

import Foundation
import SwiftUI
import XPlatform

/// Unified representation of a photo's metadata (thumbnail stored separately on disk)
struct PhotoDigest: Codable {
	let md5Hash: String
	let metadata: PhotoDigestMetadata
	
	/// Load thumbnail image from disk cache
	func loadThumbnail() -> XImage? {
		let cacheURL = PhotoDigest.thumbnailURL(for: md5Hash)
		guard let data = try? Data(contentsOf: cacheURL) else { return nil }
		return XImage(data: data)
	}
	
	/// Get thumbnail URL for an MD5 hash
	static func thumbnailURL(for md5: String) -> URL {
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let photolalaDir = cacheDir.appendingPathComponent("com.electricwoods.photolala")
		let thumbnailsDir = photolalaDir.appendingPathComponent("thumbnails")
		
		// Use first 2 characters for sharding
		let shard = String(md5.prefix(2))
		let shardDir = thumbnailsDir.appendingPathComponent(shard)
		return shardDir.appendingPathComponent("\(md5).dat")
	}
	
	/// Save thumbnail to disk cache
	static func saveThumbnail(_ thumbnailData: Data, for md5: String) throws {
		let url = thumbnailURL(for: md5)
		
		// Create shard directory if needed
		let shardDir = url.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: shardDir, withIntermediateDirectories: true)
		
		// Write thumbnail data
		try thumbnailData.write(to: url)
	}
}

/// Simplified metadata for PhotoDigest (different from full PhotoMetadata class)
struct PhotoDigestMetadata: Codable {
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
	let path: String
	let fileSize: Int64
	
	init(path: String, fileSize: Int64, modificationDate: Date? = nil) {
		self.path = path.normalizedPath
		self.fileSize = fileSize
		// modificationDate is ignored - we only use path + file size for caching
	}
	
	/// Cache key for Level 1 lookup - uses path + file size only
	var cacheKey: String {
		Self.buildKey(path: path, fileSize: fileSize)
	}
	
	/// Build a cache key from components (centralized key generation)
	static func buildKey(path: String, fileSize: Int64) -> String {
		let normalizedPath = path.normalizedPath
		return "\(normalizedPath):\(fileSize)"
	}
}

// MARK: - String Extensions

import CryptoKit

extension String {
	/// Get normalized path (resolves symlinks, ~, etc.)
	var normalizedPath: String {
		return (self as NSString).standardizingPath
	}
	
	/// Compute MD5 hash of string
	var md5Hash: String {
		let data = Data(self.utf8)
		let hash = Insecure.MD5.hash(data: data)
		return hash.map { String(format: "%02hhx", $0) }.joined()
	}
}
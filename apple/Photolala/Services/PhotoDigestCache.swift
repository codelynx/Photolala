//
//  PhotoDigestCache.swift
//  Photolala
//
//  Level 2 cache: Maps content MD5 to PhotoDigest
//

import Foundation
import SwiftUI

/// Cache that maps content MD5 to PhotoDigest (thumbnail + metadata)
@MainActor
class PhotoDigestCache {
	static let shared = PhotoDigestCache()
	
	private let memoryCache = NSCache<NSString, PhotoDigest>()
	private let cacheBaseURL: URL
	
	private init() {
		// Configure memory cache
		memoryCache.countLimit = 500  // Max items
		memoryCache.totalCostLimit = 100 * 1024 * 1024  // 100MB
		
		// Cache directory
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let photolalaDir = cacheDir.appendingPathComponent("com.electricwoods.photolala")
		self.cacheBaseURL = photolalaDir.appendingPathComponent("photos")
		
		// Create base directory
		try? FileManager.default.createDirectory(at: cacheBaseURL, withIntermediateDirectories: true)
	}
	
	// MARK: - Public API
	
	/// Get PhotoDigest from cache
	func getPhotoDigest(for md5: String) async -> PhotoDigest? {
		// Check memory cache first
		if let cached = memoryCache.object(forKey: md5 as NSString) {
			return cached
		}
		
		// Check disk cache
		return await loadFromDisk(md5: md5)
	}
	
	/// Store PhotoDigest in cache
	func setPhotoDigest(_ digest: PhotoDigest, for md5: String) async {
		// Store in memory cache
		let cost = digest.thumbnailData.count
		memoryCache.setObject(digest, forKey: md5 as NSString, cost: cost)
		
		// Store on disk
		await saveToDisk(digest: digest, md5: md5)
	}
	
	/// Remove PhotoDigest from cache
	func removePhotoDigest(for md5: String) async {
		// Remove from memory
		memoryCache.removeObject(forKey: md5 as NSString)
		
		// Remove from disk
		await removeFromDisk(md5: md5)
	}
	
	/// Clear all caches
	func clearAll() async {
		// Clear memory
		memoryCache.removeAllObjects()
		
		// Clear disk
		try? FileManager.default.removeItem(at: cacheBaseURL)
		try? FileManager.default.createDirectory(at: cacheBaseURL, withIntermediateDirectories: true)
	}
	
	// MARK: - Private Disk Operations
	
	private func shardedDirectory(for md5: String) -> URL {
		// Use first 2 characters for sharding
		let prefix = String(md5.prefix(2))
		return cacheBaseURL.appendingPathComponent(prefix)
	}
	
	private func thumbnailURL(for md5: String) -> URL {
		shardedDirectory(for: md5).appendingPathComponent("\(md5).dat")
	}
	
	private func metadataURL(for md5: String) -> URL {
		shardedDirectory(for: md5).appendingPathComponent("\(md5).json")
	}
	
	private func loadFromDisk(md5: String) async -> PhotoDigest? {
		let thumbnailPath = thumbnailURL(for: md5)
		let metadataPath = metadataURL(for: md5)
		
		guard FileManager.default.fileExists(atPath: thumbnailPath.path),
			  FileManager.default.fileExists(atPath: metadataPath.path) else {
			return nil
		}
		
		do {
			// Load thumbnail data
			let thumbnailData = try Data(contentsOf: thumbnailPath)
			
			// Load and decode metadata
			let metadataData = try Data(contentsOf: metadataPath)
			let metadata = try JSONDecoder().decode(PhotoMetadata.self, from: metadataData)
			
			// Create PhotoDigest
			let digest = PhotoDigest(
				md5Hash: md5,
				thumbnailData: thumbnailData,
				metadata: metadata
			)
			
			// Store in memory cache for faster access
			let cost = thumbnailData.count
			memoryCache.setObject(digest, forKey: md5 as NSString, cost: cost)
			
			return digest
		} catch {
			print("[PhotoDigestCache] Failed to load from disk: \(error)")
			return nil
		}
	}
	
	private func saveToDisk(digest: PhotoDigest, md5: String) async {
		let shardDir = shardedDirectory(for: md5)
		let thumbnailPath = thumbnailURL(for: md5)
		let metadataPath = metadataURL(for: md5)
		
		do {
			// Create shard directory if needed
			try FileManager.default.createDirectory(at: shardDir, withIntermediateDirectories: true)
			
			// Save thumbnail data
			try digest.thumbnailData.write(to: thumbnailPath)
			
			// Save metadata
			let metadataData = try JSONEncoder().encode(digest.metadata)
			try metadataData.write(to: metadataPath)
			
		} catch {
			print("[PhotoDigestCache] Failed to save to disk: \(error)")
		}
	}
	
	private func removeFromDisk(md5: String) async {
		let thumbnailPath = thumbnailURL(for: md5)
		let metadataPath = metadataURL(for: md5)
		
		try? FileManager.default.removeItem(at: thumbnailPath)
		try? FileManager.default.removeItem(at: metadataPath)
	}
}
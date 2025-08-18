//
//  ApplePhotosMetadataCache.swift
//  Photolala
//
//  Dual-path caching system for Apple Photos Library
//  - Fast path: photo-id based for browsing
//  - Backup path: MD5-based for starred/backup items
//

import Foundation
import Photos
import SwiftUI

@MainActor
class ApplePhotosMetadataCache {
	static let shared = ApplePhotosMetadataCache()
	
	// Two-tier caching strategy
	private var photoIDCache = NSCache<NSString, PhotoMetadata>()
	private var photoIDToMD5: [String: String] = [:] // Persistent mapping
	private var processingQueue = Set<String>() // Prevent duplicate processing
	
	private init() {
		loadPhotoIDToMD5Mapping()
		
		// Configure cache
		photoIDCache.countLimit = 500
	}
	
	// MARK: - Public API
	
	/// Get metadata for browsing (fast path - no MD5 needed)
	func getMetadataForBrowsing(_ photo: PhotoApple) async -> PhotoMetadata {
		let photoID = photo.id
		
		// Check memory cache first
		if let cached = photoIDCache.object(forKey: photoID as NSString) {
			return cached
		}
		
		// Create basic metadata from PHAsset (no file loading)
		let metadata = PhotoMetadata(
			dateTaken: photo.asset.creationDate,
			fileModificationDate: photo.asset.modificationDate ?? Date(),
			fileSize: 0, // Will be loaded lazily if needed
			pixelWidth: photo.asset.pixelWidth,
			pixelHeight: photo.asset.pixelHeight,
			cameraMake: nil, // Could extract from asset metadata
			cameraModel: nil,
			orientation: nil,
			gpsLatitude: photo.asset.location?.coordinate.latitude,
			gpsLongitude: photo.asset.location?.coordinate.longitude,
			applePhotoID: photoID
		)
		
		// Cache it
		photoIDCache.setObject(metadata, forKey: photoID as NSString)
		
		return metadata
	}
	
	/// Get metadata for backup (requires MD5 - loads original if needed)
	func getMetadataForBackup(_ photo: PhotoApple) async throws -> (md5: String, metadata: PhotoMetadata) {
		let photoID = photo.id
		
		// Check if we already have MD5 mapping
		if let md5 = photoIDToMD5[photoID] {
			// Try to load from MD5-based cache
			// Try to get metadata from PhotoManagerV2's cache
			if let wrapper = PhotoManagerV2.shared.memoryCache.object(forKey: md5 as NSString) as? PhotoDigestWrapper {
				let digest = wrapper.digest
				let metadata = PhotoMetadata(
					dateTaken: digest.metadata.creationDate,
					fileModificationDate: Date(timeIntervalSince1970: TimeInterval(digest.metadata.modificationTimestamp)),
					fileSize: digest.metadata.fileSize,
					pixelWidth: digest.metadata.pixelWidth,
					pixelHeight: digest.metadata.pixelHeight,
					applePhotoID: photoID
				)
				return (md5, metadata)
			}
		}
		
		// Prevent duplicate processing
		if processingQueue.contains(photoID) {
			// Wait a bit and retry
			try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
			return try await getMetadataForBackup(photo)
		}
		
		processingQueue.insert(photoID)
		defer { processingQueue.remove(photoID) }
		
		// Process the photo completely
		// Use PhotoManagerV2 to get PhotoDigest for backup
		let digest = try await PhotoManagerV2.shared.photoDigestForBackup(for: photo)
		let result = (
			md5: digest.md5Hash,
			metadata: PhotoMetadata(
				dateTaken: digest.metadata.creationDate,
				fileModificationDate: Date(timeIntervalSince1970: TimeInterval(digest.metadata.modificationTimestamp)),
				fileSize: digest.metadata.fileSize,
				pixelWidth: digest.metadata.pixelWidth,
				pixelHeight: digest.metadata.pixelHeight,
				applePhotoID: photoID
			)
		)
		
		// Store the mapping
		photoIDToMD5[photoID] = result.md5
		savePhotoIDToMD5Mapping()
		
		// Update photoID cache with full metadata
		photoIDCache.setObject(result.metadata, forKey: photoID as NSString)
		
		return (result.md5, result.metadata)
	}
	
	/// Check if photo has been processed (has MD5)
	func isProcessed(_ photoID: String) -> Bool {
		return photoIDToMD5[photoID] != nil
	}
	
	/// Get MD5 if available (without loading photo data)
	func getCachedMD5(_ photoID: String) -> String? {
		return photoIDToMD5[photoID]
	}
	
	// MARK: - Persistence
	
	private var mappingURL: URL {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let photolalaDir = appSupport.appendingPathComponent("Photolala", isDirectory: true)
		try? FileManager.default.createDirectory(at: photolalaDir, withIntermediateDirectories: true)
		return photolalaDir.appendingPathComponent("apple-photos-md5-mapping.json")
	}
	
	private func loadPhotoIDToMD5Mapping() {
		guard let data = try? Data(contentsOf: mappingURL),
		      let mapping = try? JSONDecoder().decode([String: String].self, from: data) else {
			return
		}
		photoIDToMD5 = mapping
		print("[ApplePhotosMetadataCache] Loaded \(mapping.count) photo ID to MD5 mappings")
	}
	
	private func savePhotoIDToMD5Mapping() {
		guard let data = try? JSONEncoder().encode(photoIDToMD5) else { return }
		try? data.write(to: mappingURL)
	}
	
	// MARK: - Background Processing
	
	/// Optionally pre-process photos in background to build MD5 mapping
	func preProcessPhotosInBackground(limit: Int = 100) async {
		// This could be called periodically to gradually build the mapping
		let fetchResult = PHAsset.fetchAssets(with: .image, options: nil)
		var processed = 0
		
		fetchResult.enumerateObjects { asset, index, stop in
			if processed >= limit {
				stop.pointee = true
				return
			}
			
			let photoID = asset.localIdentifier
			if self.photoIDToMD5[photoID] == nil {
				// Queue for background processing
				Task.detached(priority: .background) {
					let photo = PhotoApple(asset: asset)
					_ = try? await self.getMetadataForBackup(photo)
				}
				processed += 1
			}
		}
		
		print("[ApplePhotosMetadataCache] Queued \(processed) photos for background processing")
	}
}
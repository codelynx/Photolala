//
//  ApplePhotosBridge.swift
//  Photolala
//
//  Created by Khanh Yoshikawa on 6/21/2025.
//

import Foundation
import Photos
import OSLog

/// Bridge service for mapping Apple Photo IDs to MD5 hashes
/// Uses actor for thread safety and persists mappings to UserDefaults
@globalActor
actor ApplePhotosBridge {
	static let shared = ApplePhotosBridge()
	
	private let logger = Logger(subsystem: "com.electricwoods.Photolala", category: "ApplePhotosBridge")
	private let userDefaultsKey = "com.electricwoods.Photolala.ApplePhotoMappings"
	private let maxBatchSize = 100
	
	// In-memory cache for performance
	private var cache: [String: String] = [:]
	private var isDirty = false
	
	private init() {
		Task {
			await loadFromDisk()
		}
	}
	
	// MARK: - Public Methods
	
	/// Get MD5 hash for an Apple Photo ID
	/// - Parameter photoID: The PHAsset.localIdentifier
	/// - Returns: MD5 hash if found, nil otherwise
	func getMD5(for photoID: String) async -> String? {
		return cache[photoID]
	}
	
	/// Store MD5 hash for an Apple Photo ID
	/// - Parameters:
	///   - md5: The MD5 hash to store
	///   - photoID: The PHAsset.localIdentifier
	func storeMD5(_ md5: String, for photoID: String) async {
		cache[photoID] = md5
		isDirty = true
		
		// Auto-save after a certain number of changes
		if cache.count % 50 == 0 {
			await saveToDisk()
		}
		
		// logger.debug("Stored mapping: \(photoID) -> \(md5)")
	}
	
	/// Check if MD5 exists for an Apple Photo ID
	/// - Parameter photoID: The PHAsset.localIdentifier
	/// - Returns: true if MD5 exists, false otherwise
	func hasMD5(for photoID: String) async -> Bool {
		return cache[photoID] != nil
	}
	
	/// Batch retrieve MD5 hashes for multiple photo IDs
	/// - Parameter photoIDs: Array of PHAsset.localIdentifiers
	/// - Returns: Dictionary mapping photo IDs to their MD5 hashes (only includes found mappings)
	func getMD5s(for photoIDs: [String]) async -> [String: String] {
		var results: [String: String] = [:]
		
		for photoID in photoIDs {
			if let md5 = cache[photoID] {
				results[photoID] = md5
			}
		}
		
		return results
	}
	
	/// Batch store MD5 hashes for multiple photo IDs
	/// - Parameter mappings: Dictionary mapping photo IDs to MD5 hashes
	func storeMD5s(_ mappings: [String: String]) async {
		guard !mappings.isEmpty else { return }
		
		// Process in batches to avoid overwhelming memory
		let batches = mappings.chunked(into: maxBatchSize)
		
		for batch in batches {
			for (photoID, md5) in batch {
				cache[photoID] = md5
			}
		}
		
		isDirty = true
		await saveToDisk()
		
		logger.info("Stored \(mappings.count) mappings in batches")
	}
	
	/// Remove mapping for a photo ID
	/// - Parameter photoID: The PHAsset.localIdentifier to remove
	func removeMD5(for photoID: String) async {
		cache.removeValue(forKey: photoID)
		isDirty = true
		logger.debug("Removed mapping for: \(photoID)")
	}
	
	/// Clear all mappings
	func clearAll() async {
		cache.removeAll()
		isDirty = true
		await saveToDisk()
		logger.info("Cleared all mappings")
	}
	
	/// Force save current mappings to disk
	func flush() async {
		if isDirty {
			await saveToDisk()
		}
	}
	
	/// Get statistics about stored mappings
	func getStatistics() async -> BridgeStatistics {
		return BridgeStatistics(
			totalMappings: cache.count,
			isDirty: isDirty
		)
	}
	
	// MARK: - Private Methods
	
	private func loadFromDisk() {
		do {
			if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
				let decoder = JSONDecoder()
				cache = try decoder.decode([String: String].self, from: data)
				isDirty = false
				logger.info("Loaded \(self.cache.count) mappings from disk")
			} else {
				logger.info("No existing mappings found")
			}
		} catch {
			logger.error("Failed to load mappings: \(error.localizedDescription)")
			cache = [:]
		}
	}
	
	private func saveToDisk() {
		do {
			let encoder = JSONEncoder()
			let data = try encoder.encode(cache)
			UserDefaults.standard.set(data, forKey: userDefaultsKey)
			isDirty = false
			logger.debug("Saved \(self.cache.count) mappings to disk")
		} catch {
			logger.error("Failed to save mappings: \(error.localizedDescription)")
		}
	}
}

// MARK: - Supporting Types

struct BridgeStatistics {
	let totalMappings: Int
	let isDirty: Bool
}

// MARK: - Helper Extensions

private extension Dictionary {
	func chunked(into size: Int) -> [[Key: Value]] {
		var chunks: [[Key: Value]] = []
		var currentChunk: [Key: Value] = [:]
		
		for (key, value) in self {
			currentChunk[key] = value
			
			if currentChunk.count >= size {
				chunks.append(currentChunk)
				currentChunk = [:]
			}
		}
		
		if !currentChunk.isEmpty {
			chunks.append(currentChunk)
		}
		
		return chunks
	}
}

// MARK: - PHAsset Extension for Convenience

extension PHAsset {
	/// Convenience method to get MD5 for this asset
	func getMD5() async -> String? {
		await ApplePhotosBridge.shared.getMD5(for: self.localIdentifier)
	}
	
	/// Convenience method to store MD5 for this asset
	func storeMD5(_ md5: String) async {
		await ApplePhotosBridge.shared.storeMD5(md5, for: self.localIdentifier)
	}
	
	/// Convenience method to check if MD5 exists for this asset
	func hasMD5() async -> Bool {
		await ApplePhotosBridge.shared.hasMD5(for: self.localIdentifier)
	}
}
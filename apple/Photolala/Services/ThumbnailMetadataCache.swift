//
//  ThumbnailMetadataCache.swift
//  Photolala
//
//  Created by Photolala on 2025/06/25.
//

import Foundation

/// Metadata for cached thumbnails to avoid recomputing MD5 hashes
struct ThumbnailMetadata: Codable {
	let filePath: String
	let md5Hash: String
	let fileSize: Int64
	let modificationDate: Date
	let lastAccessDate: Date
	
	/// Check if metadata is still valid for the given file attributes
	func isValid(fileSize: Int64, modificationDate: Date) -> Bool {
		return self.fileSize == fileSize && self.modificationDate == modificationDate
	}
}

/// Manages persistent metadata cache for thumbnails
@MainActor
class ThumbnailMetadataCache {
	static let shared = ThumbnailMetadataCache()
	
	private var metadata: [String: ThumbnailMetadata] = [:]
	private let cacheURL: URL
	private let saveQueue = DispatchQueue(label: "com.photolala.thumbnail-metadata", qos: .background)
	private var saveTask: DispatchWorkItem?
	
	private init() {
		// Initialize cache file location
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let photolalaDir = appSupport.appendingPathComponent("Photolala")
		
		// Ensure directory exists
		try? FileManager.default.createDirectory(at: photolalaDir, withIntermediateDirectories: true)
		
		self.cacheURL = photolalaDir.appendingPathComponent("thumbnail-metadata.json")
		
		// Load existing metadata
		loadMetadata()
		
		// Clean up old entries periodically
		scheduleCleanup()
	}
	
	// MARK: - Public API
	
	/// Get cached MD5 for a file if metadata is still valid
	func getCachedMD5(for filePath: String, fileSize: Int64, modificationDate: Date) -> String? {
		guard let metadata = metadata[filePath] else { return nil }
		
		// Check if file hasn't changed
		if metadata.isValid(fileSize: fileSize, modificationDate: modificationDate) {
			// Update access date
			updateAccessDate(for: filePath)
			return metadata.md5Hash
		}
		
		// File changed, remove stale metadata
		self.metadata.removeValue(forKey: filePath)
		scheduleSave()
		return nil
	}
	
	/// Store metadata for a file
	func setMetadata(filePath: String, md5Hash: String, fileSize: Int64, modificationDate: Date) {
		let metadata = ThumbnailMetadata(
			filePath: filePath,
			md5Hash: md5Hash,
			fileSize: fileSize,
			modificationDate: modificationDate,
			lastAccessDate: Date()
		)
		
		self.metadata[filePath] = metadata
		scheduleSave()
	}
	
	/// Remove metadata for a file
	func removeMetadata(for filePath: String) {
		metadata.removeValue(forKey: filePath)
		scheduleSave()
	}
	
	/// Clear all metadata
	func clearAll() {
		metadata.removeAll()
		scheduleSave()
	}
	
	// MARK: - Private Methods
	
	private func loadMetadata() {
		guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
		
		do {
			let data = try Data(contentsOf: cacheURL)
			let decoder = JSONDecoder()
			let metadataArray = try decoder.decode([ThumbnailMetadata].self, from: data)
			
			// Convert to dictionary
			self.metadata = Dictionary(uniqueKeysWithValues: metadataArray.map { ($0.filePath, $0) })
			
			print("[ThumbnailMetadataCache] Loaded \(metadata.count) entries")
		} catch {
			print("[ThumbnailMetadataCache] Failed to load metadata: \(error)")
		}
	}
	
	private func saveMetadata() {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = .prettyPrinted
			
			// Convert to array for storage
			let metadataArray = Array(metadata.values)
			let data = try encoder.encode(metadataArray)
			
			try data.write(to: cacheURL)
			print("[ThumbnailMetadataCache] Saved \(metadata.count) entries")
		} catch {
			print("[ThumbnailMetadataCache] Failed to save metadata: \(error)")
		}
	}
	
	private func scheduleSave() {
		// Cancel any pending save
		saveTask?.cancel()
		
		// Schedule a new save after a short delay to batch updates
		let task = DispatchWorkItem { [weak self] in
			Task { @MainActor in
				self?.saveMetadata()
			}
		}
		
		saveTask = task
		saveQueue.asyncAfter(deadline: .now() + 1.0, execute: task)
	}
	
	private func updateAccessDate(for filePath: String) {
		guard var metadata = metadata[filePath] else { return }
		
		// Create updated metadata with new access date
		let updated = ThumbnailMetadata(
			filePath: metadata.filePath,
			md5Hash: metadata.md5Hash,
			fileSize: metadata.fileSize,
			modificationDate: metadata.modificationDate,
			lastAccessDate: Date()
		)
		
		self.metadata[filePath] = updated
	}
	
	private func scheduleCleanup() {
		// Clean up entries not accessed in 30 days
		Task {
			try? await Task.sleep(nanoseconds: 60 * 60 * NSEC_PER_SEC) // Check every hour
			
			await MainActor.run {
				cleanupOldEntries()
				scheduleCleanup() // Reschedule
			}
		}
	}
	
	private func cleanupOldEntries() {
		let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
		var removedCount = 0
		
		for (filePath, metadata) in self.metadata {
			// Remove if not accessed recently or file no longer exists
			if metadata.lastAccessDate < cutoffDate || !FileManager.default.fileExists(atPath: filePath) {
				self.metadata.removeValue(forKey: filePath)
				removedCount += 1
			}
		}
		
		if removedCount > 0 {
			print("[ThumbnailMetadataCache] Cleaned up \(removedCount) old entries")
			scheduleSave()
		}
	}
}
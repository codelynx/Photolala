//
//  LocalCatalogCache.swift
//  Photolala
//
//  Local cache of S3 catalog for offline star state tracking
//

import Foundation
import OSLog

/// Manages a local mirror of the S3 catalog for offline star state tracking
actor LocalCatalogCache {
	private let logger = Logger(subsystem: "com.photolala", category: "LocalCatalogCache")
	
	// Cache persistence
	private let cacheURL: URL
	private let catalogService: CatalogService
	
	// In-memory cache
	private var cachedMD5s: Set<String> = []
	private var cachedFastKeys: Set<String> = []  // Fast photo keys (head-md5:size)
	private var lastSyncDate: Date?
	private var isSyncing = false
	
	// Sync configuration
	private let syncInterval: TimeInterval = 3600 // 1 hour
	private var syncTask: Task<Void, Error>?
	
	init(catalogService: CatalogService) {
		self.catalogService = catalogService
		
		// Setup cache directory
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
												   in: .userDomainMask).first!
		let cacheDir = appSupport
			.appendingPathComponent("Photolala", isDirectory: true)
			.appendingPathComponent("CatalogCache", isDirectory: true)
		
		try? FileManager.default.createDirectory(at: cacheDir,
												  withIntermediateDirectories: true)
		
		self.cacheURL = cacheDir.appendingPathComponent("catalog_cache.json")
		
		// Load existing cache
		Task {
			await loadCache()
		}
	}
	
	deinit {
		syncTask?.cancel()
	}
	
	// MARK: - Public API
	
	/// Check if a photo is starred (exists in cache)
	func isStarred(md5: String) -> Bool {
		cachedMD5s.contains(md5)
	}

	/// Check if a photo is starred by Fast Photo Key
	func isStarredByFastKey(headMD5: String, fileSize: Int64) -> Bool {
		let fastKey = "\(headMD5.lowercased()):\(fileSize)"
		let isStarred = cachedFastKeys.contains(fastKey)
		print("[LocalCatalogCache] Checking Fast Key \(fastKey): \(isStarred)")
		print("  - Available keys: \(Array(cachedFastKeys.prefix(5)))")
		return isStarred
	}

	/// Check if a photo is starred by Fast Photo Key string
	func isStarredByFastKey(_ fastKey: String) -> Bool {
		cachedFastKeys.contains(fastKey.lowercased())
	}

	/// Add MD5 to cache (when starring locally)
	func addToCache(md5: String, fastKey: String? = nil) {
		cachedMD5s.insert(md5)
		if let fastKey = fastKey {
			cachedFastKeys.insert(fastKey.lowercased())
		}
		Task {
			await saveCache()
		}
		logger.debug("Added MD5 to cache: \(md5)")
	}
	
	/// Remove MD5 from cache (when unstarring locally)
	func removeFromCache(md5: String) {
		cachedMD5s.remove(md5)
		Task {
			await saveCache()
		}
		logger.debug("Removed MD5 from cache: \(md5)")
	}
	
	/// Sync with S3 catalog
	func syncWithS3() async throws {
		guard !isSyncing else {
			logger.info("Sync already in progress")
			return
		}

		isSyncing = true
		defer { isSyncing = false }

		logger.info("Starting S3 catalog sync")

		// Get all MD5s and Fast Keys from catalog
		let allEntries = try await catalogService.getEntries()
		let newMD5s = Set(allEntries.compactMap { $0.photoMD5 })
		let newFastKeys = Set(allEntries.map { $0.fastPhotoKey.lowercased() })

		logger.info("Loaded \(allEntries.count) catalog entries")
		logger.info("Sample Fast Keys: \(Array(newFastKeys.prefix(3)))")

		// Update cache
		let added = newMD5s.subtracting(cachedMD5s)
		let removed = cachedMD5s.subtracting(newMD5s)

		cachedMD5s = newMD5s
		cachedFastKeys = newFastKeys
		lastSyncDate = Date()

		logger.info("Sync complete: \(self.cachedMD5s.count) MD5s, \(self.cachedFastKeys.count) Fast Keys, +\(added.count) -\(removed.count)")

		// Save to disk
		await saveCache()
	}
	
	/// Start periodic sync
	func startPeriodicSync() {
		syncTask?.cancel()
		syncTask = Task {
			while !Task.isCancelled {
				do {
					try await syncWithS3()
					try await Task.sleep(nanoseconds: UInt64(syncInterval * 1_000_000_000))
				} catch {
					if !Task.isCancelled {
						logger.error("Periodic sync failed: \(error)")
					}
					// Retry after delay
					try? await Task.sleep(nanoseconds: 60_000_000_000) // 1 minute
				}
			}
		}
	}
	
	/// Stop periodic sync
	func stopPeriodicSync() {
		syncTask?.cancel()
		syncTask = nil
	}

	/// Clear all cached data
	func clear() async {
		cachedMD5s.removeAll()
		cachedFastKeys.removeAll()
		lastSyncDate = nil

		// Stop any ongoing sync
		stopPeriodicSync()

		// Delete cache file from disk
		do {
			try FileManager.default.removeItem(at: cacheURL)
			logger.info("Cleared catalog cache and deleted cache file")
		} catch {
			logger.error("Error deleting cache file: \(error)")
		}
	}
	
	// MARK: - Private Methods
	
	private func loadCache() async {
		do {
			let data = try Data(contentsOf: cacheURL)
			let cache = try JSONDecoder().decode(CacheData.self, from: data)
			self.cachedMD5s = Set(cache.md5s)
			self.cachedFastKeys = Set(cache.fastKeys ?? [])
			self.lastSyncDate = cache.lastSync
			logger.info("Loaded cache: \(self.cachedMD5s.count) MD5s, \(self.cachedFastKeys.count) Fast Keys")
		} catch {
			logger.info("No existing cache or failed to load: \(error)")
			// Start fresh
			self.cachedMD5s = []
			self.cachedFastKeys = []
		}
	}
	
	private func saveCache() async {
		let cache = CacheData(
			md5s: Array(self.cachedMD5s),
			fastKeys: Array(self.cachedFastKeys),
			lastSync: self.lastSyncDate
		)

		do {
			let data = try JSONEncoder().encode(cache)
			try data.write(to: cacheURL, options: .atomic)
			logger.debug("Saved cache: \(self.cachedMD5s.count) MD5s")
		} catch {
			logger.error("Failed to save cache: \(error)")
		}
	}
	
	// MARK: - Cache Data Model
	
	private struct CacheData: Codable {
		let md5s: [String]
		let fastKeys: [String]?  // Added for Fast Photo Key support
		let lastSync: Date?
	}
}

// MARK: - Cache Statistics

extension LocalCatalogCache {
	/// Get cache statistics
	var statistics: CacheStatistics {
		CacheStatistics(
			totalStarred: cachedMD5s.count,
			lastSync: lastSyncDate,
			isSyncing: isSyncing,
			cacheSize: getCacheSize()
		)
	}
	
	private func getCacheSize() -> Int64 {
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: cacheURL.path)
			return attributes[.size] as? Int64 ?? 0
		} catch {
			return 0
		}
	}
}

struct CacheStatistics {
	let totalStarred: Int
	let lastSync: Date?
	let isSyncing: Bool
	let cacheSize: Int64
	
	var formattedCacheSize: String {
		ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .binary)
	}
	
	var syncStatusText: String {
		if isSyncing {
			return "Syncing..."
		} else if let lastSync = lastSync {
			let formatter = RelativeDateTimeFormatter()
			return "Last sync: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
		} else {
			return "Never synced"
		}
	}
}
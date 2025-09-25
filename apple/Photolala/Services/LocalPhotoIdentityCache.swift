//
//  LocalPhotoIdentityCache.swift
//  Photolala
//
//  Caches photo identities (MD5s) for local file paths to avoid recomputation
//

import Foundation
import OSLog

/// Caches photo identities for local file paths to avoid expensive MD5 computations
actor LocalPhotoIdentityCache {
	private let logger = Logger(subsystem: "com.photolala", category: "LocalPhotoIdentityCache")

	// Cache persistence
	private let cacheURL: URL

	// In-memory cache: path -> (headMD5, fileSize, fullMD5?, lastModified)
	private var cache: [String: CachedIdentity] = [:]

	// Statistics
	private var hits = 0
	private var misses = 0

	init() {
		// Setup cache directory
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
												   in: .userDomainMask).first!
		let cacheDir = appSupport
			.appendingPathComponent("Photolala", isDirectory: true)
			.appendingPathComponent("PhotoIdentityCache", isDirectory: true)

		try? FileManager.default.createDirectory(at: cacheDir,
												  withIntermediateDirectories: true)

		self.cacheURL = cacheDir.appendingPathComponent("identity_cache.json")

		// Load existing cache
		Task {
			await loadCache()
		}
	}

	// MARK: - Public API

	/// Get cached photo identity for a file path
	func getIdentity(for path: String) async -> PhotoIdentity? {
		// Check if file exists and get its modification date
		let url = URL(fileURLWithPath: path)
		guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
			  let modificationDate = attributes[.modificationDate] as? Date else {
			return nil
		}

		// Check cache
		if let cached = cache[path],
		   cached.lastModified == modificationDate {
			hits += 1
			logger.debug("Cache hit for \(path): \(cached.headMD5 ?? "nil"):\(cached.fileSize ?? 0)")
			return PhotoIdentity(
				headMD5: cached.headMD5,
				fileSize: cached.fileSize,
				fullMD5: cached.fullMD5
			)
		}

		misses += 1
		logger.debug("Cache miss for \(path)")
		return nil
	}

	/// Cache photo identity for a file path
	func cacheIdentity(_ identity: PhotoIdentity, for path: String) async {
		// Get file modification date
		let url = URL(fileURLWithPath: path)
		guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
			  let modificationDate = attributes[.modificationDate] as? Date else {
			return
		}

		// Update cache
		cache[path] = CachedIdentity(
			headMD5: identity.headMD5,
			fileSize: identity.fileSize,
			fullMD5: identity.fullMD5,
			lastModified: modificationDate
		)

		logger.debug("Cached identity for \(path): \(identity.headMD5 ?? "nil"):\(identity.fileSize ?? 0)")

		// Save periodically (every 100 new entries)
		if cache.count % 100 == 0 {
			await saveCache()
		}
	}

	/// Clear cache entries for paths that no longer exist
	func pruneCache() async {
		let startCount = cache.count
		cache = cache.filter { path, _ in
			FileManager.default.fileExists(atPath: path)
		}
		let removed = startCount - cache.count
		if removed > 0 {
			logger.info("Pruned \(removed) stale cache entries")
			await saveCache()
		}
	}

	/// Get cache statistics
	var statistics: CacheStatistics {
		CacheStatistics(
			entries: cache.count,
			hits: hits,
			misses: misses,
			hitRate: hits + misses > 0 ? Double(hits) / Double(hits + misses) : 0,
			cacheSize: getCacheSize()
		)
	}

	/// Force save cache to disk
	func flush() async {
		await saveCache()
	}

	// MARK: - Private Methods

	private func loadCache() async {
		do {
			let data = try Data(contentsOf: cacheURL)
			let cacheData = try JSONDecoder().decode(CacheData.self, from: data)

			// Validate cached entries still exist and haven't been modified
			var validEntries: [String: CachedIdentity] = [:]
			for (path, identity) in cacheData.entries {
				if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
				   let modificationDate = attributes[.modificationDate] as? Date,
				   modificationDate == identity.lastModified {
					validEntries[path] = identity
				}
			}

			self.cache = validEntries
			logger.info("Loaded \(validEntries.count) valid cache entries (from \(cacheData.entries.count) total)")
		} catch {
			logger.info("No existing cache or failed to load: \(error)")
			self.cache = [:]
		}
	}

	private func saveCache() async {
		let cacheData = CacheData(entries: cache)

		do {
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			let data = try encoder.encode(cacheData)
			try data.write(to: cacheURL, options: .atomic)
			logger.debug("Saved \(self.cache.count) cache entries")
		} catch {
			logger.error("Failed to save cache: \(error)")
		}
	}

	private func getCacheSize() -> Int64 {
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: cacheURL.path)
			return attributes[.size] as? Int64 ?? 0
		} catch {
			return 0
		}
	}

	// MARK: - Data Models

	private struct CachedIdentity: Codable {
		let headMD5: String?
		let fileSize: Int64?
		let fullMD5: String?
		let lastModified: Date
	}

	private struct CacheData: Codable {
		let entries: [String: CachedIdentity]
	}

	struct CacheStatistics {
		let entries: Int
		let hits: Int
		let misses: Int
		let hitRate: Double
		let cacheSize: Int64

		var formattedCacheSize: String {
			ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .binary)
		}

		var formattedHitRate: String {
			String(format: "%.1f%%", hitRate * 100)
		}
	}
}

// MARK: - Photo Identity Model

struct PhotoIdentity {
	let headMD5: String?
	let fileSize: Int64?
	let fullMD5: String?

	/// Fast Photo Key if available (head-MD5:file-size)
	var fastPhotoKey: String? {
		guard let headMD5 = headMD5, let fileSize = fileSize else { return nil }
		return "\(headMD5):\(fileSize)"
	}
}
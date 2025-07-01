//
//  MD5Cache.swift
//  Photolala
//
//  Cache for computed MD5 hashes to avoid recomputation
//

import Foundation
import SwiftData

@Model
final class MD5Cache {
	/// Cache key format: "{identifier}:{modification-unix}"
	/// Examples:
	/// - PHAsset: "12345-ABCD:1703001234"
	/// - S3: "bucket/key:1703001234"
	let cacheKey: String
	
	/// The computed MD5 hash (without prefix)
	let md5Hash: String
	
	/// When the hash was computed
	let computedDate: Date
	
	init(cacheKey: String, md5Hash: String) {
		self.cacheKey = cacheKey
		self.md5Hash = md5Hash
		self.computedDate = Date()
	}
}

// MARK: - Cache Manager

@MainActor
class MD5CacheManager {
	static let shared = MD5CacheManager()
	
	private var modelContext: ModelContext?
	
	private init() {}
	
	/// Set up the model context
	func setModelContext(_ context: ModelContext) {
		self.modelContext = context
	}
	
	/// Get cached MD5 hash for a key
	func getCachedMD5(for cacheKey: String) async -> String? {
		guard let modelContext = modelContext else { return nil }
		
		let descriptor = FetchDescriptor<MD5Cache>(
			predicate: #Predicate { cache in
				cache.cacheKey == cacheKey
			}
		)
		
		do {
			let results = try modelContext.fetch(descriptor)
			return results.first?.md5Hash
		} catch {
			print("[MD5CacheManager] Failed to fetch cache: \(error)")
			return nil
		}
	}
	
	/// Store MD5 hash in cache
	func storeMD5(_ md5Hash: String, for cacheKey: String) async {
		guard let modelContext = modelContext else { return }
		
		// Check if already exists
		let descriptor = FetchDescriptor<MD5Cache>(
			predicate: #Predicate { cache in
				cache.cacheKey == cacheKey
			}
		)
		
		do {
			let existing = try modelContext.fetch(descriptor)
			if existing.isEmpty {
				// Create new cache entry
				let cache = MD5Cache(cacheKey: cacheKey, md5Hash: md5Hash)
				modelContext.insert(cache)
				try modelContext.save()
			} else {
				// Update existing (shouldn't happen with our key format)
				print("[MD5CacheManager] Cache entry already exists for key: \(cacheKey)")
			}
		} catch {
			print("[MD5CacheManager] Failed to store cache: \(error)")
		}
	}
	
	/// Clear old cache entries (optional cleanup)
	func clearOldEntries(olderThan days: Int = 30) async {
		guard let modelContext = modelContext else { return }
		
		let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
		let descriptor = FetchDescriptor<MD5Cache>(
			predicate: #Predicate { cache in
				cache.computedDate < cutoffDate
			}
		)
		
		do {
			let oldEntries = try modelContext.fetch(descriptor)
			for entry in oldEntries {
				modelContext.delete(entry)
			}
			if !oldEntries.isEmpty {
				try modelContext.save()
				print("[MD5CacheManager] Cleared \(oldEntries.count) old cache entries")
			}
		} catch {
			print("[MD5CacheManager] Failed to clear old entries: \(error)")
		}
	}
}
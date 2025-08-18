//
//  FileIdentityCache.swift
//  Photolala
//
//  Level 1 Cache Service: Maps file identity to content MD5
//

import Foundation
import SwiftData

/// Level 1 cache service that maps file identity to content MD5
@MainActor
class FileIdentityCache {
	private let modelContext: ModelContext
	private var memoryCache: [String: String] = [:]  // identityKey → contentMD5
	private let maxMemoryCacheSize = 10000
	
	init(modelContext: ModelContext) {
		self.modelContext = modelContext
		Task {
			await preloadRecentEntries()
		}
	}
	
	// MARK: - Public API
	
	/// Get content MD5 for a file (sync for memory, async for database)
	func getContentMD5(path: String, fileSize: Int64) -> String? {
		let key = FileIdentityEntry.generateKey(
			path: path,
			fileSize: fileSize
		)
		
		// Check memory cache first (sync)
		if let md5 = memoryCache[key] {
			// Update access time in background
			Task.detached { [weak self] in
				await self?.updateAccessTime(key: key)
			}
			return md5
		}
		
		// Check database (requires fetch)
		let descriptor = FetchDescriptor<FileIdentityEntry>(
			predicate: #Predicate { entry in
				entry.identityKey == key
			}
		)
		
		do {
			if let entry = try modelContext.fetch(descriptor).first {
				// Add to memory cache
				if memoryCache.count < maxMemoryCacheSize {
					memoryCache[key] = entry.contentMD5
				}
				
				// Update access time
				entry.touch()
				try? modelContext.save()
				
				return entry.contentMD5
			}
		} catch {
			print("[FileIdentityCache] Fetch error: \(error)")
		}
		
		return nil
	}
	
	/// Store content MD5 for a file
	func setContentMD5(_ md5: String, path: String, fileSize: Int64) async {
		let key = FileIdentityEntry.generateKey(
			path: path,
			fileSize: fileSize
		)
		
		// Add to memory cache
		if memoryCache.count < maxMemoryCacheSize {
			memoryCache[key] = md5
		}
		
		// Check if already exists
		let descriptor = FetchDescriptor<FileIdentityEntry>(
			predicate: #Predicate { entry in
				entry.identityKey == key
			}
		)
		
		do {
			if try modelContext.fetch(descriptor).isEmpty {
				// Create new entry
				let entry = FileIdentityEntry(
					path: path,
					fileSize: fileSize,
					contentMD5: md5
				)
				modelContext.insert(entry)
				try modelContext.save()
			}
		} catch {
			print("[FileIdentityCache] Save error: \(error)")
		}
	}
	
	/// Remove entry for a file
	func removeEntry(path: String, fileSize: Int64, modificationDate: Date) async {
		let key = FileIdentityEntry.generateKey(
			path: path,
			fileSize: fileSize,
			modificationDate: modificationDate
		)
		
		// Remove from memory
		memoryCache.removeValue(forKey: key)
		
		// Remove from database
		let descriptor = FetchDescriptor<FileIdentityEntry>(
			predicate: #Predicate { entry in
				entry.identityKey == key
			}
		)
		
		do {
			let entries = try modelContext.fetch(descriptor)
			for entry in entries {
				modelContext.delete(entry)
			}
			if !entries.isEmpty {
				try modelContext.save()
			}
		} catch {
			print("[FileIdentityCache] Delete error: \(error)")
		}
	}
	
	/// Clean up old entries
	func cleanupOldEntries(olderThanDays days: Int = 90) async {
		let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
		
		let descriptor = FetchDescriptor<FileIdentityEntry>(
			predicate: #Predicate { entry in
				entry.lastAccessDate < cutoffDate
			}
		)
		
		do {
			let oldEntries = try modelContext.fetch(descriptor)
			for entry in oldEntries {
				modelContext.delete(entry)
				memoryCache.removeValue(forKey: entry.identityKey)
			}
			if !oldEntries.isEmpty {
				try modelContext.save()
				print("[FileIdentityCache] Cleaned up \(oldEntries.count) old entries")
			}
		} catch {
			print("[FileIdentityCache] Cleanup error: \(error)")
		}
	}
	
	// MARK: - Private Methods
	
	private func preloadRecentEntries() async {
		// Load recently accessed entries into memory
		let recentDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)  // Last week
		
		var descriptor = FetchDescriptor<FileIdentityEntry>(
			predicate: #Predicate { entry in
				entry.lastAccessDate > recentDate
			},
			sortBy: [SortDescriptor(\.lastAccessDate, order: .reverse)]
		)
		descriptor.fetchLimit = maxMemoryCacheSize / 2
		
		do {
			let entries = try modelContext.fetch(descriptor)
			for entry in entries {
				memoryCache[entry.identityKey] = entry.contentMD5
			}
			print("[FileIdentityCache] Preloaded \(entries.count) recent entries")
		} catch {
			print("[FileIdentityCache] Preload error: \(error)")
		}
	}
	
	private func updateAccessTime(key: String) async {
		await MainActor.run {
			let descriptor = FetchDescriptor<FileIdentityEntry>(
				predicate: #Predicate { entry in
					entry.identityKey == key
				}
			)
			
			do {
				if let entry = try modelContext.fetch(descriptor).first {
					entry.touch()
					try? modelContext.save()
				}
			} catch {
				print("[FileIdentityCache] Update access time error: \(error)")
			}
		}
	}
}
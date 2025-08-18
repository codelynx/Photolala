//
//  PathToMD5Cache.swift
//  Photolala
//
//  Level 1 cache: Maps file identity to content MD5
//

import Foundation

/// Cache that maps file paths (with attributes) to their content MD5 hashes
@MainActor
class PathToMD5Cache {
	static let shared = PathToMD5Cache()
	
	private var memoryCache: [String: String] = [:]  // cacheKey → contentMD5
	private let cacheURL: URL
	private var saveTask: DispatchWorkItem?
	private let saveQueue = DispatchQueue(label: "com.photolala.path-md5-cache", qos: .background)
	
	private init() {
		// Cache file location
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let photolalaDir = cacheDir.appendingPathComponent("com.electricwoods.photolala")
		try? FileManager.default.createDirectory(at: photolalaDir, withIntermediateDirectories: true)
		
		self.cacheURL = photolalaDir.appendingPathComponent("path-to-md5-cache.json")
		
		// Load existing cache
		loadCache()
	}
	
	// MARK: - Public API
	
	/// Get cached MD5 for file identity
	func getMD5(for path: String, fileSize: Int64) -> String? {
		let key = FileIdentityKey(path: path, fileSize: fileSize)
		return memoryCache[key.cacheKey]
	}
	
	/// Store MD5 for file identity
	func setMD5(_ md5: String, for path: String, fileSize: Int64) {
		let key = FileIdentityKey(path: path, fileSize: fileSize)
		memoryCache[key.cacheKey] = md5
		scheduleSave()
	}
	
	/// Remove entry for path
	func removeEntry(for path: String, fileSize: Int64) {
		let key = FileIdentityKey(path: path, fileSize: fileSize)
		memoryCache.removeValue(forKey: key.cacheKey)
		scheduleSave()
	}
	
	/// Clear all cache
	func clearAll() {
		memoryCache.removeAll()
		scheduleSave()
	}
	
	// MARK: - Private Methods
	
	private func loadCache() {
		guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
		
		do {
			let data = try Data(contentsOf: cacheURL)
			let cache = try JSONDecoder().decode([String: String].self, from: data)
			self.memoryCache = cache
			print("[PathToMD5Cache] Loaded \(cache.count) entries")
		} catch {
			print("[PathToMD5Cache] Failed to load cache: \(error)")
		}
	}
	
	private func saveCache() {
		do {
			let data = try JSONEncoder().encode(memoryCache)
			try data.write(to: cacheURL)
			print("[PathToMD5Cache] Saved \(memoryCache.count) entries")
		} catch {
			print("[PathToMD5Cache] Failed to save cache: \(error)")
		}
	}
	
	private func scheduleSave() {
		// Cancel pending save
		saveTask?.cancel()
		
		// Schedule new save after delay to batch updates
		let task = DispatchWorkItem { [weak self] in
			Task { @MainActor in
				self?.saveCache()
			}
		}
		
		saveTask = task
		saveQueue.asyncAfter(deadline: .now() + 1.0, execute: task)
	}
}
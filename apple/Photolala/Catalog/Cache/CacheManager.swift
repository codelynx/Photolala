//
//  CacheManager.swift
//  Photolala
//
//  Main cache coordination for thumbnails and metadata
//

import Foundation
import OSLog

/// Cache type for organizing storage
public enum CacheType: String, CaseIterable {
	case md5 = "md5"  // Unified MD5-based cache for local and S3
	case applePhotos = "apple"  // Separate for Apple Photos with different IDs
}

/// Main cache manager for coordinating thumbnail and metadata storage
public actor CacheManager {
	static let shared = CacheManager()

	private let logger = Logger(subsystem: "com.photolala", category: "CacheManager")
	private let fileManager = FileManager.default

	// Cache root directory
	private let cacheRoot: URL

	// Quota management
	private let maxCacheSizeBytes: Int64 = 10 * 1024 * 1024 * 1024 // 10GB default
	private var currentCacheSizeBytes: Int64 = 0

	private init() {
		// Setup cache root in Library/Caches
		let cachesDirectory = fileManager.urls(for: .cachesDirectory,
											   in: .userDomainMask).first!
		self.cacheRoot = cachesDirectory.appendingPathComponent("com.photolala.catalog")

		// Create root directory
		try? fileManager.createDirectory(at: cacheRoot,
										 withIntermediateDirectories: true)

		// Calculate initial cache size
		Task {
			await calculateCacheSize()
		}
	}

	// MARK: - Public API

	/// Get cache root directory
	public func getCacheRoot() -> URL {
		cacheRoot
	}

	/// Get cache directory for specific type
	public func getCacheDirectory(for type: CacheType) -> URL {
		let dir = cacheRoot.appendingPathComponent(type.rawValue)
		try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
		return dir
	}

	/// Get thumbnail cache path for a photo (MD5-based)
	public func getThumbnailPath(photoMD5: PhotoMD5, cacheType: CacheType = .md5) -> URL {
		let cacheDir = getCacheDirectory(for: cacheType)
			.appendingPathComponent("thumbnails")
			.appendingPathComponent(photoMD5.shardPrefix)  // First 2 chars for sharding

		try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

		return cacheDir.appendingPathComponent("\(photoMD5.value).jpg")
	}

	/// Get metadata cache path for a photo (MD5-based)
	public func getMetadataPath(photoMD5: PhotoMD5, cacheType: CacheType = .md5) -> URL {
		let cacheDir = getCacheDirectory(for: cacheType)
			.appendingPathComponent("metadata")
			.appendingPathComponent(photoMD5.shardPrefix)  // First 2 chars for sharding

		try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)

		return cacheDir.appendingPathComponent("\(photoMD5.value).json")
	}

	/// Get catalog CSV path
	public func getCatalogPath(directoryMD5: String, catalogMD5: String) -> URL {
		let catalogDir = cacheRoot
			.appendingPathComponent(directoryMD5)

		try? fileManager.createDirectory(at: catalogDir, withIntermediateDirectories: true)

		return catalogDir.appendingPathComponent(".photolala.\(catalogMD5).csv")
	}

	/// Get catalog pointer path
	public func getCatalogPointerPath(directoryMD5: String) -> URL {
		let catalogDir = cacheRoot
			.appendingPathComponent(directoryMD5)

		try? fileManager.createDirectory(at: catalogDir, withIntermediateDirectories: true)

		return catalogDir.appendingPathComponent(".photolala.md5")
	}

	/// Get working catalog path (mutable copy used during processing)
	public func getWorkingCatalogPath(directoryMD5: String) -> URL {
		let catalogDir = cacheRoot
			.appendingPathComponent(directoryMD5)

		try? fileManager.createDirectory(at: catalogDir, withIntermediateDirectories: true)

		return catalogDir.appendingPathComponent(".photolala.csv")  // Simplified naming
	}

	// MARK: - Cache Management

	/// Clean old cache entries if over quota
	public func cleanCacheIfNeeded() async {
		guard currentCacheSizeBytes > maxCacheSizeBytes else { return }

		logger.info("Cache size \(self.currentCacheSizeBytes) exceeds quota \(self.maxCacheSizeBytes)")

		// Get all cache files sorted by access time
		let files = await getAllCacheFiles()
		let sortedFiles = files.sorted { $0.accessDate < $1.accessDate }

		var bytesDeleted: Int64 = 0
		let targetSize = maxCacheSizeBytes * 8 / 10 // Clean to 80% of quota

		for file in sortedFiles {
			guard currentCacheSizeBytes - bytesDeleted > targetSize else { break }

			do {
				try fileManager.removeItem(at: file.url)
				bytesDeleted += file.size
				logger.debug("Deleted cache file: \(file.url.lastPathComponent)")
			} catch {
				logger.error("Failed to delete cache file: \(error)")
			}
		}

		currentCacheSizeBytes -= bytesDeleted
		logger.info("Cleaned \(bytesDeleted) bytes from cache")
	}

	/// Calculate total cache size
	private func calculateCacheSize() async {
		let files = await getAllCacheFiles()
		currentCacheSizeBytes = files.reduce(0) { $0 + $1.size }
		logger.info("Total cache size: \(self.currentCacheSizeBytes) bytes")
	}

	/// Get all cache files with metadata
	private func getAllCacheFiles() async -> [CacheFile] {
		var files: [CacheFile] = []

		let enumerator = fileManager.enumerator(
			at: cacheRoot,
			includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey],
			options: [.skipsHiddenFiles]
		)

		while let url = enumerator?.nextObject() as? URL {
			guard url.isFileURL else { continue }

			do {
				let attributes = try url.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey])
				let size = Int64(attributes.fileSize ?? 0)
				let accessDate = attributes.contentAccessDate ?? Date.distantPast

				files.append(CacheFile(url: url, size: size, accessDate: accessDate))
			} catch {
				logger.warning("Failed to get attributes for \(url): \(error)")
			}
		}

		return files
	}

	/// Store data in cache with size tracking
	public func storeData(_ data: Data, at url: URL) async throws {
		try data.write(to: url)
		currentCacheSizeBytes += Int64(data.count)

		// Check if cleanup needed
		if currentCacheSizeBytes > maxCacheSizeBytes {
			await cleanCacheIfNeeded()
		}
	}

	/// Clear all caches
	public func clearAllCaches() async throws {
		try fileManager.removeItem(at: cacheRoot)
		try fileManager.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
		currentCacheSizeBytes = 0
		logger.info("All caches cleared")
	}

	/// Clear cache for specific type
	public func clearCache(type: CacheType) async throws {
		let dir = getCacheDirectory(for: type)
		try fileManager.removeItem(at: dir)
		try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
		await calculateCacheSize()
		logger.info("Cache cleared for type: \(type.rawValue)")
	}
}

// MARK: - Supporting Types

private struct CacheFile {
	let url: URL
	let size: Int64
	let accessDate: Date
}
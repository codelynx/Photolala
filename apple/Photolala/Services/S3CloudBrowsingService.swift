//
//  S3CloudBrowsingService.swift
//  Photolala
//
//  Cloud catalog browsing with progressive thumbnail loading
//

import Foundation
import OSLog
import CryptoKit

/// Service for browsing cloud-backed photo catalogs
public actor S3CloudBrowsingService {
	private let logger = Logger(subsystem: "com.photolala", category: "S3CloudBrowsingService")
	private let s3Service: S3Service
	private let cacheManager: CacheManager

	// Cached cloud catalog
	private var cloudDatabase: CatalogDatabase?
	private var currentUserID: String?

	// Thumbnail cache
	private var thumbnailCache: [String: Data] = [:]
	private let maxMemoryCache = 50

	// MARK: - Initialization

	public init(s3Service: S3Service) {
		self.s3Service = s3Service
	}

	// MARK: - Public API

	/// Load cloud catalog from S3
	public func loadCloudCatalog(userID: String) async throws -> CatalogDatabase {
		logger.info("Loading cloud catalog for user: \(userID)")

		// 1. Get catalog pointer
		let pointer = try await s3Service.downloadCatalogPointer(userID: userID)
		logger.debug("Found catalog pointer: \(pointer)")

		// 2. Download catalog CSV
		let csvData = try await s3Service.downloadCatalog(
			catalogMD5: pointer,
			userID: userID
		)
		logger.debug("Downloaded catalog: \(csvData.count) bytes")

		// 3. Create temporary file for CSV
		let tempPath = FileManager.default.temporaryDirectory
			.appendingPathComponent("cloud-catalog-\(pointer).csv")

		// Write CSV data
		try csvData.write(to: tempPath)

		// 4. Create read-only database from CSV
		let database = try await CatalogDatabase(path: tempPath, readOnly: true)

		// Cache for reuse
		self.cloudDatabase = database
		self.currentUserID = userID

		let entryCount = await database.getEntryCount()
		logger.info("Loaded cloud catalog with \(entryCount) entries")

		return database
	}

	/// Get cached cloud catalog
	public func getCachedCatalog() -> CatalogDatabase? {
		cloudDatabase
	}

	/// Load thumbnail with progressive loading
	public func loadThumbnail(photoMD5: String, userID: String) async -> Data? {
		// 1. Check memory cache
		if let cached = thumbnailCache[photoMD5] {
			logger.debug("Thumbnail found in memory cache: \(photoMD5)")
			return cached
		}

		// 2. Check local disk cache
		let localPath = await cacheManager.getThumbnailPath(
			photoMD5: PhotoMD5(photoMD5),
			cacheType: .md5
		)

		if FileManager.default.fileExists(atPath: localPath.path) {
			do {
				let data = try Data(contentsOf: localPath)
				updateMemoryCache(photoMD5: photoMD5, data: data)
				logger.debug("Thumbnail found in disk cache: \(photoMD5)")
				return data
			} catch {
				logger.warning("Failed to load cached thumbnail: \(error)")
			}
		}

		// 3. Download from S3
		do {
			let data = try await s3Service.downloadThumbnail(
				md5: photoMD5,
				userID: userID
			)

			// 4. Save to local cache
			try await cacheManager.storeData(data, at: localPath)
			updateMemoryCache(photoMD5: photoMD5, data: data)

			logger.info("Downloaded thumbnail from S3: \(photoMD5)")
			return data

		} catch {
			logger.error("Failed to download thumbnail: \(error)")
			return nil
		}
	}

	/// Download full photo on demand
	public func downloadPhoto(photoMD5: String, userID: String) async throws -> Data {
		logger.info("Downloading full photo: \(photoMD5)")

		// Check if we have it in local cache
		let photosDirectory = FileManager.default.temporaryDirectory
			.appendingPathComponent("cloud-photos", isDirectory: true)

		try FileManager.default.createDirectory(
			at: photosDirectory,
			withIntermediateDirectories: true
		)

		let localPath = photosDirectory.appendingPathComponent("\(photoMD5).dat")

		if FileManager.default.fileExists(atPath: localPath.path) {
			logger.debug("Photo found in local cache: \(photoMD5)")
			return try Data(contentsOf: localPath)
		}

		// Download from S3
		let data = try await s3Service.downloadPhoto(
			md5: photoMD5,
			userID: userID
		)

		// Cache locally for future use
		try data.write(to: localPath)
		logger.info("Downloaded and cached photo: \(photoMD5)")

		return data
	}

	/// Prefetch thumbnails for visible items
	public func prefetchThumbnails(photoMD5s: [String], userID: String) async {
		await withTaskGroup(of: Void.self) { group in
			for md5 in photoMD5s.prefix(10) {  // Limit concurrent downloads
				group.addTask { [weak self] in
					_ = await self?.loadThumbnail(photoMD5: md5, userID: userID)
				}
			}
		}
	}

	/// Clear cached data
	public func clearCache() {
		thumbnailCache.removeAll()
		cloudDatabase = nil
		currentUserID = nil
		logger.info("Cleared cloud browser cache")
	}

	// MARK: - Private Methods

	/// Update memory cache with LRU eviction
	private func updateMemoryCache(photoMD5: String, data: Data) {
		// Simple LRU: Remove oldest if cache is full
		if thumbnailCache.count >= maxMemoryCache {
			// Remove first (oldest) item
			if let firstKey = thumbnailCache.keys.first {
				thumbnailCache.removeValue(forKey: firstKey)
			}
		}
		thumbnailCache[photoMD5] = data
	}

	/// Get catalog entries for UI display
	public func getCatalogEntries() async -> [CatalogEntry] {
		guard let database = cloudDatabase else { return [] }
		return await database.getAllEntries()
	}

	/// Check if catalog is loaded
	public func isCatalogLoaded() -> Bool {
		cloudDatabase != nil
	}

	/// Get current user ID
	public func getCurrentUserID() -> String? {
		currentUserID
	}
}

// MARK: - Cloud Photo Item

/// Photo item from cloud catalog for display
public struct CloudPhotoItem: Identifiable, Sendable {
	public let id: String  // MD5
	public let entry: CatalogEntry
	public let userID: String

	public var displayName: String {
		"Photo_\(entry.photoHeadMD5.prefix(8))"
	}

	public var photoDate: Date {
		entry.photoDate
	}

	public var format: ImageFormat {
		entry.format
	}

	public var fileSize: Int64 {
		entry.fileSize
	}

	public var hasThumbnail: Bool {
		// Cloud photos should always have thumbnails
		true
	}

	public init(entry: CatalogEntry, userID: String) {
		self.id = entry.photoMD5 ?? entry.fastPhotoKey
		self.entry = entry
		self.userID = userID
	}
}
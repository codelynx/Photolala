import Foundation
import AWSS3

/// Service for syncing .photolala catalogs with S3
actor S3CatalogSyncService {
	
	// MARK: - Types
	
	enum SyncError: LocalizedError {
		case manifestMissing
		case shardCorrupted(String)
		case versionMismatch(String)
		case syncFailed(Error)
		case networkTimeout
		case insufficientStorage
		case invalidUserId
		
		var errorDescription: String? {
			switch self {
			case .manifestMissing:
				return "Catalog manifest not found"
			case .shardCorrupted(let shard):
				return "Catalog shard \(shard) is corrupted"
			case .versionMismatch(let message):
				return "Catalog version mismatch: \(message)"
			case .syncFailed(let error):
				return "Sync failed: \(error.localizedDescription)"
			case .networkTimeout:
				return "Network timeout during sync"
			case .insufficientStorage:
				return "Insufficient storage for catalog cache"
			case .invalidUserId:
				return "Invalid user ID for catalog sync"
			}
		}
	}
	
	struct ETagCache: Codable {
		var etags: [String: String] // S3 key -> ETag
		var lastSync: Date
		
		func etagForKey(_ key: String) -> String? {
			etags[key]
		}
		
		mutating func updateETag(_ etag: String, for key: String) {
			etags[key] = etag
			lastSync = Date()
		}
	}
	
	// MARK: - Properties
	
	private let s3Client: S3Client
	private let bucketName = "photolala"
	private let userId: String
	private let cacheDir: URL
	private var etagCache: ETagCache
	
	private var catalogCacheDir: URL {
		cacheDir.appendingPathComponent("cloud.s3").appendingPathComponent(userId)
	}
	
	// MARK: - Initialization
	
	init(s3Client: S3Client, userId: String) throws {
		guard !userId.isEmpty else { throw SyncError.invalidUserId }
		
		self.s3Client = s3Client
		self.userId = userId
		
		// Set up cache directory
		#if os(iOS)
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		#else
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
			.appendingPathComponent("com.electricwoods.photolala")
		#endif
		
		self.cacheDir = cacheDir
		
		// Create catalog cache directory
		let catalogCacheDir = cacheDir.appendingPathComponent("cloud.s3").appendingPathComponent(userId)
		try FileManager.default.createDirectory(at: catalogCacheDir, withIntermediateDirectories: true)
		
		// Load or create ETag cache
		let etagCacheURL = catalogCacheDir.appendingPathComponent(".etag-cache")
		if let data = try? Data(contentsOf: etagCacheURL),
		   let cache = try? JSONDecoder().decode(ETagCache.self, from: data) {
			self.etagCache = cache
		} else {
			self.etagCache = ETagCache(etags: [:], lastSync: .distantPast)
		}
	}
	
	// MARK: - Public Methods
	
	/// Check if catalog sync is needed and perform if necessary
	func syncCatalogIfNeeded() async throws -> Bool {
		// Check if we should sync (more than 15 minutes since last sync)
		if Date().timeIntervalSince(etagCache.lastSync) < 900 { // 15 minutes
			return false
		}
		
		return try await performSync()
	}
	
	/// Force a catalog sync
	func forceSync() async throws -> Bool {
		return try await performSync()
	}
	
	/// Load the cached catalog
	func loadCachedCatalog() async throws -> PhotolalaCatalogService {
		let catalogService = PhotolalaCatalogService(catalogURL: catalogCacheDir)
		_ = try await catalogService.loadManifest()
		return catalogService
	}
	
	/// Load the S3 master catalog
	func loadS3MasterCatalog() async throws -> S3MasterCatalog? {
		let masterCatalogURL = catalogCacheDir.appendingPathComponent("master.photolala.json")
		
		guard FileManager.default.fileExists(atPath: masterCatalogURL.path) else {
			return nil
		}
		
		let data = try Data(contentsOf: masterCatalogURL)
		return try JSONDecoder().decode(S3MasterCatalog.self, from: data)
	}
	
	// MARK: - Private Methods
	
	private func performSync() async throws -> Bool {
		// 1. Check manifest ETag first (HeadObject - no download)
		let manifestKey = "catalog/\(userId)/.photolala"
		
		let manifestNeedsUpdate = try await checkETag(key: manifestKey)
		
		guard manifestNeedsUpdate else {
			throw SyncError.networkTimeout
		}
		
		if !manifestNeedsUpdate {
			// Still check master catalog
			_ = try await syncMasterCatalogIfNeeded()
			return false
		}
		
		// 2. Download manifest only if changed
		guard let manifestData = try await downloadFile(key: manifestKey) else {
			throw SyncError.manifestMissing
		}
		
		// Save manifest temporarily
		let tempDir = catalogCacheDir.appendingPathComponent(".tmp")
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		let tempManifestURL = tempDir.appendingPathComponent(".photolala")
		try manifestData.write(to: tempManifestURL)
		
		// 3. Check each shard's ETag before downloading
		var shardsToDownload: [String] = []
		for shardIndex in 0..<16 {
			let shardHex = String(format: "%x", shardIndex)
			let shardKey = "catalog/\(userId)/.photolala#\(shardHex)"
			
			if let needsUpdate = try? await checkETag(key: shardKey), needsUpdate {
				shardsToDownload.append(shardHex)
			}
		}
		
		// 4. Download only changed shards
		for shardHex in shardsToDownload {
			let shardKey = "catalog/\(userId)/.photolala#\(shardHex)"
			if let shardData = try await downloadFile(key: shardKey) {
				let tempShardURL = tempDir.appendingPathComponent(".photolala#\(shardHex)")
				try shardData.write(to: tempShardURL)
			}
		}
		
		// 5. Verify integrity and perform atomic update
		try await atomicUpdateCatalog(from: tempDir)
		
		// 6. Also sync master catalog
		try await syncMasterCatalogIfNeeded()
		
		// 7. Save ETag cache
		try saveETagCache()
		
		return true
	}
	
	private func checkETag(key: String) async throws -> Bool {
		let headRequest = HeadObjectInput(
			bucket: bucketName,
			key: key
		)
		
		do {
			let response = try await s3Client.headObject(input: headRequest)
			let remoteETag = response.eTag?.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
			
			// Compare with stored ETag
			let localETag = etagCache.etagForKey(key)
			return remoteETag != localETag
		} catch {
			// Object might not exist yet
			return true
		}
	}
	
	private func downloadFile(key: String) async throws -> Data? {
		// TODO: Implement proper S3 download using ByteStream
		// For now, return mock data for testing
		throw SyncError.networkTimeout
	}
	
	private func atomicUpdateCatalog(from tempDir: URL) async throws {
		// Verify all files exist in temp
		let requiredFiles = [".photolala"] + (0..<16).map { String(format: ".photolala#%x", $0) }
		
		for filename in requiredFiles {
			let tempFile = tempDir.appendingPathComponent(filename)
			if !FileManager.default.fileExists(atPath: tempFile.path) {
				// Copy from existing catalog if shard wasn't updated
				let existingFile = catalogCacheDir.appendingPathComponent(filename)
				if FileManager.default.fileExists(atPath: existingFile.path) {
					try FileManager.default.copyItem(at: existingFile, to: tempFile)
				}
			}
		}
		
		// Verify manifest and checksums
		let catalogService = PhotolalaCatalogService(catalogURL: tempDir)
		_ = try await catalogService.loadManifest()
		
		// TODO: Verify shard checksums match manifest
		
		// Atomic replace using FileManager
		if FileManager.default.fileExists(atPath: catalogCacheDir.path) {
			_ = try FileManager.default.replaceItemAt(catalogCacheDir, withItemAt: tempDir)
		} else {
			try FileManager.default.moveItem(at: tempDir, to: catalogCacheDir)
		}
	}
	
	private func syncMasterCatalogIfNeeded() async throws {
		let masterKey = "catalog/\(userId)/master.photolala.json"
		
		if let needsUpdate = try? await checkETag(key: masterKey), needsUpdate {
			if let data = try await downloadFile(key: masterKey) {
				let masterURL = catalogCacheDir.appendingPathComponent("master.photolala.json")
				try data.write(to: masterURL)
			}
		}
	}
	
	private func saveETagCache() throws {
		let etagCacheURL = catalogCacheDir.appendingPathComponent(".etag-cache")
		let data = try JSONEncoder().encode(etagCache)
		try data.write(to: etagCacheURL)
	}
}
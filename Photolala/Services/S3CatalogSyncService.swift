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
	
	/// Get the catalog URL for a given user ID
	func catalogURL(for userId: String) -> URL {
		return catalogCacheDir
	}
	
	private var catalogCacheDir: URL {
		// Don't use CacheManager.cloudCatalogURL as it auto-creates the directory
		// We need to manage directory creation ourselves for atomic updates
		return CacheManager.shared.cacheRootURL
			.appendingPathComponent("cloud")
			.appendingPathComponent("s3")
			.appendingPathComponent("catalogs")
			.appendingPathComponent(userId)
			.appendingPathComponent(".photolala")
	}
	
	// MARK: - Initialization
	
	init(s3Client: S3Client, userId: String) throws {
		guard !userId.isEmpty else { throw SyncError.invalidUserId }
		
		self.s3Client = s3Client
		self.userId = userId
		
		// We'll manage directory creation ourselves for atomic updates
		self.cacheDir = CacheManager.shared.cacheRootURL
			.appendingPathComponent("cloud")
			.appendingPathComponent("s3")
		
		// Initialize etagCache before using catalogCacheDir
		self.etagCache = ETagCache(etags: [:], lastSync: .distantPast)
		
		// Now we can use catalogCacheDir safely
		let catalogDir = CacheManager.shared.cacheRootURL
			.appendingPathComponent("cloud")
			.appendingPathComponent("s3")
			.appendingPathComponent("catalogs")
			.appendingPathComponent(userId)
			.appendingPathComponent(".photolala")
		
		#if DEBUG
		print("DEBUG: S3CatalogSyncService catalog cache dir: \(catalogDir.path)")
		#endif
		
		// Load ETag cache if it exists
		let etagCacheURL = catalogDir.appendingPathComponent(".etag-cache")
		if let data = try? Data(contentsOf: etagCacheURL),
		   let cache = try? JSONDecoder().decode(ETagCache.self, from: data) {
			self.etagCache = cache
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
		// PhotolalaCatalogService expects the parent directory (it adds .photolala itself)
		let parentDir = catalogCacheDir.deletingLastPathComponent()
		print("[S3CatalogSyncService] Loading cached catalog from: \(parentDir.path)")
		
		let catalogService = PhotolalaCatalogService(catalogURL: parentDir)
		do {
			let manifest = try await catalogService.loadManifest()
			print("[S3CatalogSyncService] Loaded manifest with \(manifest.photoCount) photos")
			return catalogService
		} catch {
			print("[S3CatalogSyncService] Failed to load manifest: \(error)")
			throw error
		}
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
		let manifestKey = "catalogs/\(userId)/.photolala/manifest.plist"
		
		let manifestNeedsUpdate: Bool
		do {
			manifestNeedsUpdate = try await checkETag(key: manifestKey)
		} catch {
			// If we can't check the ETag (e.g., network error), throw timeout
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
		// Create temp directory at the user level, not inside .photolala
		let userDir = catalogCacheDir.deletingLastPathComponent() // .../catalogs/{userId}
		let tempDirName = "tmp_\(UUID().uuidString)"
		let tempDir = userDir.appendingPathComponent(tempDirName)
		
		print("Creating temp directory at: \(tempDir.path)")
		print("User directory: \(userDir.path)")
		
		// Ensure user directory exists
		try FileManager.default.createDirectory(at: userDir, withIntermediateDirectories: true)
		
		// Create temp directory
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		
		print("Temp directory created successfully")
		
		// Save manifest (v5 structure)
		let tempCatalogDir = tempDir.appendingPathComponent(".photolala")
		try FileManager.default.createDirectory(at: tempCatalogDir, withIntermediateDirectories: true)
		let tempManifestURL = tempCatalogDir.appendingPathComponent("manifest.plist")
		try manifestData.write(to: tempManifestURL)
		
		print("Manifest written to temp directory")
		
		// 3. Check each shard's ETag before downloading
		var shardsToDownload: [String] = []
		for shardIndex in 0..<16 {
			let shardHex = String(format: "%x", shardIndex)
			let shardKey = "catalogs/\(userId)/.photolala/\(shardHex).csv"
			
			if let needsUpdate = try? await checkETag(key: shardKey), needsUpdate {
				shardsToDownload.append(shardHex)
			}
		}
		
		// 4. Download only changed shards
		for shardHex in shardsToDownload {
			let shardKey = "catalogs/\(userId)/.photolala/\(shardHex).csv"
			if let shardData = try await downloadFile(key: shardKey) {
				let tempShardURL = tempCatalogDir.appendingPathComponent("\(shardHex).csv")
				try shardData.write(to: tempShardURL)
			}
		}
		
		// 5. Verify integrity and perform atomic update
		do {
			try await atomicUpdateCatalog(from: tempDir)
		} catch {
			print("[S3CatalogSync] Atomic update failed: \(error)")
			throw error
		}
		
		// 6. Also sync master catalog
		do {
			try await syncMasterCatalogIfNeeded()
		} catch {
			print("[S3CatalogSync] Master catalog sync failed: \(error)")
			throw error
		}
		
		// 7. Save ETag cache
		do {
			try saveETagCache()
		} catch {
			print("[S3CatalogSync] ETag cache save failed: \(error)")
			throw error
		}
		
		print("[S3CatalogSync] Sync completed successfully")
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
		let getRequest = GetObjectInput(
			bucket: bucketName,
			key: key
		)
		
		let response = try await s3Client.getObject(input: getRequest)
		
		// Update ETag cache
		if let etag = response.eTag?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) {
			etagCache.updateETag(etag, for: key)
		}
		
		// Handle the ByteStream body
		guard let body = response.body else { return nil }
		
		// For catalog files which are small, we can read all data at once
		switch body {
		case .data(let data):
			// If body is already data, return it
			return data
			
		case .stream(let stream):
			// If body is a stream, collect all chunks
			var result = Data()
			while true {
				guard let chunk = try await stream.readAsync(upToCount: 65536) else {
					break
				}
				result.append(chunk)
			}
			return result
			
		case .noStream:
			// No data available
			return nil
			
		@unknown default:
			throw SyncError.syncFailed(NSError(domain: "S3CatalogSync", 
											   code: -1, 
											   userInfo: [NSLocalizedDescriptionKey: "Unknown ByteStream type"]))
		}
	}
	
	private func atomicUpdateCatalog(from tempDir: URL) async throws {
		// Verify all files exist in temp (v5 structure)
		let tempCatalogDir = tempDir.appendingPathComponent(".photolala")
		let requiredFiles = ["manifest.plist"] + (0..<16).map { String(format: "%x.csv", $0) }
		
		for filename in requiredFiles {
			let tempFile = tempCatalogDir.appendingPathComponent(filename)
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
		print("Starting atomic update from \(tempDir.path) to \(catalogCacheDir.path)")
		
		// Ensure temp catalog directory exists
		guard FileManager.default.fileExists(atPath: tempCatalogDir.path) else {
			print("ERROR: Temp catalog directory does not exist at: \(tempCatalogDir.path)")
			throw SyncError.syncFailed(NSError(domain: "S3CatalogSync", 
											   code: -1, 
											   userInfo: [NSLocalizedDescriptionKey: "Temporary catalog directory does not exist"]))
		}
		
		print("Temp catalog directory exists, proceeding with atomic update")
		
		// The catalogCacheDir is already the .photolala directory where catalog files should go
		// catalogCacheDir = .../cloud/s3/catalogs/{userId}/.photolala
		// tempDir = .../cloud/s3/catalogs/{userId}/tmp_UUID
		// tempCatalogDir = .../cloud/s3/catalogs/{userId}/tmp_UUID/.photolala
		
		// Since tempDir is already at the user level, we can directly work with tempCatalogDir
		let userDir = catalogCacheDir.deletingLastPathComponent() // .../cloud/s3/catalogs/{userId}
		
		// Move the old catalog out of the way if it exists
		let backupDir = userDir.appendingPathComponent("backup_\(UUID().uuidString)")
		
		// Move existing catalog to backup location if it exists
		if FileManager.default.fileExists(atPath: catalogCacheDir.path) {
			print("Moving existing catalog to backup: \(backupDir.path)")
			do {
				try FileManager.default.moveItem(at: catalogCacheDir, to: backupDir)
				print("Successfully moved existing catalog to backup")
			} catch {
				print("ERROR: Failed to move existing catalog to backup: \(error)")
				// If we can't move it, try to remove it
				print("Attempting to remove existing catalog instead")
				try FileManager.default.removeItem(at: catalogCacheDir)
			}
		}
		
		// Move the temp catalog directory to the final location
		print("Moving new catalog from \(tempCatalogDir.path) to \(catalogCacheDir.path)")
		do {
			try FileManager.default.moveItem(at: tempCatalogDir, to: catalogCacheDir)
			print("Atomic update completed successfully")
			
			// Clean up backup directory if it exists
			if FileManager.default.fileExists(atPath: backupDir.path) {
				print("Cleaning up backup directory")
				try? FileManager.default.removeItem(at: backupDir)
			}
			
			// Clean up temp directory
			if FileManager.default.fileExists(atPath: tempDir.path) {
				print("Cleaning up temp directory")
				try? FileManager.default.removeItem(at: tempDir)
			}
		} catch {
			print("ERROR: Failed to move catalog to final location: \(error)")
			print("Source: \(tempCatalogDir.path)")
			print("Destination: \(catalogCacheDir.path)")
			// Check what exists
			print("Source exists: \(FileManager.default.fileExists(atPath: tempCatalogDir.path))")
			print("Destination exists: \(FileManager.default.fileExists(atPath: catalogCacheDir.path))")
			
			// Try to restore backup if move failed
			if FileManager.default.fileExists(atPath: backupDir.path) && !FileManager.default.fileExists(atPath: catalogCacheDir.path) {
				print("Attempting to restore backup")
				try? FileManager.default.moveItem(at: backupDir, to: catalogCacheDir)
			}
			
			// Clean up temp directory on failure
			if FileManager.default.fileExists(atPath: tempDir.path) {
				try? FileManager.default.removeItem(at: tempDir)
			}
			
			throw error
		}
	}
	
	private func syncMasterCatalogIfNeeded() async throws {
		let masterKey = "catalogs/\(userId)/master.photolala.json"
		
		do {
			// Check if master catalog exists and needs update
			let needsUpdate = try await checkETag(key: masterKey)
			
			if needsUpdate {
				// Try to download master catalog
				if let data = try? await downloadFile(key: masterKey) {
					let masterURL = catalogCacheDir.appendingPathComponent("master.photolala.json")
					try data.write(to: masterURL)
					print("Master catalog synced successfully")
				} else {
					print("Master catalog download failed or doesn't exist yet")
				}
			}
		} catch {
			// Master catalog might not exist yet, which is fine
			print("Master catalog check failed (might not exist): \(error)")
		}
	}
	
	private func saveETagCache() throws {
		let etagCacheURL = catalogCacheDir.appendingPathComponent(".etag-cache")
		let data = try JSONEncoder().encode(etagCache)
		try data.write(to: etagCacheURL)
	}
}
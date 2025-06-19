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
		
		#if DEBUG
		print("DEBUG: S3CatalogSyncService catalog cache dir: \(catalogCacheDir.path)")
		#endif
		
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
		// Use a unique temporary directory name to avoid conflicts
		let tempDirName = "tmp_\(UUID().uuidString)"
		let tempDir = catalogCacheDir.appendingPathComponent(tempDirName)
		
		print("Creating temp directory at: \(tempDir.path)")
		print("Parent directory: \(catalogCacheDir.path)")
		
		// Ensure parent directory exists
		try FileManager.default.createDirectory(at: catalogCacheDir, withIntermediateDirectories: true)
		
		// Create temp directory
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: false)
		
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
				let existingCatalogDir = catalogCacheDir.appendingPathComponent(".photolala")
				let existingFile = existingCatalogDir.appendingPathComponent(filename)
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
		
		// Ensure temp directory exists
		guard FileManager.default.fileExists(atPath: tempDir.path) else {
			print("ERROR: Temp directory does not exist at: \(tempDir.path)")
			throw SyncError.syncFailed(NSError(domain: "S3CatalogSync", 
											   code: -1, 
											   userInfo: [NSLocalizedDescriptionKey: "Temporary catalog directory does not exist"]))
		}
		
		print("Temp directory exists, proceeding with atomic update")
		
		// The issue is that catalogCacheDir includes the userId, so we need to be careful
		// catalogCacheDir = .../cloud.s3/8E9D73F3-A405-4EC2-AF7F-15519DBA4640
		// tempDir = .../cloud.s3/8E9D73F3-A405-4EC2-AF7F-15519DBA4640/tmp_UUID
		
		// Since tempDir is inside catalogCacheDir, we need to move it to a sibling location first
		let parentDir = catalogCacheDir.deletingLastPathComponent() // .../cloud.s3
		let tempSiblingDir = parentDir.appendingPathComponent("tmp_move_\(UUID().uuidString)")
		
		print("Moving temp directory to sibling location: \(tempSiblingDir.path)")
		try FileManager.default.moveItem(at: tempDir, to: tempSiblingDir)
		
		// Now remove the old catalog directory if it exists
		if FileManager.default.fileExists(atPath: catalogCacheDir.path) {
			print("Removing existing catalog directory")
			try FileManager.default.removeItem(at: catalogCacheDir)
		}
		
		// Move the temp sibling directory to the final location
		print("Moving to final location")
		try FileManager.default.moveItem(at: tempSiblingDir, to: catalogCacheDir)
		print("Atomic update completed successfully")
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
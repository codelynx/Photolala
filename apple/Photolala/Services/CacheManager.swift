import Foundation

/// Centralized cache management for Photolala
/// Manages cache directory structure for both local and cloud storage
class CacheManager {
	static let shared = CacheManager()
	
	private let rootURL: URL
	
	/// Get the root cache URL (needed for S3CatalogSyncService)
	var cacheRootURL: URL { rootURL }
	
	private init() {
		rootURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("com.electricwoods.photolala")
		
		// Ensure root directory exists
		try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
		
		// Print cache structure for debugging
		#if DEBUG
		print("[CacheManager] Cache structure initialized:")
		print("  Root: \(rootURL.path)")
		print("  Local thumbnails: \(rootURL.path)/local/thumbnails/")
		print("  Local images: \(rootURL.path)/local/images/")
		print("  Cloud S3: \(rootURL.path)/cloud/s3/")
		#endif
	}
	
	// MARK: - Local Paths
	
	/// URL for local thumbnail cache
	/// - Parameter md5: MD5 hash of the photo
	/// - Returns: URL for the thumbnail file
	func localThumbnailURL(for md5: String) -> URL {
		let dir = rootURL
			.appendingPathComponent("local")
			.appendingPathComponent("thumbnails")
		
		// Ensure directory exists
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		
		return dir.appendingPathComponent("\(md5).dat")
	}
	
	/// URL for local full-size image cache
	/// - Parameter pathHash: Hash of the file path
	/// - Returns: URL for the cached image file
	func localImageURL(for pathHash: String) -> URL {
		let dir = rootURL
			.appendingPathComponent("local")
			.appendingPathComponent("images")
		
		// Ensure directory exists
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		
		return dir.appendingPathComponent("\(pathHash).dat")
	}
	
	// MARK: - Cloud Paths
	
	/// URL for cloud thumbnail cache
	/// - Parameters:
	///   - service: Cloud service type
	///   - userId: User identifier
	///   - md5: MD5 hash of the photo
	/// - Returns: URL for the thumbnail file
	func cloudThumbnailURL(service: CloudService, userId: String, md5: String) -> URL {
		let dir = rootURL
			.appendingPathComponent("cloud")
			.appendingPathComponent(service.rawValue)
			.appendingPathComponent("thumbnails")
			.appendingPathComponent(userId)
		
		// Ensure directory exists
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		
		return dir.appendingPathComponent("\(md5).dat")
	}
	
	/// URL for cloud photo cache
	/// - Parameters:
	///   - service: Cloud service type
	///   - userId: User identifier
	///   - md5: MD5 hash of the photo
	/// - Returns: URL for the photo file
	func cloudPhotoURL(service: CloudService, userId: String, md5: String) -> URL {
		let dir = rootURL
			.appendingPathComponent("cloud")
			.appendingPathComponent(service.rawValue)
			.appendingPathComponent("photos")
			.appendingPathComponent(userId)
		
		// Ensure directory exists
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		
		return dir.appendingPathComponent("\(md5).dat")
	}
	
	/// URL for cloud metadata cache
	/// - Parameters:
	///   - service: Cloud service type
	///   - userId: User identifier
	///   - md5: MD5 hash of the photo
	/// - Returns: URL for the metadata file
	func cloudMetadataURL(service: CloudService, userId: String, md5: String) -> URL {
		let dir = rootURL
			.appendingPathComponent("cloud")
			.appendingPathComponent(service.rawValue)
			.appendingPathComponent("metadata")
			.appendingPathComponent(userId)
		
		// Ensure directory exists
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		
		return dir.appendingPathComponent("\(md5).plist")
	}
	
	/// URL for cloud catalog cache
	/// - Parameters:
	///   - service: Cloud service type
	///   - userId: User identifier
	/// - Returns: URL for the catalog directory
	func cloudCatalogURL(service: CloudService, userId: String) -> URL {
		let dir = rootURL
			.appendingPathComponent("cloud")
			.appendingPathComponent(service.rawValue)
			.appendingPathComponent("catalogs")
			.appendingPathComponent(userId)
			.appendingPathComponent(".photolala")
		
		// Ensure directory exists
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		
		return dir
	}
	
	// MARK: - Legacy Paths (for migration)
	
	/// Check if legacy cache directories exist
	func hasLegacyCaches() -> Bool {
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
		let legacyPhotolala = cacheDir.appendingPathComponent("Photolala")
		let legacyBundleId = cacheDir.appendingPathComponent("com.electricwoods.photolala")
		
		return FileManager.default.fileExists(atPath: legacyPhotolala.path) ||
			   (FileManager.default.fileExists(atPath: legacyBundleId.path) && legacyBundleId != rootURL)
	}
	
	/// Get legacy thumbnail cache directory
	func legacyLocalThumbnailDirectory() -> URL? {
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
		let legacyDir = cacheDir
			.appendingPathComponent("Photolala")
			.appendingPathComponent("cache")
		
		if FileManager.default.fileExists(atPath: legacyDir.path) {
			return legacyDir
		}
		return nil
	}
	
	/// Get legacy S3 thumbnail directory
	func legacyS3ThumbnailDirectory() -> URL? {
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
		let legacyDir = cacheDir
			.appendingPathComponent("com.electricwoods.photolala")
			.appendingPathComponent("thumbnails.s3")
		
		if FileManager.default.fileExists(atPath: legacyDir.path) {
			return legacyDir
		}
		return nil
	}
	
	/// Get legacy S3 catalog directory
	func legacyS3CatalogDirectory() -> URL? {
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
		let legacyDir = cacheDir
			.appendingPathComponent("com.electricwoods.photolala")
			.appendingPathComponent("cloud.s3")
		
		if FileManager.default.fileExists(atPath: legacyDir.path) {
			return legacyDir
		}
		return nil
	}
	
	// MARK: - Cache Management
	
	/// Clear all caches
	func clearAllCaches() throws {
		try FileManager.default.removeItem(at: rootURL)
		try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
	}
	
	/// Clear local caches only
	func clearLocalCaches() throws {
		let localURL = rootURL.appendingPathComponent("local")
		if FileManager.default.fileExists(atPath: localURL.path) {
			try FileManager.default.removeItem(at: localURL)
		}
	}
	
	/// Clear cloud caches for a specific service
	func clearCloudCaches(for service: CloudService) throws {
		let serviceURL = rootURL
			.appendingPathComponent("cloud")
			.appendingPathComponent(service.rawValue)
		if FileManager.default.fileExists(atPath: serviceURL.path) {
			try FileManager.default.removeItem(at: serviceURL)
		}
	}
	
	/// Get cache size in bytes
	func cacheSize() -> Int64 {
		calculateDirectorySize(at: rootURL)
	}
	
	/// Get local cache size in bytes
	func localCacheSize() -> Int64 {
		let localURL = rootURL.appendingPathComponent("local")
		return calculateDirectorySize(at: localURL)
	}
	
	/// Get cloud cache size for a specific service in bytes
	func cloudCacheSize(for service: CloudService) -> Int64 {
		let serviceURL = rootURL
			.appendingPathComponent("cloud")
			.appendingPathComponent(service.rawValue)
		return calculateDirectorySize(at: serviceURL)
	}
	
	private func calculateDirectorySize(at url: URL) -> Int64 {
		guard let enumerator = FileManager.default.enumerator(
			at: url,
			includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
		) else { return 0 }
		
		var totalSize: Int64 = 0
		for case let fileURL as URL in enumerator {
			guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
				  let isRegularFile = resourceValues.isRegularFile,
				  isRegularFile,
				  let fileSize = resourceValues.fileSize else { continue }
			totalSize += Int64(fileSize)
		}
		
		return totalSize
	}
}

/// Cloud service types
enum CloudService: String {
	case s3 = "s3"
	case icloud = "icloud"
	// Future: dropbox, googledrive, etc.
}

// MARK: - Cache Migration

extension CacheManager {
	
	/// Perform migration from legacy cache structure if needed
	func performMigrationIfNeeded() {
		// Check if migration is needed
		guard hasLegacyCaches() else { return }
		
		// Check if already migrated (presence of migration marker)
		let migrationMarker = rootURL.appendingPathComponent(".migrated-v1")
		if FileManager.default.fileExists(atPath: migrationMarker.path) {
			return
		}
		
		print("[CacheManager] Starting cache migration...")
		
		// Perform migration in background
		Task.detached(priority: .background) {
			do {
				// Migrate local thumbnails
				if let legacyThumbnailDir = self.legacyLocalThumbnailDirectory() {
					try self.migrateLocalThumbnails(from: legacyThumbnailDir)
				}
				
				// Migrate S3 thumbnails
				if let legacyS3ThumbnailDir = self.legacyS3ThumbnailDirectory() {
					try self.migrateS3Thumbnails(from: legacyS3ThumbnailDir)
				}
				
				// Migrate S3 catalogs
				if let legacyS3CatalogDir = self.legacyS3CatalogDirectory() {
					try self.migrateS3Catalogs(from: legacyS3CatalogDir)
				}
				
				// Mark migration as complete
				try "v1".write(to: migrationMarker, atomically: true, encoding: .utf8)
				
				print("[CacheManager] Cache migration completed successfully")
				
				// Clean up empty legacy directories
				self.cleanupLegacyDirectories()
				
			} catch {
				print("[CacheManager] Cache migration failed: \(error)")
			}
		}
	}
	
	private func migrateLocalThumbnails(from legacyDir: URL) throws {
		let files = try FileManager.default.contentsOfDirectory(at: legacyDir, includingPropertiesForKeys: nil)
		var migratedCount = 0
		
		for file in files {
			// Skip non-thumbnail files
			guard file.pathExtension == "dat" || file.pathExtension == "jpg" else { continue }
			
			let filename = file.lastPathComponent
			
			// Extract MD5 hash from filename
			// Legacy format: "md5_abc123.dat" or "md5#abc123.jpg"
			let md5: String
			if filename.hasPrefix("md5_") {
				// Format: md5_abc123.dat
				md5 = filename
					.dropFirst(4) // Remove "md5_"
					.replacingOccurrences(of: ".dat", with: "")
					.replacingOccurrences(of: ".jpg", with: "")
			} else if filename.contains("md5#") {
				// Format: md5#abc123.jpg
				let components = filename.split(separator: "#")
				guard components.count == 2 else { continue }
				md5 = String(components[1])
					.replacingOccurrences(of: ".jpg", with: "")
					.replacingOccurrences(of: ".dat", with: "")
			} else {
				continue
			}
			
			// New path
			let newURL = localThumbnailURL(for: md5)
			
			// Skip if already exists
			if FileManager.default.fileExists(atPath: newURL.path) {
				continue
			}
			
			// Move file
			try FileManager.default.moveItem(at: file, to: newURL)
			migratedCount += 1
		}
		
		print("[CacheManager] Migrated \(migratedCount) local thumbnails")
	}
	
	private func migrateS3Thumbnails(from legacyDir: URL) throws {
		// Legacy S3 thumbnails are stored flat in thumbnails.s3/{md5}
		// Need to determine user ID - for now, use a placeholder migration
		
		let files = try FileManager.default.contentsOfDirectory(at: legacyDir, includingPropertiesForKeys: nil)
		
		// We can't migrate without knowing the user ID
		// Just log for now
		print("[CacheManager] Found \(files.count) S3 thumbnails in legacy location")
		print("[CacheManager] S3 thumbnail migration requires user ID - will be handled on next S3 access")
	}
	
	private func migrateS3Catalogs(from legacyDir: URL) throws {
		// Legacy catalogs are in cloud.s3/{userId}/.photolala/
		// New location is cloud/s3/catalogs/{userId}/.photolala/
		
		let userDirs = try FileManager.default.contentsOfDirectory(at: legacyDir, includingPropertiesForKeys: nil)
		var migratedCount = 0
		
		for userDir in userDirs {
			guard userDir.hasDirectoryPath else { continue }
			
			let userId = userDir.lastPathComponent
			let legacyCatalogDir = userDir.appendingPathComponent(".photolala")
			
			// Check if catalog exists
			if FileManager.default.fileExists(atPath: legacyCatalogDir.path) {
				// New location
				let newCatalogURL = cloudCatalogURL(service: .s3, userId: userId)
				
				// Skip if already exists
				if FileManager.default.fileExists(atPath: newCatalogURL.path) {
					continue
				}
				
				// Move entire catalog directory
				try FileManager.default.moveItem(at: legacyCatalogDir, to: newCatalogURL)
				migratedCount += 1
			}
		}
		
		print("[CacheManager] Migrated \(migratedCount) S3 catalogs")
	}
	
	private func cleanupLegacyDirectories() {
		// Clean up empty legacy directories
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
		
		// Try to remove legacy directories (will fail if not empty)
		let legacyDirs = [
			cacheDir.appendingPathComponent("Photolala"),
			cacheDir.appendingPathComponent("com.electricwoods.photolala") // Only if different from rootURL
		]
		
		for dir in legacyDirs {
			// Don't remove our new root
			if dir == rootURL { continue }
			
			do {
				// This will only succeed if directory is empty
				try FileManager.default.removeItem(at: dir)
				print("[CacheManager] Removed empty legacy directory: \(dir.lastPathComponent)")
			} catch {
				// Directory not empty or doesn't exist - that's fine
			}
		}
	}
}
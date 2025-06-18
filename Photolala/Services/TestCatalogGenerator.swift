#if DEBUG
import Foundation

/// Generates test catalog data for development
actor TestCatalogGenerator {
	
	static func generateTestCatalog(userId: String) async throws {
		// Create cache directory
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		#if os(macOS)
		let appCacheDir = cacheDir.appendingPathComponent("com.electricwoods.photolala")
		#else
		let appCacheDir = cacheDir
		#endif
		
		let catalogDir = appCacheDir.appendingPathComponent("cloud.s3").appendingPathComponent(userId)
		try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
		
		// Create catalog service
		let catalogService = PhotolalaCatalogService(catalogURL: catalogDir)
		
		// Create empty catalog if it doesn't exist
		let manifestURL = catalogDir.appendingPathComponent(".photolala")
		if !FileManager.default.fileExists(atPath: manifestURL.path) {
			try await catalogService.createEmptyCatalog()
			
			// Add some test entries
			let testPhotos = [
				("test_photo_001.jpg", "a1b2c3d4e5f6789012345678901234567", 1024 * 500), // 500KB
				("sunset_beach.jpg", "b2c3d4e5f678901234567890123456789", 1024 * 800), // 800KB
				("mountain_view.jpg", "c3d4e5f6789012345678901234567890", 1024 * 1200), // 1.2MB
				("family_portrait.jpg", "d4e5f678901234567890123456789012", 1024 * 600), // 600KB
				("vacation_2024.jpg", "e5f6789012345678901234567890123", 1024 * 900), // 900KB
				("birthday_party.jpg", "f67890123456789012345678901234", 1024 * 750), // 750KB
				("landscape_wide.jpg", "0789012345678901234567890123456", 1024 * 1500), // 1.5MB
				("portrait_mode.jpg", "1890123456789012345678901234567", 1024 * 400), // 400KB
				("night_sky.jpg", "2901234567890123456789012345678", 1024 * 1100), // 1.1MB
				("city_lights.jpg", "3012345678901234567890123456789", 1024 * 950), // 950KB
			]
			
			for (filename, md5, size) in testPhotos {
				let entry = PhotolalaCatalogService.CatalogEntry(
					md5: md5,
					filename: filename,
					size: Int64(size),
					photoDate: Date().addingTimeInterval(-Double.random(in: 0...(365 * 24 * 60 * 60))), // Random date within last year
					modified: Date(),
					width: Int.random(in: 2000...4000),
					height: Int.random(in: 1500...3000)
				)
				
				try await catalogService.upsertEntry(entry)
			}
			
			// Update manifest
			let manifest = PhotolalaCatalogService.CatalogManifest(
				version: 1,
				created: Date(),
				modified: Date(),
				shardChecksums: [:], // Will be updated when saving shards
				photoCount: testPhotos.count
			)
			
			try await catalogService.saveManifest(manifest)
			
			// Create a simple S3 master catalog
			let s3MasterCatalog = S3MasterCatalog(
				version: 1,
				userId: userId,
				lastUpdated: Date(),
				photos: Dictionary(uniqueKeysWithValues: testPhotos.map { (_, md5, _) in
					(md5, S3MasterCatalog.PhotoInfo(
						uploadDate: Date().addingTimeInterval(-Double.random(in: 0...(30 * 24 * 60 * 60))), // Random upload within last month
						storageClass: Bool.random() ? "STANDARD" : "DEEP_ARCHIVE",
						archiveDate: nil,
						lastAccessed: nil
					))
				})
			)
			
			let masterCatalogURL = catalogDir.appendingPathComponent("master.photolala.json")
			let encoder = JSONEncoder()
			encoder.outputFormatting = .prettyPrinted
			let masterData = try encoder.encode(s3MasterCatalog)
			try masterData.write(to: masterCatalogURL)
			
			print("DEBUG: Generated test catalog with \(testPhotos.count) photos at \(catalogDir.path)")
		} else {
			print("DEBUG: Test catalog already exists at \(catalogDir.path)")
		}
	}
}
#endif
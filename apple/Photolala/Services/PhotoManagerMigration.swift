//
//  PhotoManagerMigration.swift
//  Photolala
//
//  Helpers for migrating from PhotoManager to PhotoManagerV2
//

import Foundation

@MainActor
class PhotoManagerMigration {
	
	/// Check if old cache exists
	static func hasOldCache() -> Bool {
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let oldCacheDir = cacheDir.appendingPathComponent("Photolala/cache")
		return FileManager.default.fileExists(atPath: oldCacheDir.path)
	}
	
	/// Migrate thumbnails from old cache to new PhotoDigest cache
	static func migrateOldCache() async {
		print("[PhotoManagerMigration] Starting cache migration...")
		
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let oldCacheDir = cacheDir.appendingPathComponent("Photolala/cache")
		
		guard FileManager.default.fileExists(atPath: oldCacheDir.path) else {
			print("[PhotoManagerMigration] No old cache found")
			return
		}
		
		do {
			let files = try FileManager.default.contentsOfDirectory(at: oldCacheDir, includingPropertiesForKeys: nil)
			var migratedCount = 0
			
			for file in files where file.pathExtension == "dat" {
				// Extract MD5 from filename (format: md5_xxxxx.dat)
				let filename = file.lastPathComponent
				if filename.hasPrefix("md5_") {
					let md5 = String(filename.dropFirst(4).dropLast(4)) // Remove "md5_" and ".dat"
					
					// Check if already migrated
					if await PhotoDigestCache.shared.getPhotoDigest(for: md5) != nil {
						continue
					}
					
					// Load thumbnail data
					if let thumbnailData = try? Data(contentsOf: file) {
						// Create minimal PhotoDigest (we don't have metadata from old cache)
						let digest = PhotoDigest(
							md5Hash: md5,
							thumbnailData: thumbnailData,
							metadata: PhotoDigestMetadata(
								filename: "Unknown",
								fileSize: 0,
								pixelWidth: nil,
								pixelHeight: nil,
								creationDate: nil,
								modificationTimestamp: 0
							)
						)
						
						await PhotoDigestCache.shared.setPhotoDigest(digest, for: md5)
						migratedCount += 1
					}
				}
			}
			
			print("[PhotoManagerMigration] Migrated \(migratedCount) thumbnails")
			
			// Optionally remove old cache after successful migration
			// try FileManager.default.removeItem(at: oldCacheDir)
			
		} catch {
			print("[PhotoManagerMigration] Migration failed: \(error)")
		}
	}
	
	/// Check and perform migration if needed
	static func checkAndMigrate() async {
		if hasOldCache() {
			await migrateOldCache()
		}
	}
}
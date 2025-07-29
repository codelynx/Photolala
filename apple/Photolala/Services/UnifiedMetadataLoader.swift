//
//  UnifiedMetadataLoader.swift
//  Photolala
//
//  Unified metadata loading that checks SwiftData first, then falls back to cache
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class UnifiedMetadataLoader {
	static let shared = UnifiedMetadataLoader()
	
	private init() {}
	
	/// Load metadata for a photo, checking SwiftData catalog first, then falling back to cache
	func loadMetadata(for photo: any PhotoItem) async -> PhotoMetadata? {
		// For PhotoFile, check SwiftData catalog first
		if let photoFile = photo as? PhotoFile {
			// First check if it has cached metadata property
			if let cached = photoFile.metadata {
				return cached
			}
			
			// Try to get MD5 hash
			let md5Hash: String?
			if let existingHash = photoFile.md5Hash {
				md5Hash = existingHash
			} else {
				// Load MD5 if not available
				do {
					let data = try Data(contentsOf: photoFile.fileURL)
					let digest = PhotoManager.shared.md5Digest(of: data)
					md5Hash = digest.map { String(format: "%02x", $0) }.joined()
					photoFile.md5Hash = md5Hash
				} catch {
					print("[UnifiedMetadataLoader] Failed to compute MD5: \(error)")
					md5Hash = nil
				}
			}
			
			// Check SwiftData catalog if we have MD5
			if let md5 = md5Hash,
			   let catalogMetadata = await loadFromCatalog(md5: md5) {
				// Convert CatalogPhotoEntry to PhotoMetadata
				let metadata = PhotoMetadata(
					dateTaken: catalogMetadata.photoDate,
					fileModificationDate: catalogMetadata.fileModifiedDate,
					fileSize: catalogMetadata.fileSize,
					pixelWidth: catalogMetadata.pixelWidth,
					pixelHeight: catalogMetadata.pixelHeight,
					cameraMake: catalogMetadata.cameraMake,
					cameraModel: catalogMetadata.cameraModel,
					orientation: catalogMetadata.orientation,
					gpsLatitude: catalogMetadata.gpsLatitude,
					gpsLongitude: catalogMetadata.gpsLongitude,
					applePhotoID: catalogMetadata.applePhotoID
				)
				photoFile.metadata = metadata
				return metadata
			}
			
			// Fall back to PhotoManager cache
			do {
				let metadata = try await PhotoManager.shared.metadata(for: photoFile)
				photoFile.metadata = metadata
				return metadata
			} catch {
				print("[UnifiedMetadataLoader] Failed to load metadata from cache: \(error)")
				// Return nil to indicate failure
				return nil
			}
		}
		
		// For PhotoApple, create metadata from asset properties
		if let applePhoto = photo as? PhotoApple {
			let metadata = PhotoMetadata(
				dateTaken: applePhoto.creationDate,
				fileModificationDate: applePhoto.modificationDate ?? applePhoto.creationDate ?? Date(),
				fileSize: applePhoto.fileSize ?? 0,
				pixelWidth: applePhoto.width,
				pixelHeight: applePhoto.height,
				applePhotoID: applePhoto.id
			)
			return metadata
		}
		
		// For PhotoS3, create basic metadata
		if let s3Photo = photo as? PhotoS3 {
			let metadata = PhotoMetadata(
				dateTaken: nil,
				fileModificationDate: s3Photo.modified,
				fileSize: s3Photo.size,
				pixelWidth: s3Photo.width,
				pixelHeight: s3Photo.height
			)
			return metadata
		}
		
		return nil
	}
	
	/// Load extended EXIF data for display in inspector
	func loadExtendedMetadata(for photo: any PhotoItem, baseMetadata: PhotoMetadata) async -> ExtendedPhotoMetadata {
		var extended = ExtendedPhotoMetadata(base: baseMetadata)
		
		// For PhotoFile, try to get extended EXIF data
		if let photoFile = photo as? PhotoFile {
			// Check if we have extended data in SwiftData
			if let md5 = photoFile.md5Hash,
			   let catalogEntry = await loadFromCatalog(md5: md5) {
				extended.aperture = catalogEntry.aperture
				extended.shutterSpeed = catalogEntry.shutterSpeed
				extended.iso = catalogEntry.iso
				extended.focalLength = catalogEntry.focalLength
			}
		}
		
		return extended
	}
	
	// MARK: - Private Methods
	
	private func loadFromCatalog(md5: String) async -> CatalogPhotoEntry? {
		let container = try? ModelContainer(for: PhotoCatalog.self, CatalogShard.self, CatalogPhotoEntry.self)
		guard let container else { return nil }
		
		let context = ModelContext(container)
		
		// Query for the photo entry by MD5
		let descriptor = FetchDescriptor<CatalogPhotoEntry>(
			predicate: #Predicate<CatalogPhotoEntry> { entry in
				entry.md5 == md5
			}
		)
		
		do {
			let entries = try context.fetch(descriptor)
			return entries.first
		} catch {
			print("[UnifiedMetadataLoader] Failed to query catalog: \(error)")
			return nil
		}
	}
}

/// Extended metadata including EXIF data
struct ExtendedPhotoMetadata {
	let base: PhotoMetadata
	var aperture: Double?
	var shutterSpeed: String?
	var iso: Int?
	var focalLength: Double?
	
	// Formatted display values
	var apertureDisplay: String? {
		guard let aperture else { return nil }
		return "ƒ/\(String(format: "%.1f", aperture))"
	}
	
	var isoDisplay: String? {
		guard let iso else { return nil }
		return "ISO \(iso)"
	}
	
	var focalLengthDisplay: String? {
		guard let focalLength else { return nil }
		return "\(Int(focalLength))mm"
	}
	
	var exposureDisplay: String? {
		guard let shutterSpeed else { return nil }
		return shutterSpeed
	}
}
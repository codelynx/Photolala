//
//  CatalogAwarePhotoLoader.swift
//  Photolala
//
//  Intelligently loads photos using catalogs when available, with fallback to directory scanning
//

import Foundation
import OSLog
import CryptoKit

/// Service that loads photos from a directory, preferring catalog files when available
class CatalogAwarePhotoLoader {
	
	private let logger = Logger(subsystem: "com.electricwoods.photolala", category: "CatalogAwarePhotoLoader")
	private let catalogService: PhotolalaCatalogService
	private let scanner = DirectoryScanner()
	
	// Cache for network directories
	private var cachedCatalogs: [URL: CachedCatalog] = [:]
	private let cacheQueue = DispatchQueue(label: "com.electricwoods.photolala.catalogcache")
	private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
	
	private struct CachedCatalog {
		let photos: [PhotoReference]
		let cachedAt: Date
		let directoryUUID: String?
		
		var isValid: Bool {
			Date().timeIntervalSince(cachedAt) < 300 // 5 minutes
		}
	}
	
	init() {
		self.catalogService = PhotolalaCatalogService(catalogURL: URL(fileURLWithPath: "/"))
	}
	
	/// Load photos from a directory, using catalog if available
	func loadPhotos(from directory: URL) async throws -> [PhotoReference] {
		// Check cache first for network directories
		if isNetworkLocation(directory), let cached = getCachedPhotos(for: directory) {
			logger.debug("Using cached photos for \(directory.path)")
			return cached
		}
		
		// Check if catalog exists
		let catalogExists = FileManager.default.fileExists(
			atPath: directory.appendingPathComponent(".photolala/manifest.plist").path
		)
		
		if catalogExists {
			logger.debug("Loading from catalog at \(directory.path)")
			do {
				let photos = try await loadFromCatalog(directory)
				
				// Cache for network directories
				if isNetworkLocation(directory) {
					cachePhotos(photos, for: directory)
				}
				
				return photos
			} catch {
				logger.error("Failed to load catalog, falling back to scan: \(error)")
				// Fall through to scanning
			}
		}
		
		// Fall back to scanning
		logger.debug("Scanning directory at \(directory.path)")
		let photos = DirectoryScanner.scanDirectory(atPath: directory.path as NSString)
		
		// Generate catalog in background for future use
		if photos.count >= 100 { // Only for directories with many photos
			Task.detached(priority: .background) {
				try? await self.generateCatalog(for: directory, photos: photos)
			}
		}
		
		return photos
	}
	
	/// Force refresh catalog, bypassing cache
	func refreshCatalog(for directory: URL) async throws -> [PhotoReference] {
		// Clear cache
		clearCache(for: directory)
		
		// Reload
		return try await loadPhotos(from: directory)
	}
	
	// MARK: - Private Methods
	
	private func loadFromCatalog(_ directory: URL) async throws -> [PhotoReference] {
		// Create a new catalog service for this directory
		let catalogService = PhotolalaCatalogService(catalogURL: directory)
		
		// Load manifest to get directory UUID
		let manifest = try await catalogService.loadManifest()
		
		// Load all entries
		let entries = try await catalogService.loadAllEntries()
		
		// Convert to PhotoReference objects
		let photos = entries.map { entry in
			let photo = PhotoReference(
				directoryPath: directory.path as NSString,
				filename: entry.filename
			)
			// Set file creation date from catalog
			photo.fileCreationDate = entry.photodate
			// Set MD5 hash for S3 lookups
			photo.md5Hash = entry.md5
			// Note: We don't set metadata here since PhotoMetadata requires more fields
			// Let the normal metadata loading process handle it when needed
			return photo
		}
		
		// Store directory UUID for cache key if available
		if let uuid = manifest.directoryUUID {
			storeCatalogUUID(uuid, for: directory)
		}
		
		return photos
	}
	
	private func generateCatalog(for directory: URL, photos: [PhotoReference]) async throws {
		logger.info("Generating catalog for \(directory.path) with \(photos.count) photos")
		
		// Create catalog service for this directory
		let catalogService = PhotolalaCatalogService(catalogURL: directory)
		
		// Create empty catalog
		try await catalogService.createEmptyCatalog()
		
		// Convert photos to catalog entries
		for photo in photos {
			// Get file attributes for size and dates
			let fileURL = photo.fileURL
			let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
			let fileSize = attributes[.size] as? Int64 ?? 0
			let modificationDate = attributes[.modificationDate] as? Date ?? Date()
			
			// Calculate MD5 if not already present
			let md5: String
			if let existingMD5 = photo.md5Hash {
				md5 = existingMD5
			} else {
				// Calculate MD5 manually
				let data = try Data(contentsOf: fileURL)
				let digest = Insecure.MD5.hash(data: data)
				md5 = digest.map { String(format: "%02x", $0) }.joined()
				photo.md5Hash = md5
			}
			
			// Get dimensions from metadata if available
			let metadata = try? await photo.loadMetadata()
			
			let entry = PhotolalaCatalogService.CatalogEntry(
				md5: md5,
				filename: photo.filename,
				size: fileSize,
				photodate: photo.fileCreationDate ?? modificationDate,
				modified: modificationDate,
				width: metadata?.pixelWidth,
				height: metadata?.pixelHeight
			)
			
			try await catalogService.upsertEntry(entry)
		}
		
		// Save manifest
		try await catalogService.saveManifestIfNeeded()
		
		logger.info("Catalog generation complete for \(directory.path)")
	}
	
	// MARK: - Caching
	
	private func isNetworkLocation(_ url: URL) -> Bool {
		// Check if URL is on a network volume
		if url.path.hasPrefix("/Volumes/") && !url.path.hasPrefix("/Volumes/Macintosh HD") {
			return true
		}
		
		// Check for common network paths
		let networkPrefixes = ["/Volumes/", "smb://", "afp://", "nfs://"]
		return networkPrefixes.contains { url.absoluteString.hasPrefix($0) }
	}
	
	private func getCachedPhotos(for directory: URL) -> [PhotoReference]? {
		cacheQueue.sync {
			guard let cached = cachedCatalogs[directory],
			      cached.isValid else {
				return nil
			}
			return cached.photos
		}
	}
	
	private func cachePhotos(_ photos: [PhotoReference], for directory: URL) {
		cacheQueue.async {
			self.cachedCatalogs[directory] = CachedCatalog(
				photos: photos,
				cachedAt: Date(),
				directoryUUID: self.getCatalogUUID(for: directory)
			)
		}
	}
	
	private func clearCache(for directory: URL) {
		cacheQueue.async {
			self.cachedCatalogs.removeValue(forKey: directory)
		}
	}
	
	// MARK: - UUID Management
	
	private var catalogUUIDs: [URL: String] = [:]
	
	private func storeCatalogUUID(_ uuid: String, for directory: URL) {
		catalogUUIDs[directory] = uuid
	}
	
	private func getCatalogUUID(for directory: URL) -> String? {
		catalogUUIDs[directory]
	}
}
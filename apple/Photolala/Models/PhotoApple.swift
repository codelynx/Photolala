//
//  PhotoApple.swift
//  Photolala
//
//  Apple Photos Library photo representation
//

import Foundation
import Photos
import SwiftUI
import XPlatform

// File size cache for Apple Photos
private actor ApplePhotoFileSizeCache {
	static let shared = ApplePhotoFileSizeCache()
	
	private var cache: [String: Int64] = [:]
	private var loadingStates: [String: Bool] = [:]
	
	func getCachedSize(for id: String) -> Int64? {
		return cache[id]
	}
	
	func setCachedSize(_ size: Int64, for id: String) {
		cache[id] = size
	}
	
	func isLoading(id: String) -> Bool {
		return loadingStates[id] ?? false
	}
	
	func setLoading(_ loading: Bool, for id: String) {
		loadingStates[id] = loading
	}
}

/// Represents a photo from Apple Photos Library
struct PhotoApple: PhotoItem {
	let asset: PHAsset
	private let imageManager = PHCachingImageManager.default()
	
	// MARK: - PhotoItem Protocol
	
	var id: String { asset.localIdentifier }
	
	var filename: String {
		// Try to get original filename from resources
		var result = "IMG_\(asset.localIdentifier.prefix(8)).jpg"
		
		let resources = PHAssetResource.assetResources(for: asset)
		if let resource = resources.first {
			result = resource.originalFilename
		}
		
		return result
	}
	
	var displayName: String {
		(filename as NSString).deletingPathExtension
	}
	
	var fileSize: Int64? {
		// File size must be loaded asynchronously
		nil
	}
	
	var width: Int? {
		asset.pixelWidth > 0 ? asset.pixelWidth : nil
	}
	
	var height: Int? {
		asset.pixelHeight > 0 ? asset.pixelHeight : nil
	}
	
	var aspectRatio: Double? {
		guard let w = width, let h = height, h > 0 else { return nil }
		return Double(w) / Double(h)
	}
	
	var creationDate: Date? {
		asset.creationDate
	}
	
	var modificationDate: Date? {
		asset.modificationDate
	}
	
	var isArchived: Bool { false }
	
	var archiveStatus: ArchiveStatus { .standard }
	
	var md5Hash: String? {
		// This will be nil until computeMD5Hash() is called
		// We can't make async calls in a computed property
		nil
	}
	
	var source: PhotoSource { .applePhotos }
	
	// MARK: - Loading Methods
	
	func loadThumbnail() async throws -> XImage? {
		try await withCheckedThrowingContinuation { continuation in
			// Request uncropped image at reasonable size
			let targetSize = CGSize(width: 512, height: 512)
			let options = PHImageRequestOptions()
			options.isSynchronous = false
			options.deliveryMode = .highQualityFormat
			options.resizeMode = .fast
			options.isNetworkAccessAllowed = true // Allow iCloud download
			
			imageManager.requestImage(
				for: asset,
				targetSize: targetSize,
				contentMode: .aspectFit, // Get full uncropped image
				options: options
			) { image, info in
				if let error = info?[PHImageErrorKey] as? Error {
					continuation.resume(throwing: error)
				} else if let image = image {
					continuation.resume(returning: image)
				} else {
					continuation.resume(throwing: ApplePhotosError.thumbnailGenerationFailed)
				}
			}
		}
	}
	
	func loadImageData() async throws -> Data {
		try await withCheckedThrowingContinuation { continuation in
			let options = PHImageRequestOptions()
			options.isSynchronous = false
			options.deliveryMode = .highQualityFormat
			options.isNetworkAccessAllowed = true
			
			imageManager.requestImageDataAndOrientation(
				for: asset,
				options: options
			) { data, _, _, info in
				if let error = info?[PHImageErrorKey] as? Error {
					continuation.resume(throwing: error)
				} else if let data = data {
					continuation.resume(returning: data)
				} else {
					continuation.resume(throwing: ApplePhotosError.loadFailed)
				}
			}
		}
	}
	
	// MARK: - Metadata Loading
	
	func computeMD5Hash() async throws -> String {
		// Check if MD5 is already stored in catalog
		// Create catalog service on MainActor
		let catalogService = await MainActor.run { PhotolalaCatalogServiceV2.shared }
		
		// Query for the entry
		let entry = try? await catalogService.findByApplePhotoID(id)
		if let entry = entry {
			return entry.md5
		}
		
		// Load image data to compute hash
		let data = try await loadImageData()
		let hash = data.md5Digest.hexadecimalString
		
		// Note: MD5 will be stored in catalog when photo is backed up
		
		return hash
	}
	
	func loadFileSize() async throws -> Int64 {
		let cache = ApplePhotoFileSizeCache.shared
		
		// Check if already cached
		if let cachedSize = await cache.getCachedSize(for: id) {
			return cachedSize
		}
		
		// Prevent multiple simultaneous loads
		guard await !cache.isLoading(id: id) else {
			// Wait for existing load if in progress
			var attempts = 0
			while await cache.isLoading(id: id) && attempts < 30 {
				try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
				attempts += 1
			}
			if let size = await cache.getCachedSize(for: id) {
				return size
			}
			throw ApplePhotosError.loadFailed
		}
		
		await cache.setLoading(true, for: id)
		defer {
			Task {
				await cache.setLoading(false, for: id)
			}
		}
		
		return try await withCheckedThrowingContinuation { continuation in
			let options = PHImageRequestOptions()
			options.deliveryMode = .fastFormat // Use fast format for size check
			options.isNetworkAccessAllowed = true
			options.isSynchronous = false
			
			imageManager.requestImageDataAndOrientation(
				for: asset,
				options: options
			) { data, _, _, info in
				if let error = info?[PHImageErrorKey] as? Error {
					continuation.resume(throwing: error)
				} else if let data = data {
					let fileSize = Int64(data.count)
					Task {
						await cache.setCachedSize(fileSize, for: self.id)
					}
					continuation.resume(returning: fileSize)
				} else {
					continuation.resume(throwing: ApplePhotosError.loadFailed)
				}
			}
		}
	}
	
	// MARK: - Context Menu
	
	func contextMenuItems() -> [PhotoContextMenuItem] {
		var items: [PhotoContextMenuItem] = []
		
		#if os(macOS)
		// View in Photos
		items.append(PhotoContextMenuItem(
			title: "View in Photos",
			systemImage: "photo",
			action: { [self] in
				// Open Photos app with this asset selected
				if let url = URL(string: "photos://\(asset.localIdentifier)") {
					NSWorkspace.shared.open(url)
				}
			}
		))
		#endif
		
		// Export
		items.append(PhotoContextMenuItem(
			title: "Export...",
			systemImage: "square.and.arrow.up",
			action: {
				// Trigger export functionality
				// This would need to be handled by the view controller
			}
		))
		
		// Get Info
		items.append(PhotoContextMenuItem(
			title: "Get Info",
			systemImage: "info.circle",
			action: {
				// Show inspector
				// This would need to be handled by the view controller
			}
		))
		
		return items
	}
}

// MARK: - Errors

enum ApplePhotosError: LocalizedError {
	case thumbnailGenerationFailed
	case loadFailed
	
	var errorDescription: String? {
		switch self {
		case .thumbnailGenerationFailed:
			return "Failed to generate thumbnail from Photos Library"
		case .loadFailed:
			return "Failed to load photo from Photos Library"
		}
	}
}

// MARK: - Hashable

extension PhotoApple: Hashable {
	static func == (lhs: PhotoApple, rhs: PhotoApple) -> Bool {
		lhs.asset.localIdentifier == rhs.asset.localIdentifier
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(asset.localIdentifier)
	}
}
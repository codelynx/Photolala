//
//  ApplePhotosSource.swift
//  Photolala
//
//  Photo source implementation for Apple Photos library using PhotoKit
//

import Foundation
import Photos
import Combine
import CoreGraphics
import ImageIO
import SwiftUI

@MainActor
class ApplePhotosSource: PhotoSourceProtocol {
	// Photo library and image manager
	private let photoLibrary = PHPhotoLibrary.shared()
	private let imageManager = PHCachingImageManager()
	private let imageRequestOptions: PHImageRequestOptions

	// Cache for asset lookups
	private var assetCache: [String: PHAsset] = [:]

	// Published properties
	@Published private var photos: [PhotoBrowserItem] = []
	@Published private var isLoading: Bool = false

	// Publishers
	var photosPublisher: AnyPublisher<[PhotoBrowserItem], Never> {
		$photos.eraseToAnyPublisher()
	}

	var isLoadingPublisher: AnyPublisher<Bool, Never> {
		$isLoading.eraseToAnyPublisher()
	}

	// Capabilities
	let capabilities = PhotoSourceCapabilities(
		canDelete: false,  // We won't delete from Photos library
		canUpload: false,
		canCreateAlbums: false,
		canExport: true,
		canEditMetadata: false,
		supportsSearch: false
	)

	init() {
		// Configure image request options
		imageRequestOptions = PHImageRequestOptions()
		imageRequestOptions.deliveryMode = .highQualityFormat
		imageRequestOptions.isNetworkAccessAllowed = true
		imageRequestOptions.isSynchronous = false
	}

	func loadPhotos() async throws -> [PhotoBrowserItem] {
		isLoading = true
		defer { isLoading = false }

		// Request authorization
		let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
		guard status == .authorized || status == .limited else {
			throw PhotoSourceError.notAuthorized
		}

		// Fetch all image assets
		let fetchOptions = PHFetchOptions()
		fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
		fetchOptions.includeHiddenAssets = false

		// Only fetch images (not videos)
		fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

		let fetchResult = PHAsset.fetchAssets(with: fetchOptions)

		// Convert to PhotoBrowserItems
		var items: [PhotoBrowserItem] = []
		var cache: [String: PHAsset] = [:]

		fetchResult.enumerateObjects { asset, _, _ in
			let id = asset.localIdentifier
			let displayName = self.getDisplayName(for: asset)

			items.append(PhotoBrowserItem(id: id, displayName: displayName))
			cache[id] = asset
		}

		// Update cache and photos
		self.assetCache = cache
		self.photos = items

		return items
	}

	nonisolated func loadMetadata(for itemId: String) async throws -> PhotoBrowserMetadata {
		// Get asset from cache
		let asset = await MainActor.run {
			assetCache[itemId]
		}

		guard let asset = asset else {
			throw PhotoSourceError.itemNotFound
		}

		// Get file size if available (may need to request resources)
		var fileSize: Int64?
		if let resource = PHAssetResource.assetResources(for: asset).first {
			if let sizeValue = resource.value(forKey: "fileSize") as? NSNumber {
				fileSize = sizeValue.int64Value
			}
		}

		// Get image dimensions and other metadata
		return PhotoBrowserMetadata(
			fileSize: fileSize,
			creationDate: asset.creationDate,
			modificationDate: asset.modificationDate,
			width: asset.pixelWidth,
			height: asset.pixelHeight,
			mimeType: nil  // Could determine from resource.uniformTypeIdentifier
		)
	}

	nonisolated func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
		// Get asset from cache on MainActor
		let asset = await MainActor.run {
			assetCache[itemId]
		}

		guard let asset = asset else {
			throw PhotoSourceError.itemNotFound
		}

		// Request thumbnail from Photos
		let targetSize = CGSize(width: 256, height: 256)

		return try await withCheckedThrowingContinuation { continuation in
			// Request must be made on MainActor since imageManager.requestImage is @MainActor
			Task { @MainActor in
				let options = PHImageRequestOptions()
				options.deliveryMode = .opportunistic
				options.isNetworkAccessAllowed = true
				options.resizeMode = .fast

				imageManager.requestImage(
					for: asset,
					targetSize: targetSize,
					contentMode: .aspectFit,
					options: options
				) { image, info in
					// Check for error
					if let error = info?[PHImageErrorKey] as? Error {
						continuation.resume(throwing: PhotoSourceError.loadFailed(error))
						return
					}

					// Check if this is the final image (not degraded)
					let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
					if !isDegraded {
						#if os(macOS)
						if let nsImage = image {
							continuation.resume(returning: nsImage)
						} else {
							continuation.resume(throwing: PhotoSourceError.invalidData)
						}
						#else
						continuation.resume(returning: image)
						#endif
					}
					// If degraded, wait for better quality image
				}
			}
		}
	}

	nonisolated func loadFullImage(for itemId: String) async throws -> Data {
		// Get asset from cache on MainActor
		let asset = await MainActor.run {
			assetCache[itemId]
		}

		guard let asset = asset else {
			throw PhotoSourceError.itemNotFound
		}

		// Request full image data
		return try await withCheckedThrowingContinuation { continuation in
			// Request must be made on MainActor since imageManager methods are @MainActor
			Task { @MainActor in
				let options = PHImageRequestOptions()
				options.deliveryMode = .highQualityFormat
				options.isNetworkAccessAllowed = true
				options.isSynchronous = false

				imageManager.requestImageDataAndOrientation(
					for: asset,
					options: options
				) { data, _, _, info in
					// Check for error
					if let error = info?[PHImageErrorKey] as? Error {
						continuation.resume(throwing: PhotoSourceError.loadFailed(error))
						return
					}

					if let data = data {
						continuation.resume(returning: data)
					} else {
						continuation.resume(throwing: PhotoSourceError.invalidData)
					}
				}
			}
		}
	}

	nonisolated func getPhotoIdentity(for itemId: String) async -> (fullMD5: String?, headMD5: String?, fileSize: Int64?) {
		// For Apple Photos, we might have cached MD5 from previous export
		// TODO: Check cache for previously computed MD5
		// For now, we can't efficiently compute MD5 without exporting
		return (nil, nil, nil)
	}

	// MARK: - Helper Methods

	private func getDisplayName(for asset: PHAsset) -> String {
		// Try to get the original filename
		if let resource = PHAssetResource.assetResources(for: asset).first {
			return resource.originalFilename
		}

		// Fall back to date-based name
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm"

		if let date = asset.creationDate {
			return "Photo \(formatter.string(from: date))"
		}

		return "Photo"
	}

	func refresh() async throws {
		_ = try await loadPhotos()
	}
}

// MARK: - Photos Authorization Extension

extension PHAuthorizationStatus {
	var isAuthorized: Bool {
		self == .authorized || self == .limited
	}

	var errorDescription: String {
		switch self {
		case .notDetermined:
			return "Photo access not yet requested"
		case .restricted:
			return "Photo access is restricted"
		case .denied:
			return "Photo access was denied"
		case .limited:
			return "Limited photo access granted"
		case .authorized:
			return "Full photo access granted"
		@unknown default:
			return "Unknown authorization status"
		}
	}
}
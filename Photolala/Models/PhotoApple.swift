//
//  PhotoApple.swift
//  Photolala
//
//  Apple Photos Library photo representation
//

import Foundation
import Photos
import SwiftUI

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
		// File size requires fetching asset resources, which is expensive
		// Return nil for now and load on demand if needed
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
	
	var md5Hash: String? { nil } // Not available for Photos Library
	
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
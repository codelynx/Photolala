//
//  LocalPhotoSource.swift
//  Photolala
//
//  Photo source implementation for local directory browsing
//

import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers
import CoreGraphics
import ImageIO

@MainActor
class LocalPhotoSource: PhotoSourceProtocol {
	// Directory to browse
	private let directoryURL: URL

	// Catalog service for thumbnails
	private let catalogService: CatalogService

	// Map item IDs back to file paths (source's private knowledge)
	private var idToPath: [String: URL] = [:]

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
		canDelete: true,
		canUpload: false,
		canCreateAlbums: false,
		canExport: true,
		canEditMetadata: false,
		supportsSearch: false
	)

	init(directoryURL: URL, catalogService: CatalogService? = nil) {
		self.directoryURL = directoryURL
		self.catalogService = catalogService ?? CatalogService(catalogDirectory: directoryURL)
	}

	func loadPhotos() async throws -> [PhotoBrowserItem] {
		isLoading = true
		defer { isLoading = false }

		// Capture values before detaching to avoid actor isolation violations
		let directoryURL = self.directoryURL

		// Enumerate files off main actor for performance
		let (items, pathMap) = try await Task.detached {
			let fileManager = FileManager.default
			let resourceKeys: [URLResourceKey] = [
				.isRegularFileKey,
				.nameKey,
				.contentTypeKey
			]

			guard let enumerator = fileManager.enumerator(
				at: directoryURL,
				includingPropertiesForKeys: resourceKeys,
				options: [.skipsHiddenFiles, .skipsPackageDescendants]
			) else {
				throw PhotoSourceError.sourceUnavailable
			}

			var items: [PhotoBrowserItem] = []
			var pathMap: [String: URL] = [:]

			while let url = enumerator.nextObject() as? URL {
				// Check if it's a regular file
				guard let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys)),
					  let isRegularFile = resourceValues.isRegularFile,
					  isRegularFile else {
					continue
				}

				// Check if it's an image file
				if let contentType = resourceValues.contentType {
					let imageTypes = ["public.image", "public.jpeg", "public.png", "public.heif", "public.tiff"]
					let isImage = imageTypes.contains { contentType.conforms(to: UTType($0)!) }
					guard isImage else { continue }
				}

				// Generate ID from path
				let relativePath = url.path.replacingOccurrences(of: directoryURL.path, with: "")
				let id = relativePath.isEmpty ? url.lastPathComponent : relativePath
				let displayName = url.lastPathComponent

				items.append(PhotoBrowserItem(id: id, displayName: displayName))
				pathMap[id] = url
			}

			return (items, pathMap)
		}.value

		// Update state on main actor
		self.idToPath = pathMap
		self.photos = items
		return items
	}

	nonisolated func loadMetadata(for itemId: String) async throws -> PhotoBrowserMetadata {
		// Get URL from main actor
		let url = await MainActor.run {
			idToPath[itemId]
		}

		guard let url = url else {
			throw PhotoSourceError.itemNotFound
		}

		// Load attributes off main actor
		return try await Task.detached {
			let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

			// Get image dimensions using thread-safe CGImageSource
			var width: Int?
			var height: Int?
			var mimeType: String?

			// Create image source to read metadata without decoding the full image
			if let data = try? Data(contentsOf: url),
			   let imageSource = CGImageSourceCreateWithData(data as CFData, nil) {
				// Get image properties without decoding the bitmap
				if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
					// Extract dimensions
					width = properties[kCGImagePropertyPixelWidth] as? Int
					height = properties[kCGImagePropertyPixelHeight] as? Int

					// Extract MIME type if available
					if let uti = CGImageSourceGetType(imageSource) as String? {
						mimeType = UTType(uti)?.preferredMIMEType
					}
				}
			}

			return PhotoBrowserMetadata(
				fileSize: attributes[.size] as? Int64,
				creationDate: attributes[.creationDate] as? Date,
				modificationDate: attributes[.modificationDate] as? Date,
				width: width,
				height: height,
				mimeType: mimeType
			)
		}.value
	}

	nonisolated func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
		// Get URL from main actor
		let url = await MainActor.run {
			idToPath[itemId]
		}

		guard let url = url else {
			throw PhotoSourceError.itemNotFound
		}

		// Load image directly (catalog integration can be added later)
		// Load and scale thumbnail using thread-safe CoreGraphics
		let thumbnailSize = CGSize(width: 256, height: 256)

		return try await Task.detached {
			// Load image data
			let data = try Data(contentsOf: url)

			// Create image source
			guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
				  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
				throw PhotoSourceError.invalidData
			}

			// Calculate scaled size maintaining aspect ratio
			let originalWidth = CGFloat(cgImage.width)
			let originalHeight = CGFloat(cgImage.height)
			let widthRatio = thumbnailSize.width / originalWidth
			let heightRatio = thumbnailSize.height / originalHeight
			let scaleFactor = min(widthRatio, heightRatio)

			let scaledWidth = Int(originalWidth * scaleFactor)
			let scaledHeight = Int(originalHeight * scaleFactor)

			// Create context for scaling
			guard let context = CGContext(
				data: nil,
				width: scaledWidth,
				height: scaledHeight,
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			) else {
				throw PhotoSourceError.invalidData
			}

			// Draw scaled image
			context.interpolationQuality = .high
			context.draw(cgImage, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

			// Get scaled CGImage
			guard let scaledCGImage = context.makeImage() else {
				throw PhotoSourceError.invalidData
			}

			// Convert to platform image
			#if os(macOS)
			return NSImage(cgImage: scaledCGImage, size: CGSize(width: scaledWidth, height: scaledHeight))
			#else
			return UIImage(cgImage: scaledCGImage)
			#endif
		}.value
	}

	nonisolated func loadFullImage(for itemId: String) async throws -> Data {
		// Get URL from main actor
		let url = await MainActor.run {
			idToPath[itemId]
		}

		guard let url = url else {
			throw PhotoSourceError.itemNotFound
		}

		// Load data off main actor
		return try await Task.detached {
			try Data(contentsOf: url)
		}.value
	}

	// MARK: - Helper Methods

	func refresh() async throws {
		_ = try await loadPhotos()
	}

	func deleteItems(_ items: [PhotoBrowserItem]) async throws {
		// Implementation for deleting files
		for item in items {
			if let url = idToPath[item.id] {
				try FileManager.default.removeItem(at: url)
				idToPath.removeValue(forKey: item.id)
			}
		}

		// Reload photos
		_ = try await loadPhotos()
	}
}


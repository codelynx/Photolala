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

	// Public accessor for getting file URL for a photo item
	public func fileURL(for itemId: String) -> URL? {
		idToPath[itemId]
	}

	// Get the directory URL (for basket context)
	public var baseDirectoryURL: URL {
		directoryURL
	}

	// Security-scoped resource handling (iOS/macOS sandbox)
	private var securityScopedURL: URL?
	private var isAccessingSecurityScopedResource = false
	private var ownsSecurityScopedResource = false

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

	init(directoryURL: URL, catalogService: CatalogService? = nil, requiresSecurityScope: Bool = false, securityScopedURL: URL? = nil) {
		self.directoryURL = directoryURL
		self.catalogService = catalogService ?? CatalogService(catalogDirectory: directoryURL)
		self.securityScopedURL = securityScopedURL

		// Start accessing security-scoped resource if needed
		if requiresSecurityScope, let scopedURL = securityScopedURL {
			startSecurityScopedAccess(url: scopedURL)
		}
	}

	deinit {
		// Stop accessing security-scoped resource when done
		if ownsSecurityScopedResource, let scopedURL = securityScopedURL {
			scopedURL.stopAccessingSecurityScopedResource()
			print("[LocalPhotoSource] Stopped accessing security-scoped resource in deinit")
		}
	}

	private func startSecurityScopedAccess(url: URL) {
		guard !isAccessingSecurityScopedResource else { return }

		if url.startAccessingSecurityScopedResource() {
			isAccessingSecurityScopedResource = true
			ownsSecurityScopedResource = true
			print("[LocalPhotoSource] Started accessing security-scoped resource: \(url.path)")
		} else if FileManager.default.isReadableFile(atPath: directoryURL.path) {
			// Directory is already accessible without security scope
			print("[LocalPhotoSource] Directory already accessible: \(directoryURL.path)")
		} else {
			print("[LocalPhotoSource] Failed to access security-scoped resource: \(url.path)")
		}
	}

	func loadPhotos() async throws -> [PhotoBrowserItem] {
		isLoading = true
		defer {
			isLoading = false
		}

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

			// Create image source from URL to stream metadata without loading the full image
			if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
				// Get image properties without decoding the bitmap
				// Pass nil options to avoid loading pixel data
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

		// Load image directly using PTM-256 thumbnail spec
		// Short edge: 256px, long edge: up to 512px
		let shortEdge: CGFloat = 256
		let maxLongEdge: CGFloat = 512

		return try await Task.detached {
			// Load image data
			let data = try Data(contentsOf: url)

			// Create image source
			guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
				  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
				throw PhotoSourceError.invalidData
			}

			// Calculate dimensions following PTM-256 spec
			let width = CGFloat(cgImage.width)
			let height = CGFloat(cgImage.height)
			let scale = shortEdge / min(width, height)

			let scaledWidth = width * scale
			let scaledHeight = height * scale

			// Clamp long edge to 512px max
			let targetWidth = min(scaledWidth, maxLongEdge)
			let targetHeight = min(scaledHeight, maxLongEdge)

			// Create context for scaling
			guard let context = CGContext(
				data: nil,
				width: Int(targetWidth.rounded()),
				height: Int(targetHeight.rounded()),
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			) else {
				throw PhotoSourceError.invalidData
			}

			context.interpolationQuality = .high

			// Calculate drawing rect with cropping if needed
			var offsetX = (targetWidth - scaledWidth) / 2
			var offsetY = (targetHeight - scaledHeight) / 2

			// For portraits, bias crop upward by 40% to preserve faces
			if scaledHeight > targetHeight {
				let overflow = scaledHeight - targetHeight
				offsetY += overflow * 0.4
				offsetY = min(offsetY, 0)
			}

			let drawRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
			context.draw(cgImage, in: drawRect)

			// Get scaled CGImage
			guard let scaledCGImage = context.makeImage() else {
				throw PhotoSourceError.invalidData
			}

			// Convert to platform image
			#if os(macOS)
			return NSImage(cgImage: scaledCGImage, size: CGSize(width: targetWidth, height: targetHeight))
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

	nonisolated func getPhotoIdentity(for itemId: String) async -> (fullMD5: String?, headMD5: String?, fileSize: Int64?) {
		// Get URL from main actor
		let url = await MainActor.run {
			idToPath[itemId]
		}

		guard let url = url else {
			return (nil, nil, nil)
		}

		// Try to compute Fast Photo Key
		do {
			let fastKey = try await FastPhotoKey(contentsOf: url)
			// File size is already in the Fast Photo Key
			let fileSize = fastKey.fileSize

			print("[LocalPhotoSource] Photo identity for \(url.lastPathComponent):")
			print("  - Head MD5: \(fastKey.headMD5)")
			print("  - File size: \(fileSize)")

			// TODO: Check if we have cached full MD5 for this file
			// For now, return Fast Photo Key components
			return (nil, fastKey.headMD5, fileSize)
		} catch {
			// If we can't compute, try to get file size from attributes
			do {
				let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
				if let fileSize = attributes[.size] as? Int64 {
					return (nil, nil, fileSize)
				}
			} catch {
				// Ignore
			}
			return (nil, nil, nil)
		}
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


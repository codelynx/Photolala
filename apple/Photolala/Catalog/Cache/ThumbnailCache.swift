//
//  ThumbnailCache.swift
//  Photolala
//
//  Thumbnail generation and caching system
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import OSLog

/// Thumbnail cache for efficient image preview management
public actor ThumbnailCache {
	static let shared = ThumbnailCache()

	private let logger = Logger(subsystem: "com.photolala", category: "ThumbnailCache")
	private let cacheManager = CacheManager.shared

	// PTM-256 Thumbnail configuration
	// Short edge is 256px, long edge up to 512px
	private let shortEdge: CGFloat = 256
	private let maxLongEdge: CGFloat = 512
	private let jpegQuality: CGFloat = 0.85

	// Rate limiting
	private let maxConcurrentGenerations = 4
	private var activeGenerations = 0

	// Memory cache (use String keys for Sendable conformance)
	private var memoryCache: [String: CGImage] = [:]
	private let maxMemoryCacheCount = 100

	private init() {}

	// MARK: - Public API

	/// Get thumbnail for photo, generating if needed
	public func getThumbnail(for photoMD5: PhotoMD5, sourceURL: URL, cacheType: CacheType = .md5) async throws -> URL {
		// Check disk cache
		let cachePath = await cacheManager.getThumbnailPath(photoMD5: photoMD5, cacheType: cacheType)
		if FileManager.default.fileExists(atPath: cachePath.path) {
			logger.debug("Thumbnail found in disk cache: \(photoMD5.value)")
			return cachePath
		}

		// Generate new thumbnail
		logger.info("Generating thumbnail for: \(photoMD5.value)")
		let image = try await generateThumbnail(from: sourceURL)

		// Save to disk cache
		try await saveThumbnail(image, to: cachePath)

		// Update memory cache
		updateMemoryCache(photoMD5: photoMD5, image: image)

		return cachePath
	}

	/// Get thumbnail as CGImage for display
	public func getThumbnailImage(for photoMD5: PhotoMD5, sourceURL: URL, cacheType: CacheType = .md5) async throws -> CGImage {
		// Check memory cache
		if let cached = memoryCache[photoMD5.value] {
			logger.debug("Thumbnail found in memory cache: \(photoMD5.value)")
			return cached
		}

		// Get thumbnail URL
		let thumbnailURL = try await getThumbnail(for: photoMD5, sourceURL: sourceURL, cacheType: cacheType)

		// Load and cache image
		let image = try await loadThumbnail(from: thumbnailURL)
		updateMemoryCache(photoMD5: photoMD5, image: image)

		return image
	}

	/// Get thumbnail as JPEG Data for S3 upload
	/// This generates a PTM-256 compliant JPEG thumbnail
	public func getThumbnailData(for photoMD5: PhotoMD5, sourceURL: URL) async throws -> Data {
		// Generate thumbnail image
		let image = try await generateThumbnail(from: sourceURL)

		// Convert to JPEG data with PTM-256 spec
		return try await Task.detached(priority: .utility) {
			var quality = self.jpegQuality
			var attempts = 0
			let maxAttempts = 3
			let minQuality: CGFloat = 0.70

			while attempts < maxAttempts {
				let data = NSMutableData()
				guard let destination = CGImageDestinationCreateWithData(
					data as CFMutableData,
					UTType.jpeg.identifier as CFString,
					1,
					nil
				) else {
					throw ThumbnailError.saveFailed
				}

				let properties: [CFString: Any] = [
					kCGImageDestinationLossyCompressionQuality: quality,
					kCGImageDestinationOptimizeColorForSharing: true
				]

				CGImageDestinationAddImage(destination, image, properties as CFDictionary)

				guard CGImageDestinationFinalize(destination) else {
					throw ThumbnailError.saveFailed
				}

				// Check if size is within PTM-256 limits
				if data.length <= 50_000 {
					self.logger.debug("Generated PTM-256 thumbnail: \(photoMD5.value) (\(data.length) bytes)")
					return data as Data
				}

				// Try lower quality if too large
				attempts += 1
				quality = max(quality - 0.05, minQuality)

				if quality <= minQuality && data.length > 50_000 {
					self.logger.warning("PTM-256 thumbnail exceeds 50KB: \(photoMD5.value) (\(data.length) bytes)")
					return data as Data
				}
			}

			throw ThumbnailError.sizeLimitExceeded
		}.value
	}

	/// Prefetch thumbnails for multiple photos
	public func prefetchThumbnails(for photos: [(PhotoMD5, URL)], cacheType: CacheType = .md5) async {
		await withTaskGroup(of: Void.self) { group in
			for (photoMD5, sourceURL) in photos.prefix(10) { // Limit prefetch count
				group.addTask { [weak self] in
					_ = try? await self?.getThumbnail(for: photoMD5, sourceURL: sourceURL, cacheType: cacheType)
				}
			}
		}
	}

	/// Check if thumbnail exists in cache
	public func hasThumbnail(for photoMD5: PhotoMD5, cacheType: CacheType = .md5) async -> Bool {
		// Check memory cache
		if memoryCache[photoMD5.value] != nil {
			return true
		}

		// Check disk cache
		let cachePath = await cacheManager.getThumbnailPath(photoMD5: photoMD5, cacheType: cacheType)
		return FileManager.default.fileExists(atPath: cachePath.path)
	}

	/// Clear memory cache
	public func clearMemoryCache() {
		memoryCache.removeAll()
		logger.info("Memory cache cleared")
	}

	/// Clear all cached thumbnails (memory and disk)
	public func clearAll() async {
		// Clear memory cache
		clearMemoryCache()

		// Clear disk cache through CacheManager
		do {
			// Clear both MD5 and Apple Photos caches
			try await cacheManager.clearAllCaches()
			logger.info("Cleared all thumbnail caches")
		} catch {
			logger.error("Failed to clear disk cache: \(error)")
		}
	}

	// MARK: - Private Methods

	/// Generate PTM-256 thumbnail from source image
	/// Follows PTM-256 spec: short edge 256px, long edge up to 512px
	private func generateThumbnail(from sourceURL: URL) async throws -> CGImage {
		// Rate limiting
		while activeGenerations >= maxConcurrentGenerations {
			try await Task.sleep(nanoseconds: 100_000_000) // 100ms
		}

		activeGenerations += 1
		defer { activeGenerations -= 1 }

		return try await Task.detached(priority: .utility) {
			// Load the source image
			guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
				  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
				throw ThumbnailError.invalidImageSource
			}

			// Calculate dimensions following PTM-256 spec
			let width = CGFloat(cgImage.width)
			let height = CGFloat(cgImage.height)
			let scale = self.shortEdge / min(width, height)

			let scaledWidth = width * scale
			let scaledHeight = height * scale

			// Clamp long edge to 512px max
			let targetWidth = min(scaledWidth, self.maxLongEdge)
			let targetHeight = min(scaledHeight, self.maxLongEdge)

			// Create context for thumbnail
			guard let context = CGContext(
				data: nil,
				width: Int(targetWidth.rounded()),
				height: Int(targetHeight.rounded()),
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			) else {
				throw ThumbnailError.generationFailed
			}

			context.interpolationQuality = .high

			// Calculate drawing rect with cropping if needed
			var offsetX = (targetWidth - scaledWidth) / 2
			var offsetY = (targetHeight - scaledHeight) / 2

			// For portraits, bias crop upward by 40% to preserve faces
			if scaledHeight > targetHeight {
				let overflow = scaledHeight - targetHeight
				offsetY += overflow * 0.4
				offsetY = min(offsetY, 0) // Don't push outside top edge
			}

			let drawRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
			context.draw(cgImage, in: drawRect)

			guard let thumbnail = context.makeImage() else {
				throw ThumbnailError.generationFailed
			}

			return thumbnail
		}.value
	}

	/// Load thumbnail from disk
	private func loadThumbnail(from url: URL) async throws -> CGImage {
		return try await Task.detached(priority: .utility) {
			guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
				  let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
				throw ThumbnailError.loadFailed
			}
			return image
		}.value
	}

	/// Save thumbnail to disk following PTM-256 spec
	private func saveThumbnail(_ image: CGImage, to url: URL) async throws {
		let data = try await Task.detached(priority: .utility) {
			var quality = self.jpegQuality
			var attempts = 0
			let maxAttempts = 3
			let minQuality: CGFloat = 0.70

			while attempts < maxAttempts {
				let data = NSMutableData()
				guard let destination = CGImageDestinationCreateWithData(
					data as CFMutableData,
					UTType.jpeg.identifier as CFString,
					1,
					nil
				) else {
					throw ThumbnailError.saveFailed
				}

				// PTM-256 spec: optimize for sharing, use current quality
				let properties: [CFString: Any] = [
					kCGImageDestinationLossyCompressionQuality: quality,
					kCGImageDestinationOptimizeColorForSharing: true
				]

				CGImageDestinationAddImage(destination, image, properties as CFDictionary)

				guard CGImageDestinationFinalize(destination) else {
					throw ThumbnailError.saveFailed
				}

				// Check if size is within PTM-256 limits (max 50KB)
				if data.length <= 50_000 {
					return data as Data
				}

				// Try lower quality if too large
				attempts += 1
				quality = max(quality - 0.05, minQuality)

				if quality <= minQuality && data.length > 50_000 {
					// Accept file even if slightly over limit at minimum quality
					self.logger.warning("PTM-256 thumbnail exceeds 50KB at minimum quality: \(data.length) bytes")
					return data as Data
				}
			}

			throw ThumbnailError.sizeLimitExceeded
		}.value

		try await cacheManager.storeData(data, at: url)
		logger.debug("Saved PTM-256 thumbnail to: \(url.lastPathComponent) (\(data.count) bytes)")
	}

	/// Update memory cache with LRU eviction
	private func updateMemoryCache(photoMD5: PhotoMD5, image: CGImage) {
		memoryCache[photoMD5.value] = image

		// Evict oldest if over limit
		if memoryCache.count > maxMemoryCacheCount {
			// Simple eviction - remove random item
			// TODO: Implement proper LRU
			if let firstKey = memoryCache.keys.first {
				memoryCache.removeValue(forKey: firstKey)
			}
		}
	}
}

// MARK: - Error Types

enum ThumbnailError: LocalizedError {
	case invalidImageSource
	case generationFailed
	case loadFailed
	case saveFailed
	case sizeLimitExceeded

	var errorDescription: String? {
		switch self {
		case .invalidImageSource:
			return "Cannot create image source from URL"
		case .generationFailed:
			return "Failed to generate thumbnail"
		case .loadFailed:
			return "Failed to load thumbnail from cache"
		case .saveFailed:
			return "Failed to save thumbnail to cache"
		case .sizeLimitExceeded:
			return "Thumbnail exceeds 50KB limit even at minimum quality"
		}
	}
}
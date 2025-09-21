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

	// Thumbnail configuration
	private let thumbnailSize = CGSize(width: 256, height: 256)
	private let jpegQuality: CGFloat = 0.8

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

	// MARK: - Private Methods

	/// Generate thumbnail from source image
	private func generateThumbnail(from sourceURL: URL) async throws -> CGImage {
		// Rate limiting
		while activeGenerations >= maxConcurrentGenerations {
			try await Task.sleep(nanoseconds: 100_000_000) // 100ms
		}

		activeGenerations += 1
		defer { activeGenerations -= 1 }

		return try await Task.detached(priority: .utility) {
			guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
				throw ThumbnailError.invalidImageSource
			}

			let options: [CFString: Any] = [
				kCGImageSourceCreateThumbnailFromImageAlways: true,
				kCGImageSourceCreateThumbnailWithTransform: true,
				kCGImageSourceThumbnailMaxPixelSize: max(self.thumbnailSize.width, self.thumbnailSize.height)
			]

			guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
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

	/// Save thumbnail to disk
	private func saveThumbnail(_ image: CGImage, to url: URL) async throws {
		let data = try await Task.detached(priority: .utility) {
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
				kCGImageDestinationLossyCompressionQuality: self.jpegQuality
			]

			CGImageDestinationAddImage(destination, image, properties as CFDictionary)

			guard CGImageDestinationFinalize(destination) else {
				throw ThumbnailError.saveFailed
			}

			return data as Data
		}.value

		try await cacheManager.storeData(data, at: url)
		logger.debug("Saved thumbnail to: \(url.lastPathComponent)")
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
		}
	}
}
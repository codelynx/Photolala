//
//  PhotoManager.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//
import CryptoKit
import Foundation
import SwiftUI

class PhotoManager {

	typealias XThumbnail = XImage

	// MARK: - Cache Statistics

	private struct CacheStatistics {
		var imageHits = 0
		var imageMisses = 0
		var thumbnailHits = 0
		var thumbnailMisses = 0
		var diskReads = 0
		var diskWrites = 0
		var totalLoadTime: TimeInterval = 0
		var loadCount = 0

		var averageLoadTime: TimeInterval {
			self.loadCount > 0 ? self.totalLoadTime / Double(self.loadCount) : 0
		}

		var imageHitRate: Double {
			let total = self.imageHits + self.imageMisses
			return total > 0 ? Double(self.imageHits) / Double(total) : 0
		}

		var thumbnailHitRate: Double {
			let total = self.thumbnailHits + self.thumbnailMisses
			return total > 0 ? Double(self.thumbnailHits) / Double(total) : 0
		}
	}

	private var stats = CacheStatistics()

	enum Identifier {
		case md5(Insecure.MD5Digest) // universal photo identifier
		case applePhotoLibrary(String) // unique device wide
		var string: String {
			switch self {
			case let .md5(digest): "md5#\(digest.data.hexadecimalString)"
			case let .applePhotoLibrary(identifier): "apl#\(identifier)"
			}
		}

		init?(string: String) {
			let components = string.split(separator: "#").map { String($0) }
			guard components.count == 2 else { return nil }
			switch components[0].lowercased() {
			case "md5":
				guard let data = Data(hexadecimalString: String(components[1])),
				      let md5 = Insecure.MD5Digest(rawBytes: data)
				else { return nil }
				self = .md5(md5)
			case "apl":
				self = .applePhotoLibrary(String(components[1]))
			default:
				return nil
			}
		}
	}

	static let shared = PhotoManager()

	func thumbnailURL(for identifier: Identifier) -> URL {
		let fileName = identifier.string + ".jpg"
		let filePath = (self.thumbnailStoragePath as NSString).appendingPathComponent(fileName)
		return URL(fileURLWithPath: filePath)
	}

	private func error(message: String) -> Error {
		NSError(domain: "PhotoManager", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
	}

	func md5Digest(of data: Data) -> Insecure.MD5Digest {
		Insecure.MD5.hash(data: data)
	}

	private let imageCache = NSCache<NSString, XImage>() // filePath: XImage
	private let thumbnailCache = NSCache<NSString, XThumbnail>() // PhotoManager.Identifier: XThumbnail
	private let metadataCache = NSCache<NSString, PhotoMetadata>() // filePath: PhotoMetadata
	private let queue = DispatchQueue(label: "com.photolala.PhotoManager", qos: .userInitiated, attributes: .concurrent)

	func loadImage(for photo: PhotoReference) async throws -> XImage? {
		try await withCheckedThrowingContinuation { continuation in
			self.queue.async {
				do {
					let result = try self.syncLoadImage(for: photo)
					continuation.resume(returning: result)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	func loadFullImage(for photo: PhotoReference) async throws -> XImage? {
		try await withCheckedThrowingContinuation { continuation in
			self.queue.async {
				do {
					let startTime = Date()
					print("[PhotoManager] loadFullImage for: \(photo.filename), path: \(photo.filePath)")

					// Check if we have it in cache
					if let cachedImage = self.imageCache.object(forKey: photo.filePath as NSString) {
						self.stats.imageHits += 1
						let loadTime = Date().timeIntervalSince(startTime)
						print(
							"[PhotoManager] ✅ CACHE HIT - Image: \(photo.filename) (Load time: \(String(format: "%.3f", loadTime))s)"
						)
						continuation.resume(returning: cachedImage)
						return
					}

					// Cache miss
					self.stats.imageMisses += 1

					// Load from disk
					let url = photo.fileURL
					print("[PhotoManager] ❌ CACHE MISS - Loading from disk: \(url.path)")
					let diskStartTime = Date()
					let data = try Data(contentsOf: url)
					let diskReadTime = Date().timeIntervalSince(diskStartTime)
					self.stats.diskReads += 1
					print(
						"[PhotoManager] 💾 DISK READ - \(data.count / 1_024 / 1_024)MB in \(String(format: "%.3f", diskReadTime))s"
					)

					guard let image = XImage(data: data) else {
						print("[PhotoManager] Failed to create image from data")
						throw NSError(
							domain: "PhotoManager",
							code: 2,
							userInfo: [NSLocalizedDescriptionKey: "Unable to create image from data"]
						)
					}

					let totalTime = Date().timeIntervalSince(startTime)
					self.stats.totalLoadTime += totalTime
					self.stats.loadCount += 1

					print(
						"[PhotoManager] Successfully created image, size: \(image.size), total time: \(String(format: "%.3f", totalTime))s"
					)

					// Cache it
					self.imageCache.setObject(image, forKey: photo.filePath as NSString)

					continuation.resume(returning: image)
				} catch {
					print("[PhotoManager] Error loading image: \(error)")
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func syncLoadImage(for photo: PhotoReference) throws -> XImage? {
		if let image = imageCache.object(forKey: photo.id as NSString) {
			return image
		}
		let imageData = try Data(contentsOf: URL(fileURLWithPath: photo.filePath))
		if let image = XImage(data: imageData) {
			let identifier = PhotoManager.Identifier.md5(self.md5Digest(of: imageData))
			if self.hasThumbnail(for: identifier) == false {
				try self.prepareThumbnail(from: imageData)
			}
			return image
		} else { return nil }
	}

	@discardableResult
	func prepareThumbnail(from data: Data) throws -> XThumbnail? {
		guard let image = XImage(data: data) else {
			throw self.error(message: "Unable to create image from data")
		}
		let md5 = self.md5Digest(of: data)
		let identifier = PhotoManager.Identifier.md5(md5)

		// Scale so that the shorter side becomes 256 pixels
		let originalSize = image.size
		let minSide = min(originalSize.width, originalSize.height)
		let scale = 256.0 / minSide
		let scaledSize = CGSize(
			width: originalSize.width * scale,
			height: originalSize.height * scale
		)

		#if os(macOS)
			// On macOS, NSImage already handles EXIF orientation automatically
			// when we create it from data, so we just need to get a bitmap rep
			guard let tiffData = image.tiffRepresentation,
			      let imageRep = NSBitmapImageRep(data: tiffData)
			else {
				throw self.error(message: "Unable to get image representation")
			}

			// Calculate crop dimensions
			let cropWidth = min(scaledSize.width, 512)
			let cropHeight = min(scaledSize.height, 512)
			let cropX = (scaledSize.width - cropWidth) / 2
			let cropY = (scaledSize.height - cropHeight) / 2

			// Create a new bitmap rep with the target size
			guard let newRep = NSBitmapImageRep(
				bitmapDataPlanes: nil,
				pixelsWide: Int(cropWidth),
				pixelsHigh: Int(cropHeight),
				bitsPerSample: 8,
				samplesPerPixel: 4,
				hasAlpha: true,
				isPlanar: false,
				colorSpaceName: .deviceRGB,
				bytesPerRow: 0,
				bitsPerPixel: 0
			) else {
				throw self.error(message: "Unable to create bitmap representation")
			}

			// Draw the scaled and cropped image
			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newRep)

			let sourceRect = NSRect(x: 0, y: 0, width: originalSize.width, height: originalSize.height)
			let destRect = NSRect(x: -cropX, y: -cropY, width: scaledSize.width, height: scaledSize.height)
			image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)

			NSGraphicsContext.restoreGraphicsState()

			// Get JPEG data
			guard let jpegData = newRep.representation(using: .jpeg, properties: [:]) else {
				throw self.error(message: "Unable to create JPEG data")
			}

			// Save to file
			let thumbnailFilePath = self.thumbnailURL(for: identifier).path
			try jpegData.write(to: URL(fileURLWithPath: thumbnailFilePath))

			// Create and cache the thumbnail
			let thumbnail = NSImage(size: NSSize(width: cropWidth, height: cropHeight))
			thumbnail.addRepresentation(newRep)
			self.thumbnailCache.setObject(thumbnail, forKey: identifier.string as NSString)
			return thumbnail
		#else
			// Resize on iOS - handle orientation properly
			// First, normalize the image orientation by drawing it
			UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
			image.draw(at: .zero)
			guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
				UIGraphicsEndImageContext()
				throw self.error(message: "Unable to normalize image orientation")
			}
			UIGraphicsEndImageContext()

			guard let cgImage = normalizedImage.cgImage else {
				throw self.error(message: "Unable to get CGImage")
			}

			// Now scale and crop with the normalized image
			let cropWidth = min(scaledSize.width, 512)
			let cropHeight = min(scaledSize.height, 512)

			// Create a context with the final size
			let colorSpace = CGColorSpaceCreateDeviceRGB()
			guard let context = CGContext(
				data: nil,
				width: Int(cropWidth),
				height: Int(cropHeight),
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: colorSpace,
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			) else {
				throw self.error(message: "Unable to create bitmap context")
			}

			// Calculate the drawing rect to center the cropped area
			let drawRect = CGRect(
				x: -(scaledSize.width - cropWidth) / 2,
				y: -(scaledSize.height - cropHeight) / 2,
				width: scaledSize.width,
				height: scaledSize.height
			)

			// Draw the scaled image
			context.interpolationQuality = .high
			context.draw(cgImage, in: drawRect)

			// Get the final image
			guard let finalCGImage = context.makeImage() else {
				throw self.error(message: "Unable to create final image")
			}

			let finalImage = UIImage(cgImage: finalCGImage)
			guard let jpegData = finalImage.jpegData(compressionQuality: 0.8) else {
				throw self.error(message: "Unable to create JPEG data")
			}
			let thumbnailFilePath = self.thumbnailURL(for: identifier).path
			try jpegData.write(to: URL(fileURLWithPath: thumbnailFilePath))
			// Cache the generated thumbnail
			self.thumbnailCache.setObject(finalImage, forKey: identifier.string as NSString)
			return finalImage
		#endif
	}

	func thumbnail(for identifier: Identifier) throws -> XThumbnail? {
		if let thumbnail = self.thumbnailCache.object(forKey: identifier.string as NSString) {
			return thumbnail
		}
		if self.hasThumbnail(for: identifier) {
			let data = try Data(contentsOf: self.thumbnailURL(for: identifier))
			if let thumbnail = XImage(data: data) {
				self.thumbnailCache.setObject(thumbnail, forKey: identifier.string as NSString)
				return thumbnail as XThumbnail
			}
		}
		// can't find filepath from identifier
		return nil
	}

	func thumbnail(for photoRep: PhotoReference) async throws -> XThumbnail? {
		try await withCheckedThrowingContinuation { continuation in
			self.queue.async {
				do {
					let result = try self.syncThumbnail(for: photoRep)
					continuation.resume(returning: result)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func syncThumbnail(for photoRep: PhotoReference) throws -> XThumbnail? {
		let startTime = Date()

		// First check memory cache with file path (faster)
		let cacheKey = photoRep.filePath as NSString
		if let cached = thumbnailCache.object(forKey: cacheKey) {
			self.stats.thumbnailHits += 1
			let loadTime = Date().timeIntervalSince(startTime)
			print(
				"[PhotoManager] ✅ THUMBNAIL CACHE HIT - \(photoRep.filename) (Load time: \(String(format: "%.3f", loadTime))s)"
			)
			return cached
		}

		// Cache miss
		self.stats.thumbnailMisses += 1
		print("[PhotoManager] ❌ THUMBNAIL CACHE MISS - \(photoRep.filename)")

		// Load image data for MD5
		let md5StartTime = Date()
		let imageData = try Data(contentsOf: photoRep.fileURL)
		let md5Time = Date().timeIntervalSince(md5StartTime)
		print(
			"[PhotoManager] 📊 MD5 computation - Read \(imageData.count / 1_024)KB in \(String(format: "%.3f", md5Time))s"
		)

		let identifier = Identifier.md5(self.md5Digest(of: imageData))

		// Check disk cache
		if self.hasThumbnail(for: identifier) {
			let diskStartTime = Date()
			let data = try Data(contentsOf: thumbnailURL(for: identifier))
			let diskTime = Date().timeIntervalSince(diskStartTime)
			self.stats.diskReads += 1
			print(
				"[PhotoManager] 💾 THUMBNAIL DISK READ - \(data.count / 1_024)KB in \(String(format: "%.3f", diskTime))s"
			)

			if let thumbnail = XImage(data: data) {
				// Cache in memory with file path as key
				self.thumbnailCache.setObject(thumbnail, forKey: cacheKey)
				return thumbnail
			}
		}

		// Generate new thumbnail
		print("[PhotoManager] 🔨 GENERATING NEW THUMBNAIL - \(photoRep.filename)")
		let generateStartTime = Date()
		let thumbnail = try prepareThumbnail(from: imageData)
		let generateTime = Date().timeIntervalSince(generateStartTime)
		self.stats.diskWrites += 1

		// IMPORTANT: Cache the thumbnail with file path as key for fast lookup
		if let thumbnail {
			self.thumbnailCache.setObject(thumbnail, forKey: cacheKey)
		}

		let totalTime = Date().timeIntervalSince(startTime)
		print(
			"[PhotoManager] ⏱️ THUMBNAIL TOTAL TIME - \(photoRep.filename): \(String(format: "%.3f", totalTime))s (generate: \(String(format: "%.3f", generateTime))s)"
		)

		return thumbnail
	}

	func hasThumbnail(for identifier: Identifier) -> Bool {
		FileManager.default.fileExists(atPath: self.thumbnailURL(for: identifier).path)
	}

	private let photolalaStoragePath: NSString
	private let thumbnailStoragePath: NSString // Keep for backward compatibility
	private let cacheDirectoryPath: NSString

	private init() {
		let photolalaStoragePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
			.appendingPathComponent("Photolala").path
		do { try FileManager.default.createDirectory(atPath: photolalaStoragePath, withIntermediateDirectories: true) }
		catch { fatalError("\(error): cannot create photolala storage directory: \(photolalaStoragePath)") }
		self.photolalaStoragePath = photolalaStoragePath as NSString
		print("photolala directory: \(photolalaStoragePath)")

		// Migration: Check if 'thumbnails' directory exists and rename to 'cache'
		let oldThumbnailPath = (photolalaStoragePath as NSString).appendingPathComponent("thumbnails")
		let newCachePath = (photolalaStoragePath as NSString).appendingPathComponent("cache")

		if FileManager.default.fileExists(atPath: oldThumbnailPath),
		   !FileManager.default.fileExists(atPath: newCachePath)
		{
			do {
				try FileManager.default.moveItem(atPath: oldThumbnailPath, toPath: newCachePath)
				print("[PhotoManager] Migrated thumbnails directory to cache directory")
			} catch {
				print("[PhotoManager] Failed to migrate thumbnails directory: \(error)")
			}
		}

		// Create cache directory if needed
		do { try FileManager.default.createDirectory(atPath: newCachePath, withIntermediateDirectories: true) }
		catch { fatalError("\(error): cannot create cache directory: \(newCachePath)") }

		self.cacheDirectoryPath = newCachePath as NSString
		self.thumbnailStoragePath = newCachePath as NSString // Point to same location for backward compatibility

		// Configure cache limits based on available memory
		let totalMemory = ProcessInfo.processInfo.physicalMemory
		let memoryBudget = totalMemory / 4 // Use up to 25% of physical memory

		// Image cache: Limited for preview navigation (±2-3 images from current)
		// Scale from 16 (base) to 64 (high-end machines) based on available memory
		let baseImageCount = 16
		let scaleFactor = min(totalMemory / (8 * 1_024 * 1_024 * 1_024), 4) // Scale up to 4x for 32GB+ machines
		self.imageCache.countLimit = Int(Double(baseImageCount) * Double(scaleFactor))
		self.imageCache.totalCostLimit = Int(memoryBudget)

		// Thumbnail cache: assume 100KB per thumbnail
		let averageThumbnailSize: UInt64 = 100 * 1_024
		self.thumbnailCache.countLimit = 1_000
		self.thumbnailCache.totalCostLimit = 100 * 1_024 * 1_024 // 100MB max

		print(
			"[PhotoManager] Cache configured - Images: \(self.imageCache.countLimit) items, \(memoryBudget / 1_024 / 1_024)MB"
		)
		print("[PhotoManager] Cache configured - Thumbnails: \(self.thumbnailCache.countLimit) items, 100MB")
	}

	// MARK: - Prefetching

	func prefetchThumbnails(for photos: [PhotoReference]) async {
		// Process in parallel but limit concurrency
		await withTaskGroup(of: Void.self) { group in
			for photo in photos {
				group.addTask { [weak self] in
					do {
						_ = try await self?.thumbnail(for: photo)
					} catch {
						// Silently ignore prefetch errors
						print("[PhotoManager] Prefetch thumbnail failed for \(photo.filename): \(error)")
					}
				}
			}
		}
	}

	func prefetchImages(for photos: [PhotoReference], priority: TaskPriority = .medium) async {
		// Limit concurrent full image loads to prevent memory spikes
		let maxConcurrent = 2

		await withTaskGroup(of: Void.self) { group in
			for (index, photo) in photos.enumerated() {
				// Limit concurrent operations
				if index >= maxConcurrent {
					await group.next()
				}

				group.addTask(priority: priority) { [weak self] in
					do {
						_ = try await self?.loadFullImage(for: photo)
					} catch {
						// Silently ignore prefetch errors
						print("[PhotoManager] Prefetch image failed for \(photo.filename): \(error)")
					}
				}
			}
		}
	}

	func prefetchThumbnails(for photos: [PhotoReference], priority: TaskPriority = .low) async {
		// Limit concurrent thumbnail loads
		let maxConcurrent = 4

		await withTaskGroup(of: Void.self) { group in
			for (index, photo) in photos.enumerated() {
				// Skip if already has thumbnail
				if photo.thumbnail != nil {
					continue
				}

				// Limit concurrent operations
				if index >= maxConcurrent {
					await group.next()
				}

				group.addTask(priority: priority) { [weak self] in
					do {
						_ = try await self?.thumbnail(for: photo)
					} catch {
						// Silently ignore prefetch errors
						print("[PhotoManager] Prefetch thumbnail failed for \(photo.filename): \(error)")
					}
				}
			}
		}
	}

	// Cancel all pending operations for cleanup
	func cancelAllPrefetches() {
		// This would require tracking tasks, implement later if needed
	}

	// MARK: - Cache Statistics

	func printCacheStatistics() {
		print("\n📊 ========== PHOTOMANAGER CACHE STATISTICS ==========")
		print("📸 Images:")
		print("   • Cache hits: \(self.stats.imageHits)")
		print("   • Cache misses: \(self.stats.imageMisses)")
		print("   • Hit rate: \(String(format: "%.1f%%", self.stats.imageHitRate * 100))")
		print("   • Current cache count: \(self.getCurrentCacheCount())")
		print("   • Cache limit: \(self.imageCache.countLimit)")

		print("\n🖼️ Thumbnails:")
		print("   • Cache hits: \(self.stats.thumbnailHits)")
		print("   • Cache misses: \(self.stats.thumbnailMisses)")
		print("   • Hit rate: \(String(format: "%.1f%%", self.stats.thumbnailHitRate * 100))")

		print("\n💾 Disk Operations:")
		print("   • Disk reads: \(self.stats.diskReads)")
		print("   • Disk writes: \(self.stats.diskWrites)")

		print("\n⏱️ Performance:")
		print("   • Total operations: \(self.stats.loadCount)")
		print("   • Average load time: \(String(format: "%.3f", self.stats.averageLoadTime))s")
		print("   • Total time spent loading: \(String(format: "%.3f", self.stats.totalLoadTime))s")

		print("\n💻 Memory:")
		print("   • Process memory: \(self.getMemoryUsage())")
		print("   • Cache memory budget: \(self.imageCache.totalCostLimit / 1_024 / 1_024)MB")
		print("====================================================\n")
	}

	func resetStatistics() {
		self.stats = CacheStatistics()
		print("[PhotoManager] 🔄 Cache statistics reset")
	}

	private func getCurrentCacheCount() -> Int {
		// This is an approximation since NSCache doesn't expose count
		min(self.stats.imageHits + self.stats.imageMisses, self.imageCache.countLimit)
	}

	private func getMemoryUsage() -> String {
		var info = mach_task_basic_info()
		var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

		let result = withUnsafeMutablePointer(to: &info) {
			$0.withMemoryRebound(to: integer_t.self, capacity: 1) {
				task_info(
					mach_task_self_,
					task_flavor_t(MACH_TASK_BASIC_INFO),
					$0,
					&count
				)
			}
		}

		if result == KERN_SUCCESS {
			let usedMemory = Double(info.resident_size) / 1_024.0 / 1_024.0
			return String(format: "%.1fMB", usedMemory)
		}
		return "Unknown"
	}

	private func getMemoryScaleFactor() -> Double {
		let totalMemory = ProcessInfo.processInfo.physicalMemory
		return min(Double(totalMemory) / Double(8 * 1_024 * 1_024 * 1_024), 4.0) // Scale up to 4x for 32GB+ machines
	}

	// MARK: - Metadata Support

	enum CacheType {
		case thumbnail
		case metadata

		var fileExtension: String {
			switch self {
			case .thumbnail: "jpg"
			case .metadata: "plist"
			}
		}
	}

	private func cacheURL(for identifier: Identifier, type: CacheType) -> URL {
		let fileName = identifier.string + "." + type.fileExtension
		let filePath = (self.cacheDirectoryPath as NSString).appendingPathComponent(fileName)
		return URL(fileURLWithPath: filePath)
	}

	private func parseEXIFDate(_ dateString: String) -> Date? {
		// EXIF date format: "yyyy:MM:dd HH:mm:ss"
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		return formatter.date(from: dateString)
	}

	// MARK: - Public API for Statistics

	struct CacheStatisticsReport {
		let imageHits: Int
		let imageMisses: Int
		let thumbnailHits: Int
		let thumbnailMisses: Int
		let diskReads: Int
		let diskWrites: Int
		let totalLoadTime: TimeInterval
		let loadCount: Int
		let averageLoadTime: TimeInterval
		let imageHitRate: Double
		let thumbnailHitRate: Double
	}

	struct MemoryUsageInfo {
		let processMemory: String
		let cacheBudget: Int
		let totalMemory: UInt64
		let imageCacheLimit: Int
	}

	func getCacheStatistics() -> CacheStatisticsReport {
		CacheStatisticsReport(
			imageHits: self.stats.imageHits,
			imageMisses: self.stats.imageMisses,
			thumbnailHits: self.stats.thumbnailHits,
			thumbnailMisses: self.stats.thumbnailMisses,
			diskReads: self.stats.diskReads,
			diskWrites: self.stats.diskWrites,
			totalLoadTime: self.stats.totalLoadTime,
			loadCount: self.stats.loadCount,
			averageLoadTime: self.stats.averageLoadTime,
			imageHitRate: self.stats.imageHitRate,
			thumbnailHitRate: self.stats.thumbnailHitRate
		)
	}

	func getMemoryUsageInfo() -> MemoryUsageInfo {
		let memoryScale = self.getMemoryScaleFactor()
		let baseCount = 16
		let imageCacheLimit = min(baseCount * Int(memoryScale), 64)

		return MemoryUsageInfo(
			processMemory: self.getMemoryUsage(),
			cacheBudget: self.imageCache.totalCostLimit,
			totalMemory: ProcessInfo.processInfo.physicalMemory,
			imageCacheLimit: imageCacheLimit
		)
	}

	// MARK: - Metadata Extraction

	private func extractMetadata(from imageData: Data, fileURL: URL) throws -> PhotoMetadata {
		// Get file attributes
		let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
		let fileModificationDate = attributes[.modificationDate] as? Date ?? Date()
		let fileSize = attributes[.size] as? Int64 ?? 0

		// Extract EXIF using ImageIO
		guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
		      let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
		else {
			// Return basic metadata if image properties can't be read
			return PhotoMetadata(
				dateTaken: nil,
				fileModificationDate: fileModificationDate,
				fileSize: fileSize,
				pixelWidth: nil,
				pixelHeight: nil,
				cameraMake: nil,
				cameraModel: nil,
				orientation: nil,
				gpsLatitude: nil,
				gpsLongitude: nil
			)
		}

		// Extract various metadata
		var dateTaken: Date?
		if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
		   let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String
		{
			dateTaken = self.parseEXIFDate(dateString)
		}

		let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int
		let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int
		let orientation = properties[kCGImagePropertyOrientation as String] as? Int

		// Camera info
		var cameraMake: String?
		var cameraModel: String?
		if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
			cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
			cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
		}

		// GPS info - handle coordinate conversion
		var gpsLatitude: Double?
		var gpsLongitude: Double?
		if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
			if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
			   let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String
			{
				gpsLatitude = latRef == "S" ? -lat : lat
			}
			if let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
			   let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String
			{
				gpsLongitude = lonRef == "W" ? -lon : lon
			}
		}

		return PhotoMetadata(
			dateTaken: dateTaken,
			fileModificationDate: fileModificationDate,
			fileSize: fileSize,
			pixelWidth: pixelWidth,
			pixelHeight: pixelHeight,
			cameraMake: cameraMake,
			cameraModel: cameraModel,
			orientation: orientation,
			gpsLatitude: gpsLatitude,
			gpsLongitude: gpsLongitude
		)
	}

	// Combined thumbnail and metadata loading for efficiency
	func loadPhotoData(for photo: PhotoReference) async throws -> (thumbnail: XThumbnail?, metadata: PhotoMetadata?) {
		try await withCheckedThrowingContinuation { continuation in
			self.queue.async {
				do {
					let result = try self.syncLoadPhotoData(for: photo)
					continuation.resume(returning: result)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func syncLoadPhotoData(for photo: PhotoReference) throws
		-> (thumbnail: XThumbnail?, metadata: PhotoMetadata?)
	{
		// Load image data once
		let imageData = try Data(contentsOf: photo.fileURL)
		let identifier = Identifier.md5(self.md5Digest(of: imageData))

		// Try to get both from cache
		var thumbnail: XThumbnail?
		var metadata: PhotoMetadata?

		// Check thumbnail cache
		if let cachedThumbnail = thumbnailCache.object(forKey: identifier.string as NSString) {
			thumbnail = cachedThumbnail
		} else {
			// Generate thumbnail
			thumbnail = try? self.prepareThumbnail(from: imageData)
			if let thumbnail {
				// Save to cache and disk
				self.thumbnailCache.setObject(thumbnail, forKey: identifier.string as NSString)
				let thumbnailURL = self.cacheURL(for: identifier, type: .thumbnail)
				if let jpegData = thumbnail.jpegData(compressionQuality: 0.8) {
					try? jpegData.write(to: thumbnailURL)
				}
			}
		}

		// Check metadata cache
		if let cachedMetadata = metadataCache.object(forKey: photo.filePath as NSString) {
			metadata = cachedMetadata
		} else {
			// Extract metadata
			metadata = try self.extractMetadata(from: imageData, fileURL: photo.fileURL)
			// Save to cache and disk
			self.metadataCache.setObject(metadata!, forKey: photo.filePath as NSString)
			let metadataURL = self.cacheURL(for: identifier, type: .metadata)
			let encoder = PropertyListEncoder()
			let metadataData = try encoder.encode(metadata!)
			try metadataData.write(to: metadataURL)
		}

		return (thumbnail, metadata)
	}

	// Public API for metadata
	func metadata(for photo: PhotoReference) async throws -> PhotoMetadata? {
		try await withCheckedThrowingContinuation { continuation in
			self.queue.async {
				do {
					let result = try self.syncMetadata(for: photo)
					continuation.resume(returning: result)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func syncMetadata(for photo: PhotoReference) throws -> PhotoMetadata? {
		// Check memory cache first
		if let cached = metadataCache.object(forKey: photo.filePath as NSString) {
			self.stats.thumbnailHits += 1 // Reuse thumbnail stats for now
			return cached
		}

		self.stats.thumbnailMisses += 1

		// Load image data (needed for MD5)
		// TODO: Phase 2 optimization - use file attributes for cache key
		let imageData = try Data(contentsOf: photo.fileURL)
		let identifier = Identifier.md5(self.md5Digest(of: imageData))
		let metadataURL = self.cacheURL(for: identifier, type: .metadata)

		// Check disk cache
		if FileManager.default.fileExists(atPath: metadataURL.path) {
			let data = try Data(contentsOf: metadataURL)
			let metadata = try PropertyListDecoder().decode(PhotoMetadata.self, from: data)
			self.metadataCache.setObject(metadata, forKey: photo.filePath as NSString)
			self.stats.diskReads += 1
			return metadata
		}

		// Extract metadata
		let metadata = try extractMetadata(from: imageData, fileURL: photo.fileURL)

		// Save to disk
		let encoder = PropertyListEncoder()
		let metadataData = try encoder.encode(metadata)
		try metadataData.write(to: metadataURL)
		self.stats.diskWrites += 1

		// Cache in memory
		self.metadataCache.setObject(metadata, forKey: photo.filePath as NSString)

		// If we're extracting metadata, might as well generate thumbnail too
		// Check if thumbnail exists
		let thumbnailURL = self.cacheURL(for: identifier, type: .thumbnail)
		if !FileManager.default.fileExists(atPath: thumbnailURL.path) {
			// Generate and save thumbnail
			if let thumbnail = try? prepareThumbnail(from: imageData) {
				if let jpegData = thumbnail.jpegData(compressionQuality: 0.8) {
					try? jpegData.write(to: thumbnailURL)
					self.thumbnailCache.setObject(thumbnail, forKey: identifier.string as NSString)
				}
			}
		}

		return metadata
	}

	// MARK: - Photo Grouping

	func groupPhotos(_ photos: [PhotoReference], by option: PhotoGroupingOption) -> [PhotoGroup] {
		guard option != .none else {
			// Single group with all photos
			return [PhotoGroup(title: "", photos: photos, dateRepresentative: Date())]
		}

		print("[PhotoManager] Grouping \(photos.count) photos by \(option.rawValue)")

		// Load file dates for all photos that need it
		for photo in photos {
			photo.loadFileCreationDateIfNeeded()
		}

		let calendar = Calendar.current
		let sortedPhotos = photos.sorted { (photo1: PhotoReference, photo2: PhotoReference) -> Bool in
			return (photo1.fileCreationDate ?? Date()) > (photo2.fileCreationDate ?? Date())
		}

		switch option {
		case .year:
			let grouped = Dictionary(grouping: sortedPhotos) { (photo: PhotoReference) -> Int in
				calendar.component(.year, from: photo.fileCreationDate ?? Date())
			}

			return grouped.map { year, photos in
				PhotoGroup(
					title: "\(year)",
					photos: photos,
					dateRepresentative: calendar.date(from: DateComponents(year: year)) ?? Date()
				)
			}.sorted { (group1: PhotoGroup, group2: PhotoGroup) -> Bool in
				group1.dateRepresentative > group2.dateRepresentative
			}

		case .month:
			let formatter = DateFormatter()
			formatter.dateFormat = "MMMM yyyy" // e.g., "April 2024"

			let grouped = Dictionary(grouping: sortedPhotos) { (photo: PhotoReference) -> Date in
				let date = photo.fileCreationDate ?? Date()
				let components = calendar.dateComponents([.year, .month], from: date)
				return calendar.date(from: components) ?? date
			}

			return grouped.map { monthDate, photos in
				PhotoGroup(
					title: formatter.string(from: monthDate),
					photos: photos,
					dateRepresentative: monthDate
				)
			}.sorted { (group1: PhotoGroup, group2: PhotoGroup) -> Bool in
				group1.dateRepresentative > group2.dateRepresentative
			}

		case .day:
			let formatter = DateFormatter()
			formatter.dateFormat = "MMMM d, yyyy" // e.g., "April 15, 2024"

			let grouped = Dictionary(grouping: sortedPhotos) { (photo: PhotoReference) -> Date in
				let date = photo.fileCreationDate ?? Date()
				let components = calendar.dateComponents([.year, .month, .day], from: date)
				return calendar.date(from: components) ?? date
			}

			return grouped.map { dayDate, photos in
				PhotoGroup(
					title: formatter.string(from: dayDate),
					photos: photos,
					dateRepresentative: dayDate
				)
			}.sorted { (group1: PhotoGroup, group2: PhotoGroup) -> Bool in
				group1.dateRepresentative > group2.dateRepresentative
			}

		default:
			return [PhotoGroup(title: "", photos: photos, dateRepresentative: Date())]
		}
	}

}

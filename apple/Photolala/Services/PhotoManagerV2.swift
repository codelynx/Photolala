//
//  PhotoManagerV2.swift
//  Photolala
//
//  Photo manager using two-level PhotoDigest cache architecture
//

import Foundation
import SwiftUI
import Photos
import ImageIO
import CryptoKit
import XPlatform

/// Wrapper class for PhotoDigest to work with NSCache
class PhotoDigestWrapper {
	let digest: PhotoDigest
	
	init(_ digest: PhotoDigest) {
		self.digest = digest
	}
}

@MainActor
class PhotoManagerV2 {
	static let shared = PhotoManagerV2()
	
	private let pathToMD5Cache = PathToMD5Cache.shared
	let memoryCache = NSCache<NSString, PhotoDigestWrapper>()  // Made internal for PhotoManagerV2+Sources
	private let processingQueue = DispatchQueue(label: "com.photolala.photo-processing", qos: .userInitiated)
	
	private init() {
		// Configure memory cache
		memoryCache.countLimit = 500  // Max items
		memoryCache.totalCostLimit = 100 * 1024 * 1024  // 100MB
	}
	
	// MARK: - Public API
	
	/// Get thumbnail for a local photo file
	func thumbnail(for photoFile: PhotoFile) async throws -> XImage? {
		// Level 1: Get MD5 from path
		let attributes = try FileManager.default.attributesOfItem(atPath: photoFile.filePath)
		let fileSize = attributes[.size] as? Int64 ?? 0
		let modificationDate = attributes[.modificationDate] as? Date ?? Date()
		
		let contentMD5: String
		if let cachedMD5 = pathToMD5Cache.getMD5(
			for: photoFile.filePath,
			fileSize: fileSize
		) {
			// Use cached MD5
			contentMD5 = cachedMD5
		} else {
			// Compute MD5
			contentMD5 = try await computeMD5(for: photoFile)
			
			// Cache it
			pathToMD5Cache.setMD5(
				contentMD5,
				for: photoFile.filePath,
				fileSize: fileSize
			)
		}
		
		// Level 2: Get PhotoDigest from MD5
		if let wrapper = memoryCache.object(forKey: contentMD5 as NSString) {
			return wrapper.digest.loadThumbnail()
		}
		
		// Generate new PhotoDigest
		let digest = try await generatePhotoDigest(
			for: photoFile,
			md5: contentMD5,
			fileSize: fileSize,
			modificationDate: modificationDate
		)
		
		// Cache it
		let wrapper = PhotoDigestWrapper(digest)
		memoryCache.setObject(wrapper, forKey: contentMD5 as NSString)
		
		return digest.loadThumbnail()
	}
	
	/// Get PhotoDigest for a file
	func photoDigest(for photoFile: PhotoFile) async throws -> PhotoDigest? {
		// Level 1: Get MD5 from path
		let attributes = try FileManager.default.attributesOfItem(atPath: photoFile.filePath)
		let fileSize = attributes[.size] as? Int64 ?? 0
		let modificationDate = attributes[.modificationDate] as? Date ?? Date()
		
		let contentMD5: String
		if let cachedMD5 = pathToMD5Cache.getMD5(
			for: photoFile.filePath,
			fileSize: fileSize
		) {
			contentMD5 = cachedMD5
		} else {
			contentMD5 = try await computeMD5(for: photoFile)
			pathToMD5Cache.setMD5(
				contentMD5,
				for: photoFile.filePath,
				fileSize: fileSize
			)
		}
		
		// Level 2: Get PhotoDigest
		if let wrapper = memoryCache.object(forKey: contentMD5 as NSString) {
			return wrapper.digest
		}
		
		// Generate new
		let digest = try await generatePhotoDigest(
			for: photoFile,
			md5: contentMD5,
			fileSize: fileSize,
			modificationDate: modificationDate
		)
		
		let wrapper = PhotoDigestWrapper(digest)
		memoryCache.setObject(wrapper, forKey: contentMD5 as NSString)
		
		return digest
	}
	
	// MARK: - Private Methods
	
	private func computeMD5(for photoFile: PhotoFile) async throws -> String {
		return try await withCheckedThrowingContinuation { continuation in
			processingQueue.async {
				do {
					let data = try Data(contentsOf: URL(fileURLWithPath: photoFile.filePath))
					let md5 = Insecure.MD5.hash(data: data)
					let md5String = md5.map { String(format: "%02hhx", $0) }.joined()
					continuation.resume(returning: md5String)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	private func generatePhotoDigest(
		for photoFile: PhotoFile,
		md5: String,
		fileSize: Int64,
		modificationDate: Date
	) async throws -> PhotoDigest {
		return try await withCheckedThrowingContinuation { continuation in
			processingQueue.async {
				do {
					let url = URL(fileURLWithPath: photoFile.filePath)
					
					// Generate thumbnail
					let thumbnailData = try self.generateThumbnail(from: url)
					
					// Save thumbnail to disk
					try PhotoDigest.saveThumbnail(thumbnailData, for: md5)
					
					// Extract metadata
					let metadata = try self.extractMetadata(
						from: url,
						filename: photoFile.filename,
						fileSize: fileSize,
						modificationDate: modificationDate
					)
					
					// Create PhotoDigest (without thumbnail data)
					let digest = PhotoDigest(
						md5Hash: md5,
						metadata: metadata
					)
					
					continuation.resume(returning: digest)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	private func generateThumbnail(from url: URL) throws -> Data {
		// Use existing thumbnail generation logic
		let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil)
		guard let source = imageSource else {
			throw PhotoError.processingFailed(filename: url.lastPathComponent, underlyingError: NSError(domain: "PhotoManagerV2", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create thumbnail"]))
		}
		
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceThumbnailMaxPixelSize: 512,
			kCGImageSourceCreateThumbnailWithTransform: true
		]
		
		guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
			throw PhotoError.processingFailed(filename: url.lastPathComponent, underlyingError: NSError(domain: "PhotoManagerV2", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create thumbnail"]))
		}
		
		#if os(macOS)
		let image = NSImage(cgImage: cgImage, size: NSZeroSize)
		guard let tiffData = image.tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiffData),
			  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
			throw PhotoError.processingFailed(filename: url.lastPathComponent, underlyingError: NSError(domain: "PhotoManagerV2", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create thumbnail"]))
		}
		return jpegData
		#else
		let image = UIImage(cgImage: cgImage)
		guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
			throw PhotoError.processingFailed(filename: url.lastPathComponent, underlyingError: NSError(domain: "PhotoManagerV2", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create thumbnail"]))
		}
		return jpegData
		#endif
	}
	
	private func extractMetadata(
		from url: URL,
		filename: String,
		fileSize: Int64,
		modificationDate: Date
	) throws -> PhotoDigestMetadata {
		// Extract image properties
		guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
			  let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
			// Return basic metadata if we can't read image properties
			return PhotoDigestMetadata(
				filename: filename,
				fileSize: fileSize,
				pixelWidth: nil,
				pixelHeight: nil,
				creationDate: nil,
				modificationTimestamp: Int(modificationDate.timeIntervalSince1970)
			)
		}
		
		// Extract dimensions
		let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int
		let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int
		
		// Extract creation date from EXIF
		var creationDate: Date?
		if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
		   let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
			// Parse EXIF date
			let formatter = DateFormatter()
			formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
			creationDate = formatter.date(from: dateString)
		}
		
		return PhotoDigestMetadata(
			filename: filename,
			fileSize: fileSize,
			pixelWidth: pixelWidth,
			pixelHeight: pixelHeight,
			creationDate: creationDate,
			modificationTimestamp: Int(modificationDate.timeIntervalSince1970)
		)
	}
	
	// MARK: - Additional Methods for UI Compatibility
	
	/// Group photos by specified grouping option
	func groupPhotos(_ photos: [any PhotoItem], by grouping: PhotoGroupingOption) -> [PhotoGroup] {
		guard grouping != .none else {
			// For compatibility with PhotoGroup, we need PhotoFile array
			// For now, only group PhotoFile items
			let photoFiles = photos.compactMap { $0 as? PhotoFile }
			return [PhotoGroup(title: "", photos: photoFiles, dateRepresentative: Date())]
		}
		
		// Filter to PhotoFile for compatibility with PhotoGroup
		let photoFiles = photos.compactMap { $0 as? PhotoFile }
		
		// Load file dates for all photos that need it
		for photo in photoFiles {
			photo.loadFileCreationDateIfNeeded()
		}
		
		let calendar = Calendar.current
		let sortedPhotos = photoFiles.sorted { photo1, photo2 in
			(photo1.fileCreationDate ?? Date()) > (photo2.fileCreationDate ?? Date())
		}
		
		switch grouping {
		case .year:
			let grouped = Dictionary(grouping: sortedPhotos) { photo in
				calendar.component(.year, from: photo.fileCreationDate ?? Date())
			}
			
			return grouped.map { year, photos in
				PhotoGroup(
					title: "\(year)",
					photos: photos,
					dateRepresentative: calendar.date(from: DateComponents(year: year)) ?? Date()
				)
			}.sorted { group1, group2 in
				group1.dateRepresentative > group2.dateRepresentative
			}
			
		case .yearMonth:
			let formatter = DateFormatter()
			formatter.dateFormat = "MMMM yyyy"
			
			let grouped = Dictionary(grouping: sortedPhotos) { photo in
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
			}.sorted { group1, group2 in
				group1.dateRepresentative > group2.dateRepresentative
			}
			
		default:
			return [PhotoGroup(title: "", photos: photoFiles, dateRepresentative: Date())]
		}
	}
	
	/// Prefetch thumbnails for given photos
	func prefetchThumbnails(for photos: [any PhotoItem]) async {
		// Use priority loader for batch prefetching
		for photo in photos {
			PriorityThumbnailLoaderV2.shared.requestThumbnail(for: photo, priority: .prefetch)
		}
	}
	
	/// Load full image for a photo
	func loadFullImage(for photo: any PhotoItem) async throws -> XImage? {
		// Handle different photo types
		switch photo {
		case let photoFile as PhotoFile:
			// Load full image from file
			let data = try Data(contentsOf: URL(fileURLWithPath: photoFile.filePath))
			return XImage(data: data)
		case let photoApple as PhotoApple:
			// Load full image data and convert to image
			let data = try await photoApple.loadImageData()
			return XImage(data: data)
		case let photoS3 as PhotoS3:
			// Load from S3
			let data = try await S3DownloadService.shared.downloadPhoto(for: photoS3)
			return XImage(data: data)
		default:
			return nil
		}
	}
	
	/// Get metadata for a photo
	func metadata(for photo: any PhotoItem) async throws -> PhotoMetadata? {
		// Try to get from PhotoDigest first
		if let photoFile = photo as? PhotoFile,
		   let digest = try? await photoDigest(for: photoFile) {
			// Convert PhotoDigestMetadata to PhotoMetadata
			return PhotoMetadata(
				dateTaken: digest.metadata.creationDate,
				fileModificationDate: Date(timeIntervalSince1970: TimeInterval(digest.metadata.modificationTimestamp)),
				fileSize: digest.metadata.fileSize,
				pixelWidth: digest.metadata.pixelWidth,
				pixelHeight: digest.metadata.pixelHeight
			)
		}
		
		// For other photo types, handle appropriately
		switch photo {
		case let photoApple as PhotoApple:
			// Create metadata from PhotoApple properties
			let fileSize = try await photoApple.loadFileSize()
			return PhotoMetadata(
				dateTaken: photoApple.creationDate,
				fileModificationDate: photoApple.modificationDate ?? photoApple.creationDate ?? Date(),
				fileSize: fileSize,
				pixelWidth: photoApple.width,
				pixelHeight: photoApple.height
			)
		case let photoS3 as PhotoS3:
			// Create metadata from S3 photo properties
			return PhotoMetadata(
				dateTaken: photoS3.photoDate,
				fileModificationDate: photoS3.modified,
				fileSize: photoS3.size,
				pixelWidth: photoS3.width,
				pixelHeight: photoS3.height
			)
		default:
			return nil
		}
	}
	
	/// Prefetch images with priority
	func prefetchImages(for photos: [any PhotoItem], priority: TaskPriority) async {
		// Use priority loader for all photo types
		for photo in photos {
			PriorityThumbnailLoaderV2.shared.requestThumbnail(for: photo, priority: .prefetch)
		}
	}
	
	// MARK: - Statistics
	
	struct CacheStatisticsReport {
		let memoryCount: Int
		let memoryUsage: Int
		let diskCount: Int
		let diskUsage: Int64
	}
	
	struct MemoryUsageInfo {
		let totalMemory: Int64
		let availableMemory: Int64
		let usedMemory: Int64
	}
	
	func printCacheStatistics() {
		print("=== PhotoManagerV2 Cache Statistics ===")
		print("Memory Cache: \(memoryCache.countLimit) max items")
		print("Path-to-MD5 Cache: Active")
		
		// Count disk thumbnails
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let photolalaCache = cacheDir.appendingPathComponent("com.electricwoods.photolala")
		let thumbnailCache = photolalaCache.appendingPathComponent("thumbnails")
		
		do {
			let files = try FileManager.default.contentsOfDirectory(at: thumbnailCache, includingPropertiesForKeys: [.fileSizeKey])
			var totalSize: Int64 = 0
			for file in files {
				if let size = try? file.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize {
					totalSize += Int64(size)
				}
			}
			print("Disk Thumbnails: \(files.count) files, \(totalSize / 1024 / 1024) MB")
		} catch {
			print("Unable to read disk cache")
		}
	}
	
	func resetStatistics() {
		// Clear memory cache
		memoryCache.removeAllObjects()
		PathToMD5Cache.shared.clearAll()
		print("Cache statistics reset")
	}
	
	func getCacheStatistics() -> CacheStatisticsReport {
		var diskCount = 0
		var diskUsage: Int64 = 0
		
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let photolalaCache = cacheDir.appendingPathComponent("com.electricwoods.photolala")
		let thumbnailCache = photolalaCache.appendingPathComponent("thumbnails")
		
		do {
			let files = try FileManager.default.contentsOfDirectory(at: thumbnailCache, includingPropertiesForKeys: [.fileSizeKey])
			diskCount = files.count
			for file in files {
				if let size = try? file.resourceValues(forKeys: [URLResourceKey.fileSizeKey]).fileSize {
					diskUsage += Int64(size)
				}
			}
		} catch {
			// Ignore errors
		}
		
		return CacheStatisticsReport(
			memoryCount: memoryCache.countLimit,
			memoryUsage: memoryCache.totalCostLimit,
			diskCount: diskCount,
			diskUsage: diskUsage
		)
	}
	
	func getMemoryUsageInfo() -> MemoryUsageInfo {
		var info = mach_task_basic_info()
		var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
		
		let result = withUnsafeMutablePointer(to: &info) { infoPtr in
			infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
				task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
			}
		}
		
		let usedMemory = result == KERN_SUCCESS ? Int64(info.resident_size) : 0
		
		let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
		let availableMemory = totalMemory - usedMemory
		
		return MemoryUsageInfo(
			totalMemory: totalMemory,
			availableMemory: availableMemory,
			usedMemory: usedMemory
		)
	}
	
	func loadArchiveStatus(for catalogEntries: [CatalogEntry], userId: String) async {
		// PhotoManagerV2 doesn't need this for now
		// Archive status is handled differently in the new architecture
	}
}


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

@MainActor
class PhotoManagerV2 {
	static let shared = PhotoManagerV2()
	
	private let pathToMD5Cache = PathToMD5Cache.shared
	let photoDigestCache = PhotoDigestCache.shared  // Made internal for PhotoManagerV2+Sources
	private let processingQueue = DispatchQueue(label: "com.photolala.photo-processing", qos: .userInitiated)
	
	private init() {}
	
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
			fileSize: fileSize,
			modificationDate: modificationDate
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
				fileSize: fileSize,
				modificationDate: modificationDate
			)
		}
		
		// Level 2: Get PhotoDigest from MD5
		if let digest = await photoDigestCache.getPhotoDigest(for: contentMD5) {
			return digest.thumbnail
		}
		
		// Generate new PhotoDigest
		let digest = try await generatePhotoDigest(
			for: photoFile,
			md5: contentMD5,
			fileSize: fileSize,
			modificationDate: modificationDate
		)
		
		// Cache it
		await photoDigestCache.setPhotoDigest(digest, for: contentMD5)
		
		return digest.thumbnail
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
			fileSize: fileSize,
			modificationDate: modificationDate
		) {
			contentMD5 = cachedMD5
		} else {
			contentMD5 = try await computeMD5(for: photoFile)
			pathToMD5Cache.setMD5(
				contentMD5,
				for: photoFile.filePath,
				fileSize: fileSize,
				modificationDate: modificationDate
			)
		}
		
		// Level 2: Get PhotoDigest
		if let digest = await photoDigestCache.getPhotoDigest(for: contentMD5) {
			return digest
		}
		
		// Generate new
		let digest = try await generatePhotoDigest(
			for: photoFile,
			md5: contentMD5,
			fileSize: fileSize,
			modificationDate: modificationDate
		)
		
		await photoDigestCache.setPhotoDigest(digest, for: contentMD5)
		
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
					
					// Extract metadata
					let metadata = try self.extractMetadata(
						from: url,
						filename: photoFile.filename,
						fileSize: fileSize,
						modificationDate: modificationDate
					)
					
					// Create PhotoDigest
					let digest = PhotoDigest(
						md5Hash: md5,
						thumbnailData: thumbnailData,
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
		// Convert to PhotoFile array for compatibility
		let photoFiles = photos.compactMap { $0 as? PhotoFile }
		return PhotoManager.shared.groupPhotos(photoFiles, by: grouping)
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
			return try await PhotoManager.shared.loadFullImage(for: photoFile)
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
		// Convert to PhotoFile array if possible for compatibility
		let photoFiles = photos.compactMap { $0 as? PhotoFile }
		if !photoFiles.isEmpty {
			await PhotoManager.shared.prefetchImages(for: photoFiles, priority: priority)
		}
		// For other photo types, prefetch thumbnails instead
		for photo in photos where !(photo is PhotoFile) {
			PriorityThumbnailLoaderV2.shared.requestThumbnail(for: photo, priority: .prefetch)
		}
	}
	
	// MARK: - Statistics (Delegate to PhotoManager for now)
	
	func printCacheStatistics() {
		PhotoManager.shared.printCacheStatistics()
	}
	
	func resetStatistics() {
		PhotoManager.shared.resetStatistics()
	}
	
	func getCacheStatistics() -> PhotoManager.CacheStatisticsReport {
		PhotoManager.shared.getCacheStatistics()
	}
	
	func getMemoryUsageInfo() -> PhotoManager.MemoryUsageInfo {
		PhotoManager.shared.getMemoryUsageInfo()
	}
	
	func loadArchiveStatus(for catalogEntries: [CatalogEntry], userId: String) async {
		// PhotoManagerV2 doesn't need this for now
		// Archive status is handled differently in the new architecture
	}
}


//
//  PhotoManagerV2+Sources.swift
//  Photolala
//
//  Extensions for handling different photo sources with PhotoDigest
//

import Foundation
import SwiftUI
import Photos
import XPlatform
import CryptoKit

extension PhotoManagerV2 {
	
	// MARK: - Apple Photos Support
	
	/// Get thumbnail for Apple Photo (fast path - no MD5)
	func thumbnailForBrowsing(for photoApple: PhotoApple) async throws -> XImage? {
		// Use Apple Photo ID as cache key for browsing
		let cacheKey = "applePhotos|\(photoApple.id)"
		
		// Check if we have a full PhotoDigest (from previous star operation)
		if let existingMD5 = await getExistingMD5(for: photoApple) {
			if let wrapper = PhotoManagerV2.shared.memoryCache.object(forKey: existingMD5 as NSString) {
				return wrapper.digest.loadThumbnail()
			}
		}
		
		// For browsing, just use Photos framework directly (no PhotoDigest)
		return try await photoApple.loadThumbnail()
	}
	
	/// Get full PhotoDigest for Apple Photo (for backup/star operations)
	func photoDigestForBackup(for photoApple: PhotoApple) async throws -> PhotoDigest {
		// Load full image data to compute MD5
		let imageData = try await photoApple.loadImageData()
		let md5Hash = computeMD5(from: imageData)
		
		// Check if we already have this PhotoDigest
		if let wrapper = PhotoManagerV2.shared.memoryCache.object(forKey: md5Hash as NSString) {
			return wrapper.digest
		}
		
		// Generate thumbnail from data
		let thumbnailData = try generateThumbnailFromData(imageData)
		
		// Save thumbnail to disk
		try PhotoDigest.saveThumbnail(thumbnailData, for: md5Hash)
		
		// Extract metadata
		let metadata = PhotoDigestMetadata(
			filename: photoApple.filename,
			fileSize: Int64(imageData.count),
			pixelWidth: photoApple.width,
			pixelHeight: photoApple.height,
			creationDate: photoApple.creationDate,
			modificationTimestamp: Int((photoApple.modificationDate ?? Date()).timeIntervalSince1970)
		)
		
		// Create PhotoDigest (without thumbnail data)
		let digest = PhotoDigest(
			md5Hash: md5Hash,
			metadata: metadata
		)
		
		// Cache it
		let wrapper = PhotoDigestWrapper(digest)
		PhotoManagerV2.shared.memoryCache.setObject(wrapper, forKey: md5Hash as NSString)
		
		// Also store Apple Photo ID → MD5 mapping for future lookups
		await storeApplePhotoMapping(photoID: photoApple.id, md5: md5Hash)
		
		return digest
	}
	
	// MARK: - S3 Photos Support
	
	/// Get PhotoDigest for S3 photo
	func photoDigest(for photoS3: PhotoS3) async throws -> PhotoDigest? {
		let md5 = photoS3.md5
		
		// Check cache first
		if let wrapper = PhotoManagerV2.shared.memoryCache.object(forKey: md5 as NSString) {
			return wrapper.digest
		}
		
		// Download thumbnail from S3
		guard let thumbnailData = try await S3DownloadService.shared.downloadThumbnailData(
			key: photoS3.thumbnailKey,
			userId: photoS3.userId
		) else {
			return nil
		}
		
		// Create metadata from PhotoS3 fields
		let metadata = PhotoDigestMetadata(
			filename: photoS3.filename,
			fileSize: photoS3.size,
			pixelWidth: photoS3.width,
			pixelHeight: photoS3.height,
			creationDate: photoS3.photoDate,
			modificationTimestamp: Int(photoS3.modified.timeIntervalSince1970)
		)
		
		// Save thumbnail to disk (S3 thumbnails are already downloaded)
		try PhotoDigest.saveThumbnail(thumbnailData, for: md5)
		
		// Create PhotoDigest (without thumbnail data)
		let digest = PhotoDigest(
			md5Hash: md5,
			metadata: metadata
		)
		
		// Cache in S3-specific location
		let wrapper = PhotoDigestWrapper(digest)
		PhotoManagerV2.shared.memoryCache.setObject(wrapper, forKey: md5 as NSString)
		
		return digest
	}
	
	// MARK: - Unified Thumbnail Interface
	
	/// Get thumbnail for any PhotoItem
	func thumbnail(for photo: any PhotoItem) async throws -> XImage? {
		switch photo {
		case let photoFile as PhotoFile:
			return try await thumbnail(for: photoFile)
			
		case let photoApple as PhotoApple:
			return try await thumbnailForBrowsing(for: photoApple)
			
		case let photoS3 as PhotoS3:
			let digest = try await photoDigest(for: photoS3)
			return digest?.loadThumbnail()
			
		default:
			return nil
		}
	}
	
	// MARK: - Helper Methods
	
	private func computeMD5(from data: Data) -> String {
		let hash = Insecure.MD5.hash(data: data)
		return hash.map { String(format: "%02hhx", $0) }.joined()
	}
	
	private func generateThumbnailFromData(_ data: Data) throws -> Data {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
			throw PhotoError.processingFailed(
				filename: "Unknown",
				underlyingError: NSError(domain: "PhotoManagerV2", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
			)
		}
		
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceThumbnailMaxPixelSize: 512,
			kCGImageSourceCreateThumbnailWithTransform: true
		]
		
		guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
			throw PhotoError.processingFailed(
				filename: "Unknown",
				underlyingError: NSError(domain: "PhotoManagerV2", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create thumbnail"])
			)
		}
		
		#if os(macOS)
		let image = NSImage(cgImage: cgImage, size: NSZeroSize)
		guard let tiffData = image.tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiffData),
			  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
			throw PhotoError.processingFailed(
				filename: "Unknown",
				underlyingError: NSError(domain: "PhotoManagerV2", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to encode thumbnail"])
			)
		}
		return jpegData
		#else
		let image = UIImage(cgImage: cgImage)
		guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
			throw PhotoError.processingFailed(
				filename: "Unknown",
				underlyingError: NSError(domain: "PhotoManagerV2", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to encode thumbnail"])
			)
		}
		return jpegData
		#endif
	}
	
	// MARK: - Apple Photo Mapping
	
	private func getExistingMD5(for photoApple: PhotoApple) async -> String? {
		// This would check a persistent mapping of Apple Photo ID → MD5
		// For now, return nil (to be implemented with SwiftData integration)
		return nil
	}
	
	private func storeApplePhotoMapping(photoID: String, md5: String) async {
		// Store the mapping for future lookups
		// To be implemented with SwiftData integration
	}
}
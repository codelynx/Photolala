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

@MainActor
class PhotoManagerV2 {
	static let shared = PhotoManagerV2()
	
	private let pathToMD5Cache = PathToMD5Cache.shared
	private let photoDigestCache = PhotoDigestCache.shared
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
			throw PhotoError.thumbnailGenerationFailed
		}
		
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceThumbnailMaxPixelSize: 512,
			kCGImageSourceCreateThumbnailWithTransform: true
		]
		
		guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
			throw PhotoError.thumbnailGenerationFailed
		}
		
		#if os(macOS)
		let image = NSImage(cgImage: cgImage, size: NSZeroSize)
		guard let tiffData = image.tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiffData),
			  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
			throw PhotoError.thumbnailGenerationFailed
		}
		return jpegData
		#else
		let image = UIImage(cgImage: cgImage)
		guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
			throw PhotoError.thumbnailGenerationFailed
		}
		return jpegData
		#endif
	}
	
	private func extractMetadata(
		from url: URL,
		filename: String,
		fileSize: Int64,
		modificationDate: Date
	) throws -> PhotoMetadata {
		// Extract image properties
		guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
			  let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
			// Return basic metadata if we can't read image properties
			return PhotoMetadata(
				filename: filename,
				fileSize: fileSize,
				modificationDate: modificationDate
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
		
		return PhotoMetadata(
			filename: filename,
			fileSize: fileSize,
			pixelWidth: pixelWidth,
			pixelHeight: pixelHeight,
			creationDate: creationDate,
			modificationDate: modificationDate
		)
	}
}

// MARK: - Error Types

enum PhotoError: Error {
	case thumbnailGenerationFailed
	case metadataExtractionFailed
	case fileNotFound
	case invalidImageData
}
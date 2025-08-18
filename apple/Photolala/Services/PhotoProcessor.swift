//
//  PhotoProcessor.swift
//  Photolala
//
//  Unified photo processing to read file once for thumbnail, MD5, and metadata
//

import Foundation
import SwiftUI
import CryptoKit
import ImageIO
import XPlatform

/// Processes photos efficiently by reading the file once for all operations
@MainActor
class PhotoProcessor {
	
	// MARK: - Placeholder Generation
	
	/// Generate a placeholder image for corrupted/empty files
	@MainActor
	static func generateCorruptedFilePlaceholder(for filename: String) -> XImage? {
		let size = CGSize(width: 256, height: 256)
		
		#if os(macOS)
		let image = NSImage(size: size)
		image.lockFocus()
		
		// Background
		NSColor.systemGray.withAlphaComponent(0.2).setFill()
		NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
		
		// Icon
		let iconRect = NSRect(x: 96, y: 96, width: 64, height: 64)
		NSColor.systemRed.withAlphaComponent(0.7).setFill()
		let path = NSBezierPath()
		path.move(to: NSPoint(x: iconRect.midX, y: iconRect.minY))
		path.line(to: NSPoint(x: iconRect.maxX, y: iconRect.maxY))
		path.line(to: NSPoint(x: iconRect.minX, y: iconRect.maxY))
		path.close()
		path.fill()
		
		// Exclamation mark
		NSColor.white.setFill()
		NSBezierPath(ovalIn: NSRect(x: iconRect.midX - 4, y: iconRect.midY - 12, width: 8, height: 8)).fill()
		NSBezierPath(rect: NSRect(x: iconRect.midX - 4, y: iconRect.midY, width: 8, height: 20)).fill()
		
		image.unlockFocus()
		return image
		#else
		UIGraphicsBeginImageContextWithOptions(size, false, 0)
		defer { UIGraphicsEndImageContext() }
		
		guard let context = UIGraphicsGetCurrentContext() else { return nil }
		
		// Background
		context.setFillColor(UIColor.systemGray.withAlphaComponent(0.2).cgColor)
		context.fill(CGRect(origin: .zero, size: size))
		
		// Icon
		let iconRect = CGRect(x: 96, y: 96, width: 64, height: 64)
		context.setFillColor(UIColor.systemRed.withAlphaComponent(0.7).cgColor)
		context.beginPath()
		context.move(to: CGPoint(x: iconRect.midX, y: iconRect.minY))
		context.addLine(to: CGPoint(x: iconRect.maxX, y: iconRect.maxY))
		context.addLine(to: CGPoint(x: iconRect.minX, y: iconRect.maxY))
		context.closePath()
		context.fillPath()
		
		// Exclamation mark
		context.setFillColor(UIColor.white.cgColor)
		context.fillEllipse(in: CGRect(x: iconRect.midX - 4, y: iconRect.midY - 12, width: 8, height: 8))
		context.fill(CGRect(x: iconRect.midX - 4, y: iconRect.midY, width: 8, height: 20))
		
		return UIGraphicsGetImageFromCurrentImageContext()
		#endif
	}
	
	/// Result of processing a photo file
	struct ProcessedData {
		let thumbnail: XImage
		let md5: String
		let metadata: PhotoMetadata
		let thumbnailData: Data // For saving to disk
	}
	
	/// Process a photo file, extracting thumbnail, MD5, and metadata in a single pass
	static func processPhoto(_ photo: PhotoFile) async throws -> ProcessedData {
		let startTime = Date()
		
		// Check if we have a valid cached MD5
		let attributes = try FileManager.default.attributesOfItem(atPath: photo.filePath)
		let fileSize = attributes[.size] as? Int64 ?? 0
		let modificationDate = attributes[.modificationDate] as? Date ?? Date()
		
		// Early check for empty files
		if fileSize == 0 {
			print("[PhotoProcessor] Empty file detected: \(photo.filename)")
			throw PhotoError.emptyFile(filename: photo.filename)
		}
		
		let md5Result: String
		let needsFullRead: Bool
		
		if let cachedMD5 = ThumbnailMetadataCache.shared.getCachedMD5(
			for: photo.filePath,
			fileSize: fileSize,
			modificationDate: modificationDate
		) {
			// We have a valid cached MD5
			md5Result = cachedMD5
			needsFullRead = false
			print("[PhotoProcessor] Using cached MD5 for \(photo.filename)")
		} else {
			// Need to read file and compute MD5
			needsFullRead = true
			md5Result = ""  // Will be computed below
		}
		
		// If we don't need full read, just generate thumbnail from file
		if !needsFullRead {
			// Just read for thumbnail generation
			let data = try Data(contentsOf: photo.fileURL)
			print("[PhotoProcessor] Read \(data.count / 1024)KB from \(photo.filename) for thumbnail")
			
			// Process everything needed
			async let thumbnail = generateThumbnail(from: data, filename: photo.filename)
			async let metadata = extractMetadata(from: data, url: photo.fileURL)
			
			// Wait for operations
			let (thumbnailResult, metadataResult) = try await (thumbnail, metadata)
			
			let elapsed = Date().timeIntervalSince(startTime)
			print("[PhotoProcessor] Processed \(photo.filename) in \(String(format: "%.3f", elapsed))s (cached MD5)")
			
			return ProcessedData(
				thumbnail: thumbnailResult.image,
				md5: md5Result,
				metadata: metadataResult,
				thumbnailData: thumbnailResult.data
			)
		} else {
			// Full processing - read once for all operations
			let data = try Data(contentsOf: photo.fileURL)
			print("[PhotoProcessor] Read \(data.count / 1024)KB from \(photo.filename)")
			
			// Process everything in parallel
			async let thumbnail = generateThumbnail(from: data, filename: photo.filename)
			async let md5 = computeMD5(from: data)
			async let metadata = extractMetadata(from: data, url: photo.fileURL)
			
			// Wait for all operations
			let (thumbnailResult, computedMD5, metadataResult) = try await (thumbnail, md5, metadata)
			
			// Store MD5 in metadata cache
			ThumbnailMetadataCache.shared.setMetadata(
				filePath: photo.filePath,
				md5Hash: computedMD5,
				fileSize: fileSize,
				modificationDate: modificationDate
			)
			
			let elapsed = Date().timeIntervalSince(startTime)
			print("[PhotoProcessor] Processed \(photo.filename) in \(String(format: "%.3f", elapsed))s")
			
			return ProcessedData(
				thumbnail: thumbnailResult.image,
				md5: computedMD5,
				metadata: metadataResult,
				thumbnailData: thumbnailResult.data
			)
		}
	}
	
	// MARK: - Private Processing Methods
	
	private static func generateThumbnail(from data: Data, filename: String) async throws -> (image: XImage, data: Data) {
		// Check for empty file first
		if data.isEmpty {
			throw PhotoError.emptyFile(filename: filename)
		}
		
		// Try to create image
		guard let sourceImage = XImage(data: data) else {
			// File has data but can't be decoded as an image
			throw PhotoError.corruptedFile(filename: filename)
		}
		
		// Scale so that the shorter side becomes 256 pixels
		let originalSize = sourceImage.size
		let minSide = min(originalSize.width, originalSize.height)
		let scale = 256.0 / minSide
		let scaledSize = CGSize(
			width: originalSize.width * scale,
			height: originalSize.height * scale
		)
		
		// Calculate crop dimensions (max 512x512)
		let cropWidth = min(scaledSize.width, 512)
		let cropHeight = min(scaledSize.height, 512)
		let cropX = (scaledSize.width - cropWidth) / 2
		let cropY = (scaledSize.height - cropHeight) / 2
		
		#if os(macOS)
		// macOS implementation
		guard let tiffData = sourceImage.tiffRepresentation,
			  let _ = NSBitmapImageRep(data: tiffData) else {
			throw NSError(domain: "PhotoProcessor", code: 2,
						  userInfo: [NSLocalizedDescriptionKey: "Unable to get image representation"])
		}
		
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
			throw NSError(domain: "PhotoProcessor", code: 3,
						  userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap representation"])
		}
		
		NSGraphicsContext.saveGraphicsState()
		NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newRep)
		
		let sourceRect = NSRect(x: 0, y: 0, width: originalSize.width, height: originalSize.height)
		let destRect = NSRect(x: -cropX, y: -cropY, width: scaledSize.width, height: scaledSize.height)
		sourceImage.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
		
		NSGraphicsContext.restoreGraphicsState()
		
		// Get JPEG data with 0.8 quality
		guard let jpegData = newRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
			throw NSError(domain: "PhotoProcessor", code: 4,
						  userInfo: [NSLocalizedDescriptionKey: "Unable to create JPEG data"])
		}
		
		let thumbnail = NSImage(size: NSSize(width: cropWidth, height: cropHeight))
		thumbnail.addRepresentation(newRep)
		
		return (thumbnail, jpegData)
		#else
		// iOS implementation
		UIGraphicsBeginImageContextWithOptions(CGSize(width: cropWidth, height: cropHeight), false, 1.0)
		defer { UIGraphicsEndImageContext() }
		
		sourceImage.draw(in: CGRect(x: -cropX, y: -cropY, width: scaledSize.width, height: scaledSize.height))
		
		guard let thumbnail = UIGraphicsGetImageFromCurrentImageContext(),
			  let jpegData = thumbnail.jpegData(compressionQuality: 0.8) else {
			throw NSError(domain: "PhotoProcessor", code: 4,
						  userInfo: [NSLocalizedDescriptionKey: "Unable to create thumbnail"])
		}
		
		return (thumbnail, jpegData)
		#endif
	}
	
	private static func computeMD5(from data: Data) async -> String {
		let digest = Insecure.MD5.hash(data: data)
		return digest.map { String(format: "%02x", $0) }.joined()
	}
	
	private static func extractMetadata(from data: Data, url: URL) async throws -> PhotoMetadata {
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
			throw NSError(domain: "PhotoProcessor", code: 5,
						  userInfo: [NSLocalizedDescriptionKey: "Unable to create image source"])
		}
		
		// Get properties
		let options = [kCGImageSourceShouldCache: false] as CFDictionary
		guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, options) as? [String: Any] else {
			throw NSError(domain: "PhotoProcessor", code: 6,
						  userInfo: [NSLocalizedDescriptionKey: "Unable to get image properties"])
		}
		
		// Extract metadata
		let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int
		let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int
		
		// Get EXIF data
		let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
		let dateTimeOriginal = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String
		
		// Get TIFF data
		let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
		let make = tiff?[kCGImagePropertyTIFFMake as String] as? String
		let model = tiff?[kCGImagePropertyTIFFModel as String] as? String
		
		// Get GPS data
		let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
		let latitude = gps?[kCGImagePropertyGPSLatitude as String] as? Double
		let longitude = gps?[kCGImagePropertyGPSLongitude as String] as? Double
		
		// Parse date
		var dateTaken: Date?
		if let dateTimeOriginal = dateTimeOriginal {
			let formatter = DateFormatter()
			formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
			dateTaken = formatter.date(from: dateTimeOriginal)
		}
		
		// Get file attributes
		let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
		let fileSize = attributes[.size] as? Int64 ?? 0
		
		// Get file modification date
		let fileModificationDate = attributes[.modificationDate] as? Date ?? Date()
		
		return PhotoMetadata(
			dateTaken: dateTaken,
			fileModificationDate: fileModificationDate,
			fileSize: fileSize,
			pixelWidth: pixelWidth,
			pixelHeight: pixelHeight,
			cameraMake: make,
			cameraModel: model,
			gpsLatitude: latitude,
			gpsLongitude: longitude
		)
	}
}
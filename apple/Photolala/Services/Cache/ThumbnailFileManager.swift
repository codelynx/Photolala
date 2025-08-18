//
//  ThumbnailFileManager.swift
//  Photolala
//
//  Manages thumbnail files on disk with sharded storage
//

import Foundation
import SwiftUI
import XPlatform

/// Manages thumbnail files on disk
actor ThumbnailFileManager {
	static let shared = ThumbnailFileManager()
	
	private let baseURL: URL
	private let maxThumbnailSize = 256  // Maximum dimension
	private let compressionQuality: CGFloat = 0.8
	
	private init() {
		let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let photolalaDir = cacheDir.appendingPathComponent("com.electricwoods.photolala")
		self.baseURL = photolalaDir.appendingPathComponent("thumbnails")
		
		// Create base directory
		try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
	}
	
	// MARK: - Public API
	
	/// Save thumbnail data to disk
	func saveThumbnail(_ data: Data, for md5: String) async throws {
		let url = thumbnailURL(for: md5)
		
		// Create shard directory if needed
		let shardDir = url.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: shardDir, withIntermediateDirectories: true)
		
		// Write thumbnail data
		try data.write(to: url)
	}
	
	/// Save thumbnail image to disk
	func saveThumbnail(_ image: XImage, for md5: String) async throws -> (data: Data, width: Int, height: Int) {
		// Resize if needed
		let resized = resizeImage(image, maxDimension: maxThumbnailSize)
		
		// Convert to JPEG data
		#if os(macOS)
		guard let tiffData = resized.tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiffData),
			  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) else {
			throw ThumbnailError.conversionFailed
		}
		let width = Int(bitmap.pixelsWide)
		let height = Int(bitmap.pixelsHigh)
		#else
		guard let jpegData = resized.jpegData(compressionQuality: compressionQuality) else {
			throw ThumbnailError.conversionFailed
		}
		let width = Int(resized.size.width * resized.scale)
		let height = Int(resized.size.height * resized.scale)
		#endif
		
		// Save to disk
		try await saveThumbnail(jpegData, for: md5)
		
		return (jpegData, width, height)
	}
	
	/// Load thumbnail data from disk
	func loadThumbnail(for md5: String) async -> Data? {
		let url = thumbnailURL(for: md5)
		return try? Data(contentsOf: url)
	}
	
	/// Load thumbnail image from disk
	func loadThumbnailImage(for md5: String) async -> XImage? {
		guard let data = await loadThumbnail(for: md5) else { return nil }
		return XImage(data: data)
	}
	
	/// Delete thumbnail from disk
	func deleteThumbnail(for md5: String) async {
		let url = thumbnailURL(for: md5)
		try? FileManager.default.removeItem(at: url)
	}
	
	/// Check if thumbnail exists
	func thumbnailExists(for md5: String) -> Bool {
		let url = thumbnailURL(for: md5)
		return FileManager.default.fileExists(atPath: url.path)
	}
	
	/// Get thumbnail file size
	func thumbnailSize(for md5: String) -> Int? {
		let url = thumbnailURL(for: md5)
		let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
		return attributes?[.size] as? Int
	}
	
	/// Clean up orphaned thumbnails (not in database)
	func cleanupOrphanedThumbnails(validMD5s: Set<String>) async {
		do {
			// Iterate through all shard directories
			let shardDirs = try FileManager.default.contentsOfDirectory(
				at: baseURL,
				includingPropertiesForKeys: nil
			)
			
			var deletedCount = 0
			for shardDir in shardDirs {
				let thumbnails = try FileManager.default.contentsOfDirectory(
					at: shardDir,
					includingPropertiesForKeys: nil
				)
				
				for thumbnailURL in thumbnails {
					let filename = thumbnailURL.deletingPathExtension().lastPathComponent
					if !validMD5s.contains(filename) {
						try FileManager.default.removeItem(at: thumbnailURL)
						deletedCount += 1
					}
				}
			}
			
			if deletedCount > 0 {
				print("[ThumbnailFileManager] Deleted \(deletedCount) orphaned thumbnails")
			}
		} catch {
			print("[ThumbnailFileManager] Cleanup error: \(error)")
		}
	}
	
	/// Clear all thumbnails
	func clearAll() async {
		try? FileManager.default.removeItem(at: baseURL)
		try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
	}
	
	// MARK: - Private Methods
	
	private func thumbnailURL(for md5: String) -> URL {
		// Use first 2 characters for sharding (256 possible directories)
		let shard = String(md5.prefix(2))
		let shardDir = baseURL.appendingPathComponent(shard)
		return shardDir.appendingPathComponent("\(md5).jpg")
	}
	
	private func resizeImage(_ image: XImage, maxDimension: Int) -> XImage {
		#if os(macOS)
		let currentSize = image.size
		#else
		let currentSize = CGSize(
			width: image.size.width * image.scale,
			height: image.size.height * image.scale
		)
		#endif
		
		// Check if resizing is needed
		let maxDim = max(currentSize.width, currentSize.height)
		if maxDim <= CGFloat(maxDimension) {
			return image
		}
		
		// Calculate new size
		let scale = CGFloat(maxDimension) / maxDim
		let newSize = CGSize(
			width: currentSize.width * scale,
			height: currentSize.height * scale
		)
		
		#if os(macOS)
		let newImage = NSImage(size: newSize)
		newImage.lockFocus()
		image.draw(in: NSRect(origin: .zero, size: newSize))
		newImage.unlockFocus()
		return newImage
		#else
		UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
		defer { UIGraphicsEndImageContext() }
		image.draw(in: CGRect(origin: .zero, size: newSize))
		return UIGraphicsGetImageFromCurrentImageContext() ?? image
		#endif
	}
}

enum ThumbnailError: Error {
	case conversionFailed
	case invalidImage
}
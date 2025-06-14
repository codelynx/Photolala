//
//  PhotoManager.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//
import Foundation
import SwiftUI
import CryptoKit

class PhotoManager {

	typealias XThumbnail = XImage

	enum Identifier {
		case md5(Insecure.MD5Digest) // universal photo identifier
		case applePhotoLibrary(String) // unique device wide
		var string: String {
			switch self {
			case .md5(let digest): return "md5#\(digest.data.hexadecimalString)"
			case .applePhotoLibrary(let identifier): return "apl#\(identifier)"
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
	
	private func error(message: String) ->Error {
		return NSError(domain: "PhotoManager", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
	}

	func md5Digest(of data: Data) -> Insecure.MD5Digest {
		return Insecure.MD5.hash(data: data)
	}
	
	private let imageCache = NSCache<NSString, XImage>() // filePath: XImage
	private let thumbnailCache = NSCache<NSString, XThumbnail>() // PhotoManager.Identifier: XThumbnail
	private let queue = DispatchQueue(label: "com.photolala.PhotoManager", qos: .userInitiated, attributes: .concurrent)
	
	func loadImage(for photo: PhotoReference) async throws -> XImage? {
		return try await withCheckedThrowingContinuation { continuation in
			queue.async {
				do {
					let result = try self.syncLoadImage(for: photo)
					continuation.resume(returning: result)
				} catch {
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
			let identifier = PhotoManager.Identifier.md5(md5Digest(of: imageData))
			if self.hasThumbnail(for: identifier) == false {
				try self.prepareThumbnail(from: imageData)
			}
			return image
		}
		else { return nil }
	}

	@discardableResult
	func prepareThumbnail(from data: Data) throws -> XThumbnail? {
		guard let image = XImage(data: data) else {
			throw error(message: "Unable to create image from data")
		}
		let md5 = md5Digest(of: data)
		let identifier = PhotoManager.Identifier.md5(md5)

		// Scale so that the shorter side becomes 256 pixels
		let originalSize = image.size
		let minSide = min(originalSize.width, originalSize.height)
		let scale = 256.0 / minSide
		let scaledSize = CGSize(width: originalSize.width * scale,
								height: originalSize.height * scale)
		
#if os(macOS)
		// On macOS, NSImage already handles EXIF orientation automatically
		// when we create it from data, so we just need to get a bitmap rep
		guard let tiffData = image.tiffRepresentation,
			  let imageRep = NSBitmapImageRep(data: tiffData) else {
			throw error(message: "Unable to get image representation")
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
			throw error(message: "Unable to create bitmap representation")
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
			throw error(message: "Unable to create JPEG data")
		}
		
		// Save to file
		let thumbnailFilePath = self.thumbnailURL(for: identifier).path
		try jpegData.write(to: URL(fileURLWithPath: thumbnailFilePath))
		
		// Create and cache the thumbnail
		let thumbnail = NSImage(size: NSSize(width: cropWidth, height: cropHeight))
		thumbnail.addRepresentation(newRep)
		thumbnailCache.setObject(thumbnail, forKey: identifier.string as NSString)
		return thumbnail
#else
		// Resize on iOS - handle orientation properly
		// First, normalize the image orientation by drawing it
		UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
		image.draw(at: .zero)
		guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
			UIGraphicsEndImageContext()
			throw error(message: "Unable to normalize image orientation")
		}
		UIGraphicsEndImageContext()
		
		guard let cgImage = normalizedImage.cgImage else {
			throw error(message: "Unable to get CGImage")
		}
		
		// Now scale and crop with the normalized image
		let cropWidth = min(scaledSize.width, 512)
		let cropHeight = min(scaledSize.height, 512)
		
		// Create a context with the final size
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(data: nil,
									  width: Int(cropWidth),
									  height: Int(cropHeight),
									  bitsPerComponent: 8,
									  bytesPerRow: 0,
									  space: colorSpace,
									  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
			throw error(message: "Unable to create bitmap context")
		}
		
		// Calculate the drawing rect to center the cropped area
		let drawRect = CGRect(x: -(scaledSize.width - cropWidth) / 2,
							  y: -(scaledSize.height - cropHeight) / 2,
							  width: scaledSize.width,
							  height: scaledSize.height)
		
		// Draw the scaled image
		context.interpolationQuality = .high
		context.draw(cgImage, in: drawRect)
		
		// Get the final image
		guard let finalCGImage = context.makeImage() else {
			throw error(message: "Unable to create final image")
		}
		
		let finalImage = UIImage(cgImage: finalCGImage)
		guard let jpegData = finalImage.jpegData(compressionQuality: 0.8) else {
			throw error(message: "Unable to create JPEG data")
		}
		let thumbnailFilePath = self.thumbnailURL(for: identifier).path
		try jpegData.write(to: URL(fileURLWithPath: thumbnailFilePath))
		// Cache the generated thumbnail
		thumbnailCache.setObject(finalImage, forKey: identifier.string as NSString)
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
		return try await withCheckedThrowingContinuation { continuation in
			queue.async {
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
		let imageData = try Data(contentsOf: photoRep.fileURL)
		let identifier = Identifier.md5(md5Digest(of: imageData))
		if let cached = thumbnailCache.object(forKey: identifier.string as NSString) {
			return cached
		}
		if hasThumbnail(for: identifier) {
			let data = try Data(contentsOf: thumbnailURL(for: identifier))
			if let thumbnail = XImage(data: data) {
				thumbnailCache.setObject(thumbnail, forKey: identifier.string as NSString)
				return thumbnail
			}
		}
		return try prepareThumbnail(from: imageData)
	}
	
	func hasThumbnail(for identifier: Identifier) -> Bool {
		return FileManager.default.fileExists(atPath: self.thumbnailURL(for: identifier).path)
	}

	private let photolalaStoragePath: NSString
	private let thumbnailStoragePath: NSString

	private init() {
		let photolalaStoragePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("Photolala").path
		do { try FileManager.default.createDirectory(atPath: photolalaStoragePath, withIntermediateDirectories: true) }
		catch { fatalError("\(error): cannot create photolala storage directory: \(photolalaStoragePath)") }
		self.photolalaStoragePath = photolalaStoragePath as NSString
		print("photolala directory: \(photolalaStoragePath)")

		let thumbnailStoragePath = (photolalaStoragePath as NSString).appendingPathComponent("thumbnails")
		do { try FileManager.default.createDirectory(atPath: thumbnailStoragePath, withIntermediateDirectories: true) }
		catch { fatalError("\(error): cannot create thumbnail directory: \(thumbnailStoragePath)") }
		self.thumbnailStoragePath = thumbnailStoragePath as NSString
	}
}

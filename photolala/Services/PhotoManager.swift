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
			case .md5(let digest): return "md5#\(digest)"
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
		let filePath = self.thumbnailStoragePath.appendingPathComponent(identifier.string).appending(".jpg")
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
	private let queue = DispatchQueue(label: "com.photolala.PhotoManager", attributes: .concurrent)
	
	func loadImage(for photo: PhotoRepresentation) async throws -> XImage? {
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
	
	private func syncLoadImage(for photo: PhotoRepresentation) throws -> XImage? {
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
		let scale = 256 / minSide
		let scaledSize = CGSize(width: originalSize.width * scale,
								height: originalSize.height * scale)
		
#if os(macOS)
		// Resize on macOS
		let resized = NSImage(size: scaledSize)
		resized.lockFocus()
		image.draw(in: NSRect(origin: .zero, size: scaledSize),
				   from: NSRect(origin: .zero, size: originalSize),
				   operation: .copy,
				   fraction: 1.0)
		resized.unlockFocus()
		
		// Crop the long side to max 512 px
		guard let cg = resized.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
			throw self.error(message: "Unable to get CGImage")
		}
		let cropWidth = min(scaledSize.width, 512)
		let cropHeight = min(scaledSize.height, 512)
		let cropRect = CGRect(x: (scaledSize.width - cropWidth) / 2,
							  y: (scaledSize.height - cropHeight) / 2,
							  width: cropWidth,
							  height: cropHeight)
		guard let croppedCG = cg.cropping(to: cropRect) else {
			throw error(message: "Unable to crop CGImage")
		}
		let rep = NSBitmapImageRep(cgImage: croppedCG)
		guard let jpegData = rep.representation(using: .jpeg, properties: [:]) else {
			throw error(message: "Unable to write JPEG data")
		}
		let thumbnailFilePath = self.thumbnailURL(for: identifier).path
		try jpegData.write(to: URL(fileURLWithPath: thumbnailFilePath))
		// Create and cache the thumbnail
		let thumbnail = NSImage(cgImage: croppedCG, size: NSSize(width: cropWidth, height: cropHeight))
		imageCache.setObject(thumbnail, forKey: identifier.string as NSString)
		return thumbnail
#else
		// Resize on iOS
		UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
		image.draw(in: CGRect(origin: .zero, size: scaledSize))
		guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
			UIGraphicsEndImageContext()
			throw error(message: "Unable to get resized image")
		}
		UIGraphicsEndImageContext()
		
		// Crop the long side to max 512 px
		guard let cgImage = resizedImage.cgImage else {
			throw error(message: "Unable to get CGIImage")
		}
		let cropWidth = min(scaledSize.width, 512)
		let cropHeight = min(scaledSize.height, 512)
		let cropRect = CGRect(x: (scaledSize.width - cropWidth) / 2,
							  y: (scaledSize.height - cropHeight) / 2,
							  width: cropWidth,
							  height: cropHeight)
		guard let croppedCG = cgImage.cropping(to: cropRect) else {
			throw error(message: "Unable to crop CGImage")
		}
		let finalImage = UIImage(cgImage: croppedCG, scale: 0.0, orientation: .up)
		guard let jpegData = finalImage.jpegData(compressionQuality: 0.8) else {
			throw error(message: "Unable to write JPEG data")
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
	
	func thumbnail(for photoRep: PhotoRepresentation) async throws -> XThumbnail? {
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
	
	private func syncThumbnail(for photoRep: PhotoRepresentation) throws -> XThumbnail? {
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

		let thumbnailStoragePath = (photolalaStoragePath as NSString).appendingPathComponent("thumbnails")
		do { try FileManager.default.createDirectory(atPath: thumbnailStoragePath, withIntermediateDirectories: true) }
		catch { fatalError("\(error): cannot create thumbnail directory: \(thumbnailStoragePath)") }
		self.thumbnailStoragePath = thumbnailStoragePath as NSString
		
		print("photolala storage directory: \(photolalaStoragePath)")
	}
}

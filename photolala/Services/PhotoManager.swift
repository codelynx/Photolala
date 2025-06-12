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

	enum Identifier {
		case md5(Insecure.MD5Digest, Int) // universal photo identifier
		case applePhotoLibrary(String) // unique device wide
		var string: String {
			switch self {
			case .md5(let digest, let index):
				return "md5#\(digest)#\(index)"
			case .applePhotoLibrary(let identifier):
				return "apl#\(identifier)"
			}
		}
		init?(string: String) {
			let components = string.split(separator: "#")
			switch components.count {
			case 3 where components[0] == "md5":
				guard let data = Data(hexadecimalString: String(components[1])),
					  let md5 = Insecure.MD5Digest(rawBytes: data),
					  let size = Int(String(components[2]))
				else { return nil }
				self = .md5(md5, size)
			case 2 where components[0] == "apl":
				self = .applePhotoLibrary(String(components[1]))
			default:
				return nil
			}
		}
	}

	static let shared = PhotoManager()
	private(set) lazy var photolalaStoragePath: NSString = {
		let directoryPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("Photolala").path
		do { try FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true) }
		catch { fatalError("cannot create directory: \(directoryPath), \(error)") }
		return directoryPath as NSString
	}()
	private(set) lazy var thumbnailStoragePath: NSString = {
		let directoryPath = self.photolalaStoragePath.appendingPathComponent("thumbnails")
		do { try FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true) }
		catch { fatalError("cannot create directory: \(directoryPath), \(error)") }
		return directoryPath as NSString
	}()
	func thumbnailFilePath(for identifier: PhotoManager.Identifier) -> String {
		return self.thumbnailStoragePath.appendingPathComponent(identifier.string).appending(".jpg")
	}
	
	private func error(message: String) ->Error {
		return NSError(domain: "PhotoManager", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
	}

	func computeMD5(_ data: Data) -> Insecure.MD5Digest {
		return Insecure.MD5.hash(data: data)
	}
	
	func thumbnail(rawData: Data) throws -> XImage? {
		guard let image = XImage(data: rawData) else {
			throw error(message: "Unable to create image from data")
		}
		let md5 = computeMD5(rawData)
		let identifier = PhotoManager.Identifier.md5(md5, rawData.count)

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
		let thumbnailFilePath = self.thumbnailFilePath(for: identifier)
		try jpegData.write(to: URL(filePath: thumbnailFilePath))
		return NSImage(cgImage: croppedCG, size: NSSize(width: cropWidth, height: cropHeight))
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
		let thumbnailFilePath = self.thumbnailFilePath(for: identifier)
		try jpegData.write(to: URL(fileURLWithPath: thumbnailFilePath) as URL)
		return finalImage
#endif
	}
	
	func thumbnail(for identifier: PhotoManager.Identifier) -> XImage? {
		let filePath = self.thumbnailFilePath(for: identifier)
		if FileManager.default.fileExists(atPath: filePath) {
			if let data = try? Data(contentsOf: URL(filePath: filePath)),
			   let image = XImage(data: data) {
				return image
			}
		}
		return nil
	}
	

	private init() {}
}

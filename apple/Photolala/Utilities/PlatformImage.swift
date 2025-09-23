//
//  PlatformImage.swift
//  Photolala
//
//  Cross-platform image type for unified photo browser
//

import SwiftUI

#if os(macOS)
import AppKit
/// Platform-specific image type
public typealias PlatformImage = NSImage

extension NSImage {
	/// Convert to SwiftUI Image
	var swiftUIImage: Image {
		Image(nsImage: self)
	}
}
#else
import UIKit
/// Platform-specific image type
public typealias PlatformImage = UIImage

extension UIImage {
	/// Convert to SwiftUI Image
	var swiftUIImage: Image {
		Image(uiImage: self)
	}
}
#endif

// MARK: - Common Extensions

extension PlatformImage {
	/// Create image from data
	static func fromData(_ data: Data) -> PlatformImage? {
		PlatformImage(data: data)
	}

	/// Get PNG representation
	var pngData: Data? {
		#if os(macOS)
		guard let tiff = self.tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiff) else {
			return nil
		}
		return bitmap.representation(using: .png, properties: [:])
		#else
		return self.pngData()
		#endif
	}

	/// Get JPEG representation with compression
	func jpegData(compressionQuality: CGFloat) -> Data? {
		#if os(macOS)
		guard let tiff = self.tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiff) else {
			return nil
		}
		return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
		#else
		return self.jpegData(compressionQuality: compressionQuality)
		#endif
	}

	/// Scale image to fit within maximum size
	func scaled(toFit maxSize: CGSize) -> PlatformImage? {
		let aspectWidth = maxSize.width / size.width
		let aspectHeight = maxSize.height / size.height
		let aspectRatio = min(aspectWidth, aspectHeight)

		let newSize = CGSize(
			width: size.width * aspectRatio,
			height: size.height * aspectRatio
		)

		#if os(macOS)
		let newImage = NSImage(size: newSize)
		newImage.lockFocus()
		self.draw(in: NSRect(origin: .zero, size: newSize))
		newImage.unlockFocus()
		return newImage
		#else
		UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
		defer { UIGraphicsEndImageContext() }
		self.draw(in: CGRect(origin: .zero, size: newSize))
		return UIGraphicsGetImageFromCurrentImageContext()
		#endif
	}
}
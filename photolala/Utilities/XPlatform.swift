//
//  XPlatform.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Foundation
import SwiftUI

#if canImport(AppKit)
	import AppKit
	public typealias XView = NSView
	public typealias XViewController = NSViewController
	public typealias XWindow = NSWindow
	public typealias XImage = NSImage
	public typealias XColor = NSColor
	public typealias XCollectionView = NSCollectionView
	public typealias XCollectionViewDelegate = NSCollectionViewDelegate
	public typealias XCollectionViewDataSource = NSCollectionViewDataSource
	public typealias XViewControllerRepresentable = NSViewControllerRepresentable
	public typealias XViewRepresentable = NSViewRepresentable
	public typealias XMenu = NSMenu
	public typealias XCollectionViewDiffableDataSource = NSCollectionViewDiffableDataSource
	public typealias XCollectionViewLayout = NSCollectionViewLayout
#endif

#if canImport(UIKit)
	import UIKit
	public typealias XView = UIView
	public typealias XViewController = UIViewController
	public typealias XWindow = UIWindow
	public typealias XImage = UIImage
	public typealias XColor = UIColor
	public typealias XCollectionView = UICollectionView
	public typealias XCollectionViewDelegate = UICollectionViewDelegate
	public typealias XCollectionViewDataSource = UICollectionViewDataSource
	public typealias XViewControllerRepresentable = UIViewControllerRepresentable
	public typealias XViewRepresentable = UIViewRepresentable
	public typealias XMenu = UIMenu
	public typealias XCollectionViewDiffableDataSource = UICollectionViewDiffableDataSource
	public typealias XCollectionViewLayout = UICollectionViewLayout
#endif

extension XView {
	#if canImport(AppKit)
	func setNeedsLayout() {
		self.needsLayout = true
	}
	#elseif canImport(UIKit)
	// setNeedsLayout() there
	#endif
}

// Cross-platform image data extension
extension XImage {

	#if canImport(AppKit)
		func jpegData(compressionQuality: CGFloat) -> Data? {
			guard let tiffData = self.tiffRepresentation,
			      let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
			return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
		}
	#endif
}

// MARK: - Image Extension

extension Image {
	init(_ image: XImage) {
		#if os(macOS)
		self.init(nsImage: image)
		#else
		self.init(uiImage: image)
		#endif
	}
}


// MARK: - Cross-platform Button Styles

extension View {
	/// Applies a link-style button appearance across platforms
	func linkButtonStyle() -> some View {
		#if os(macOS)
		self.buttonStyle(.link)
		#else
		self.buttonStyle(.plain)
			.foregroundColor(.blue)
		#endif
	}
	
	/// Applies a primary button style across platforms
	func primaryButtonStyle() -> some View {
		#if os(macOS)
		self.buttonStyle(.borderedProminent)
		#else
		self.buttonStyle(.borderedProminent)
		#endif
	}
	
	/// Applies a secondary button style across platforms
	func secondaryButtonStyle() -> some View {
		#if os(macOS)
		self.buttonStyle(.bordered)
		#else
		self.buttonStyle(.bordered)
		#endif
	}
}

// MARK: - Cross-platform Colors

struct XPlatform {
	#if os(macOS)
	static let primaryBackgroundColor = NSColor.controlBackgroundColor
	static let secondaryBackgroundColor = NSColor.windowBackgroundColor
	static let tertiaryBackgroundColor = NSColor.controlBackgroundColor
	#else
	static let primaryBackgroundColor = UIColor.systemBackground
	static let secondaryBackgroundColor = UIColor.systemBackground
	static let tertiaryBackgroundColor = UIColor.secondarySystemBackground
	#endif
}

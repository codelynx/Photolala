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
public typealias XViewController = NSViewController
public typealias XWindow = NSWindow
public typealias XImage = NSImage
public typealias XColor = NSColor
public typealias XCollectionView = NSCollectionView
public typealias XCollectionViewDelegate = NSCollectionViewDelegate
public typealias XCollectionViewDataSource = NSCollectionViewDataSource
public typealias XViewControllerRepresentable = NSViewControllerRepresentable
#endif

#if canImport(UIKit)
import UIKit
public typealias XViewController = UIViewController
public typealias XWindow = UIWindow
public typealias XImage = UIImage
public typealias XColor = UIColor
public typealias XCollectionView = UICollectionView
public typealias XCollectionViewDelegate = UICollectionViewDelegate
public typealias XCollectionViewDataSource = UICollectionViewDataSource
public typealias XViewControllerRepresentable = UIViewControllerRepresentable
#endif

// Cross-platform image data extension
extension XImage {
	func jpegData(compressionQuality: CGFloat) -> Data? {
		#if canImport(AppKit)
		guard let tiffData = self.tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
		return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
		#else
		return self.jpegData(compressionQuality: compressionQuality)
		#endif
	}
}


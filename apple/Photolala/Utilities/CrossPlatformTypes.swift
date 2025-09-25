//
//  CrossPlatformTypes.swift
//  Photolala
//
//  Cross-platform type aliases for unified code across macOS and iOS
//

import Foundation

#if os(macOS)
import AppKit

typealias XView = NSView
typealias XImageView = NSImageView
typealias XImage = NSImage
typealias XColor = NSColor
typealias XActivityIndicator = NSProgressIndicator
typealias XBezierPath = NSBezierPath
typealias XFont = NSFont
typealias XScreen = NSScreen
typealias XTextField = NSTextField
typealias XStackView = NSStackView

#else
import UIKit

typealias XView = UIView
typealias XImageView = UIImageView
typealias XImage = UIImage
typealias XColor = UIColor
typealias XActivityIndicator = UIActivityIndicatorView
typealias XBezierPath = UIBezierPath
typealias XFont = UIFont
typealias XScreen = UIScreen
typealias XTextField = UILabel
typealias XStackView = UIStackView

#endif

// MARK: - Horizontal and Vertical Stack Views

/// Horizontal stack view - preconfigured for horizontal layout
class XHStackView: XStackView {
	override init(frame: CGRect) {
		super.init(frame: frame)
		#if os(macOS)
		self.orientation = .horizontal
		self.distribution = .fill
		self.alignment = .centerY
		#else
		self.axis = .horizontal
		self.distribution = .fill
		self.alignment = .center
		#endif
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		#if os(macOS)
		self.orientation = .horizontal
		self.distribution = .fill
		self.alignment = .centerY
		#else
		self.axis = .horizontal
		self.distribution = .fill
		self.alignment = .center
		#endif
	}

	convenience init(spacing: CGFloat = 0) {
		self.init(frame: .zero)
		self.spacing = spacing
	}
}

/// Vertical stack view - preconfigured for vertical layout
class XVStackView: XStackView {
	override init(frame: CGRect) {
		super.init(frame: frame)
		#if os(macOS)
		self.orientation = .vertical
		self.distribution = .fill
		self.alignment = .centerX
		#else
		self.axis = .vertical
		self.distribution = .fill
		self.alignment = .center
		#endif
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		#if os(macOS)
		self.orientation = .vertical
		self.distribution = .fill
		self.alignment = .centerX
		#else
		self.axis = .vertical
		self.distribution = .fill
		self.alignment = .center
		#endif
	}

	convenience init(spacing: CGFloat = 0) {
		self.init(frame: .zero)
		self.spacing = spacing
	}
}
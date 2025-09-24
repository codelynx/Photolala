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

#endif
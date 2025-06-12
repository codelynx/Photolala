//
//  XPlatform.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Foundation

#if canImport(AppKit)
import AppKit
typealias XViewController = NSViewController
typealias XWindow = NSWindow
typealias XImage = NSImage
typealias XColor = NSColor
#endif

#if canImport(UIKit)
import UIKit
typealias XViewController = UIViewController
typealias XWindow = UIWindow
typealias XImage = UIImage
typealias XColor = UIColor
#endif


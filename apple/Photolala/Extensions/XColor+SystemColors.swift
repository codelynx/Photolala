//
//  XColor+SystemColors.swift
//  Photolala
//
//  Cross-platform system color mappings
//

import SwiftUI

#if os(macOS)
import AppKit

extension NSColor {
	// Map iOS system colors to macOS equivalents
	static var systemBackground: NSColor {
		return .windowBackgroundColor
	}

	static var secondarySystemBackground: NSColor {
		return .controlBackgroundColor
	}

	static var tertiarySystemBackground: NSColor {
		return .controlBackgroundColor
	}

	static var separator: NSColor {
		return .separatorColor
	}
}

#endif
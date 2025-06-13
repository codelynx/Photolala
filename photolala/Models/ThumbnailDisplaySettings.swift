//
//  ThumbnailDisplaySettings.swift
//  photolala
//
//  Created by Assistant on 2025-06-13.
//

import SwiftUI

enum ThumbnailDisplayMode: String, CaseIterable {
	case scaleToFit = "fit"
	case scaleToFill = "fill"
	
	var localizedName: String {
		switch self {
		case .scaleToFit:
			return "Scale to Fit"
		case .scaleToFill:
			return "Scale to Fill"
		}
	}
}

enum ThumbnailSize: CaseIterable {
	case small
	case medium
	case large
	
	var value: CGFloat {
		switch self {
		case .small: return 64
		case .medium: return 128
		case .large: return 256
		}
	}
	
	var name: String {
		switch self {
		case .small: return "Small"
		case .medium: return "Medium"
		case .large: return "Large"
		}
	}
	
	static var defaultValue: CGFloat { Self.medium.value }
}

@Observable
class ThumbnailDisplaySettings {
	var displayMode: ThumbnailDisplayMode = .scaleToFit
	var thumbnailSize: CGFloat = ThumbnailSize.large.value // Default to Large (256px)
	
	init() {
		// No UserDefaults - each window gets its own settings
	}
	
	func setPresetSize(_ size: ThumbnailSize) {
		thumbnailSize = size.value
	}
	
	func currentPresetSize() -> ThumbnailSize? {
		return ThumbnailSize.allCases.first { $0.value == thumbnailSize }
	}
}

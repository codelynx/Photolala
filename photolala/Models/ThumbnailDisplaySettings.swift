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

enum ThumbnailOption: CaseIterable {
	case small
	case medium
	case large
	
	static var `default`: ThumbnailOption { .medium }
	
	var size: CGFloat {
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
	
	var spacing: CGFloat {
		switch self {
		case .small: return 2
		case .medium: return 4
		case .large: return 8
		}
	}
	
	var cornerRadius: CGFloat {
		switch self {
		case .small: return 0
		case .medium: return 6
		case .large: return 12
		}
	}
	
	var sectionInset: CGFloat {
		switch self {
		case .small: return 4
		case .medium: return 8
		case .large: return 12
		}
	}
}

@Observable
class ThumbnailDisplaySettings {
	var displayMode: ThumbnailDisplayMode = .scaleToFit
	var thumbnailOption: ThumbnailOption = .default
	
	var thumbnailSize: CGFloat {
		thumbnailOption.size
	}
	
	init() {
		// No UserDefaults - each window gets its own settings
	}
}

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
			"Scale to Fit"
		case .scaleToFill:
			"Scale to Fill"
		}
	}
}

enum ThumbnailOption: CaseIterable, Hashable {
	case small
	case medium
	case large

	static var `default`: ThumbnailOption { .medium }

	var size: CGFloat {
		switch self {
		case .small: 64
		case .medium: 128
		case .large: 256
		}
	}

	var name: String {
		switch self {
		case .small: "Small"
		case .medium: "Medium"
		case .large: "Large"
		}
	}

	var spacing: CGFloat {
		switch self {
		case .small: 2
		case .medium: 4
		case .large: 8
		}
	}

	var cornerRadius: CGFloat {
		switch self {
		case .small: 0
		case .medium: 6
		case .large: 12
		}
	}

	var sectionInset: CGFloat {
		switch self {
		case .small: 4
		case .medium: 8
		case .large: 12
		}
	}
}

@Observable
class ThumbnailDisplaySettings {
	var displayMode: ThumbnailDisplayMode = .scaleToFit
	var thumbnailOption: ThumbnailOption = .default
	var sortOption: PhotoSortOption = .filename
	var groupingOption: PhotoGroupingOption = .none

	var thumbnailSize: CGFloat {
		self.thumbnailOption.size
	}

	init() {
		// No UserDefaults - each window gets its own settings
	}
}

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

	// Get device-aware size based on screen width
	func size(for screenWidth: CGFloat) -> CGFloat {
		let category = DeviceCategory.current(for: screenWidth)
		let sizes = DeviceSizeHelper.getRecommendedThumbnailSizes(for: category)
		
		switch self {
		case .small: return sizes[0].size
		case .medium: return sizes[1].size
		case .large: return sizes[2].size
		}
	}
	
	// Legacy fixed size for backwards compatibility
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
	var displayMode: ThumbnailDisplayMode = .scaleToFill
	var thumbnailOption: ThumbnailOption = .default
	var sortOption: PhotoSortOption = .filename
	var groupingOption: PhotoGroupingOption = .none
	var thumbnailSize: CGFloat = 150
	var spacing: CGFloat = 8
	var showItemInfo: Bool = true

	// Convenience properties
	var canIncreaseThumbnailSize: Bool {
		thumbnailSize < 400
	}
	
	var canDecreaseThumbnailSize: Bool {
		thumbnailSize > 80
	}

	init() {
		// No UserDefaults - each window gets its own settings
		// Use device-aware size if we can get screen width
		#if os(iOS)
		if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
			let screenWidth = windowScene.screen.bounds.width
			self.thumbnailSize = thumbnailOption.size(for: screenWidth)
		} else {
			self.thumbnailSize = thumbnailOption.size
		}
		#else
		self.thumbnailSize = thumbnailOption.size
		#endif
		self.spacing = thumbnailOption.spacing
	}
	
	func increaseThumbnailSize() {
		if canIncreaseThumbnailSize {
			thumbnailSize += 20
		}
	}
	
	func decreaseThumbnailSize() {
		if canDecreaseThumbnailSize {
			thumbnailSize -= 20
		}
	}
}

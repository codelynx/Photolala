//
//  PhotoBrowserSettings.swift
//  Photolala
//
//  Photo browser display settings and configuration
//

import SwiftUI
import Observation

// MARK: - Thumbnail Size

/// Available thumbnail size options
enum ThumbnailSize: String, CaseIterable {
	case small = "S"
	case medium = "M"
	case large = "L"

	/// Display title for UI
	var title: String {
		switch self {
		case .small: return "Small"
		case .medium: return "Medium"
		case .large: return "Large"
		}
	}

	/// Base size in points
	var baseSize: CGFloat {
		switch self {
		case .small: return 64
		case .medium: return 128
		case .large: return 256
		}
	}

	/// Spacing between items
	var spacing: CGFloat {
		switch self {
		case .small: return 1
		case .medium: return 2
		case .large: return 4
		}
	}

	/// Section insets
	var sectionInset: CGFloat {
		switch self {
		case .small: return 2
		case .medium: return 4
		case .large: return 8
		}
	}

	/// Info bar height (if shown)
	var infoBarHeight: CGFloat {
		switch self {
		case .small: return 16
		case .medium: return 20
		case .large: return 24
		}
	}

	/// Font size for info bar
	var fontSize: CGFloat {
		switch self {
		case .small: return 10
		case .medium: return 11
		case .large: return 12
		}
	}
}

// MARK: - Display Mode

/// Thumbnail display mode options
enum ThumbnailDisplayMode: String, CaseIterable {
	case fit = "Fit"
	case fill = "Fill"

	var title: String { rawValue }
}

// MARK: - Photo Browser Settings

/// Observable settings for photo browser display
@Observable
final class PhotoBrowserSettings {
	// MARK: - Properties

	/// Current thumbnail size
	var thumbnailSize: ThumbnailSize = .medium {
		didSet {
			saveToUserDefaults()
		}
	}

	/// Display mode (fit or fill)
	var displayMode: ThumbnailDisplayMode = .fill {
		didSet {
			saveToUserDefaults()
		}
	}

	/// Show info bar with date and file size
	var showInfoBar: Bool = true {
		didSet {
			saveToUserDefaults()
		}
	}

	/// Enable dynamic sizing (smart grid optimization)
	var useDynamicSizing: Bool = true {
		didSet {
			saveToUserDefaults()
		}
	}

	/// Dynamic adjustment percentage (-20% to +20%)
	var dynamicAdjustment: CGFloat = 0

	// MARK: - Computed Properties

	/// Calculate item size including info bar
	var itemSize: CGSize {
		let base = thumbnailSize.baseSize
		let adjustedSize = useDynamicSizing ? base * (1 + dynamicAdjustment / 100) : base
		let height = showInfoBar ? adjustedSize + thumbnailSize.infoBarHeight : adjustedSize
		return CGSize(width: adjustedSize, height: height)
	}

	/// Get item spacing
	var itemSpacing: CGFloat {
		thumbnailSize.spacing
	}

	/// Get section insets
	var sectionInsets: NSDirectionalEdgeInsets {
		let inset = thumbnailSize.sectionInset
		return NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
	}

	// MARK: - Initialization

	init() {
		loadFromUserDefaults()
	}

	// MARK: - Persistence

	private let defaults = UserDefaults.standard

	private enum Keys {
		static let thumbnailSize = "PhotoBrowser.thumbnailSize"
		static let displayMode = "PhotoBrowser.displayMode"
		static let showInfoBar = "PhotoBrowser.showInfoBar"
		static let useDynamicSizing = "PhotoBrowser.useDynamicSizing"
	}

	private func saveToUserDefaults() {
		defaults.set(thumbnailSize.rawValue, forKey: Keys.thumbnailSize)
		defaults.set(displayMode.rawValue, forKey: Keys.displayMode)
		defaults.set(showInfoBar, forKey: Keys.showInfoBar)
		defaults.set(useDynamicSizing, forKey: Keys.useDynamicSizing)
	}

	private func loadFromUserDefaults() {
		if let sizeRaw = defaults.string(forKey: Keys.thumbnailSize),
		   let size = ThumbnailSize(rawValue: sizeRaw) {
			thumbnailSize = size
		}

		if let modeRaw = defaults.string(forKey: Keys.displayMode),
		   let mode = ThumbnailDisplayMode(rawValue: modeRaw) {
			displayMode = mode
		}

		// Use object(forKey:) to check if key exists, otherwise use default
		if defaults.object(forKey: Keys.showInfoBar) != nil {
			showInfoBar = defaults.bool(forKey: Keys.showInfoBar)
		}

		if defaults.object(forKey: Keys.useDynamicSizing) != nil {
			useDynamicSizing = defaults.bool(forKey: Keys.useDynamicSizing)
		}
	}

	// MARK: - Smart Grid Optimization

	/// Calculate optimal item size and column count for available width
	func optimizeLayout(for availableWidth: CGFloat) -> (itemSize: CGSize, columns: Int) {
		let baseSize = thumbnailSize.baseSize
		let spacing = thumbnailSize.spacing
		let inset = thumbnailSize.sectionInset

		// Calculate usable width
		let usableWidth = availableWidth - (2 * inset)

		// Start with base size
		var itemWidth = baseSize
		var columns = Int((usableWidth + spacing) / (baseSize + spacing))

		if useDynamicSizing && columns > 0 {
			// Calculate wasted space with current columns
			let totalSpacing = CGFloat(columns - 1) * spacing
			let idealWidth = (usableWidth - totalSpacing) / CGFloat(columns)

			// Allow ±20% adjustment
			let minSize = baseSize * 0.8
			let maxSize = baseSize * 1.2

			// Try to fit one more column by shrinking
			let columnsWithShrink = columns + 1
			let shrinkSpacing = CGFloat(columnsWithShrink - 1) * spacing
			let shrinkWidth = (usableWidth - shrinkSpacing) / CGFloat(columnsWithShrink)

			if shrinkWidth >= minSize {
				// Can fit extra column
				itemWidth = shrinkWidth
				columns = columnsWithShrink
			} else if idealWidth <= maxSize {
				// Expand to fill space
				itemWidth = idealWidth
			}

			// Update dynamic adjustment for UI feedback
			dynamicAdjustment = ((itemWidth - baseSize) / baseSize) * 100
		}

		let height = showInfoBar ? itemWidth + thumbnailSize.infoBarHeight : itemWidth
		return (CGSize(width: itemWidth, height: height), columns)
	}
}
//
//  DeviceSizeHelper.swift
//  Photolala
//
//  Created by Assistant on 2025-07-02.
//

import SwiftUI

enum DeviceCategory {
	case compact    // < 380pt (small phones)
	case medium     // 380-430pt (regular phones)
	case expanded   // > 430pt (large phones, tablets)
	
	static func current(for screenWidth: CGFloat) -> DeviceCategory {
		switch screenWidth {
		case ..<380:
			return .compact
		case 380..<430:
			return .medium
		default:
			return .expanded
		}
	}
}

struct DeviceSizeHelper {
	static func getRecommendedThumbnailSizes(for category: DeviceCategory) -> [(size: CGFloat, label: String)] {
		switch category {
		case .compact:
			return [
				(64, "Small"),
				(80, "Medium"),
				(100, "Large")
			]
		case .medium:
			return [
				(80, "Small"),
				(100, "Medium"),
				(128, "Large")
			]
		case .expanded:
			return [
				(100, "Small"),
				(128, "Medium"),
				(160, "Large")
			]
		}
	}
	
	static func calculateOptimalColumns(screenWidth: CGFloat, thumbnailSize: CGFloat, spacing: CGFloat = 4) -> Int {
		let availableWidth = screenWidth - spacing * 2
		let itemWidthWithSpacing = thumbnailSize + spacing
		let columns = Int(availableWidth / itemWidthWithSpacing)
		
		// Ensure reasonable column range based on device
		let category = DeviceCategory.current(for: screenWidth)
		let range: ClosedRange<Int>
		switch category {
		case .compact:
			range = 3...5
		case .medium:
			range = 3...6
		case .expanded:
			range = 4...8
		}
		
		return min(max(columns, range.lowerBound), range.upperBound)
	}
}
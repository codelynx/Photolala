//
//  PhotoGroupingOption.swift
//  Photolala
//
//  Created by Assistant on 2025/06/15.
//

import Foundation

enum PhotoGroupingOption: String, CaseIterable {
	case none = "None"
	case year = "Year"
	case month = "Month"
	case day = "Day"

	var systemImage: String {
		switch self {
		case .none: "square.grid.3x3"
		case .year: "calendar"
		case .month: "calendar.badge.clock"
		case .day: "calendar.circle"
		}
	}

	var dateFormat: String? {
		switch self {
		case .none: nil
		case .year: "yyyy"
		case .month: "MMMM yyyy"
		case .day: "MMMM d, yyyy"
		}
	}
}

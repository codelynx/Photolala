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
		case .none: return "square.grid.3x3"
		case .year: return "calendar"
		case .month: return "calendar.badge.clock"
		case .day: return "calendar.circle"
		}
	}
	
	var dateFormat: String? {
		switch self {
		case .none: return nil
		case .year: return "yyyy"
		case .month: return "MMMM yyyy"
		case .day: return "MMMM d, yyyy"
		}
	}
}
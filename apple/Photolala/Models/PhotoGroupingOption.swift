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
	case yearMonth = "Year/Month"

	var systemImage: String {
		switch self {
		case .none: "square.grid.3x3"
		case .year: "calendar"
		case .yearMonth: "calendar.badge.clock"
		}
	}

	var dateFormat: String? {
		switch self {
		case .none: nil
		case .year: "yyyy"
		case .yearMonth: "MMMM yyyy"
		}
	}
	
	var description: String {
		switch self {
		case .none: "None"
		case .year: "Year"
		case .yearMonth: "Year/Month"
		}
	}
}

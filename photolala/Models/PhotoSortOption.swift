//
//  PhotoSortOption.swift
//  Photolala
//
//  Created by Assistant on 2025/06/14.
//

import Foundation

enum PhotoSortOption: String, CaseIterable {
	case filename = "Name"
	case dateAscending = "Date (Oldest First)"
	case dateDescending = "Date (Newest First)"
	
	var systemImage: String {
		switch self {
		case .filename: return "textformat"
		case .dateAscending: return "calendar"
		case .dateDescending: return "calendar"
		}
	}
	
	// Helper to get sort direction arrow
	var directionIndicator: String {
		switch self {
		case .filename: return ""
		case .dateAscending: return "↑"
		case .dateDescending: return "↓"
		}
	}
	
	// Sort comparator for PhotoReference - using file dates only
	func comparator(for photo1: PhotoReference, photo2: PhotoReference) -> Bool {
		switch self {
		case .filename:
			return photo1.filename.localizedStandardCompare(photo2.filename) == .orderedAscending
		case .dateAscending:
			let date1 = photo1.fileCreationDate ?? Date.distantPast
			let date2 = photo2.fileCreationDate ?? Date.distantPast
			return date1 < date2
		case .dateDescending:
			let date1 = photo1.fileCreationDate ?? Date.distantPast
			let date2 = photo2.fileCreationDate ?? Date.distantPast
			return date1 > date2
		}
	}
	
	// Sort an array of photos
	func sort(_ photos: [PhotoReference]) -> [PhotoReference] {
		return photos.sorted { comparator(for: $0, photo2: $1) }
	}
}
//
//  PhotoBookmark.swift
//  Photolala
//
//  Created by Photolala on 2025/06/24.
//

import Foundation

/// Represents a bookmark (emoji) associated with a photo
struct PhotoBookmark: Equatable, Codable {
	/// Photo content hash (MD5)
	let md5: String
	
	/// Single emoji character
	var emoji: String
	
	/// Optional note for future use
	var note: String?
	
	/// Last modification date for sync conflict resolution
	let modifiedDate: Date
	
	/// Create a new bookmark
	init(md5: String, emoji: String, note: String? = nil, modifiedDate: Date = Date()) {
		self.md5 = md5
		self.emoji = emoji
		self.note = note
		self.modifiedDate = modifiedDate
	}
	
	/// Create from CSV row
	init?(csvRow: String) {
		let components = csvRow.split(separator: ",").map { String($0) }
		guard components.count >= 4 else { return nil }
		
		self.md5 = components[0]
		self.emoji = components[1]
		
		// Handle empty note field
		let noteField = components[2]
		self.note = noteField.isEmpty ? nil : noteField
		
		// Parse Unix timestamp
		guard let timestamp = Double(components[3]) else { return nil }
		self.modifiedDate = Date(timeIntervalSince1970: timestamp)
	}
	
}
//
//  PhotoTag.swift
//  Photolala
//
//  Created by Photolala on 2025/06/24.
//

import Foundation

/// Represents color flags associated with a photo
struct PhotoTag: Equatable, Codable, Identifiable {
	/// Photo identifier (e.g., "md5#abc123" or "apl#xyz789")
	let photoIdentifier: String
	
	/// Set of color flags
	var flags: Set<ColorFlag>
	
	/// Computed property for Identifiable
	var id: String { photoIdentifier }
	
	/// Create a new tag
	init(photoIdentifier: String, flags: Set<ColorFlag> = []) {
		self.photoIdentifier = photoIdentifier
		self.flags = flags
	}
	
	/// Check if tag has any flags
	var isEmpty: Bool {
		flags.isEmpty
	}
	
	/// Get sorted array of flags for display
	var sortedFlags: [ColorFlag] {
		Array(flags).sorted
	}
}
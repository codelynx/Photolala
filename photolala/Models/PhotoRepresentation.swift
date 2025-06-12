//
//  PhotoRepresentation.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Foundation

struct PhotoRepresentation: Identifiable, Hashable {
	var id: String { filePath }
	let directoryPath: NSString
	let filename: String
	
	// Computed property for file URL
	var fileURL: URL {
		URL(fileURLWithPath: directoryPath.appendingPathComponent(filename))
	}
	
	var filePath: String {
		directoryPath.appendingPathComponent(filename)
	}
	
	init(directoryPath: NSString, filename: String) {
		self.directoryPath = directoryPath
		self.filename = filename
	}
	
	// Hashable
	func hash(into hasher: inout Hasher) {
		hasher.combine(self.directoryPath)
		hasher.combine(self.filename)
	}
	
	// Equatable
	static func == (lhs: PhotoRepresentation, rhs: PhotoRepresentation) -> Bool {
		lhs.directoryPath == rhs.directoryPath && lhs.filename == rhs.filename
	}
}

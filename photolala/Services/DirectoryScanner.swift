//
//  DirectoryScanner.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Foundation

class DirectoryScanner {
	static let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp", "gif", "webp"]
	
	static func scanDirectory(atPath path: NSString) -> [PhotoRepresentation] {
		var photos: [PhotoRepresentation] = []
		
		do {
			// Convert NSString path to URL
			let url = URL(fileURLWithPath: path as String)
			
			// Get directory contents
			let contents = try FileManager.default.contentsOfDirectory(
				at: url,
				includingPropertiesForKeys: [.isRegularFileKey],
				options: [.skipsHiddenFiles]
			)
			
			// Filter for image files
			for fileURL in contents {
				// Check if it's a regular file
				let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
				guard let isRegularFile = resourceValues.isRegularFile, isRegularFile else {
					continue
				}
				
				// Check if it's an image file
				let fileExtension = fileURL.pathExtension.lowercased()
				if imageExtensions.contains(fileExtension) {
					let filename = fileURL.lastPathComponent
					let photo = PhotoRepresentation(directoryPath: path, filename: filename)
					photos.append(photo)
					
					// Print for debugging
					print("Found photo: \(photo.filename) at \(photo.filePath)")
				}
			}
			
			print("Total photos found: \(photos.count)")
			
		} catch {
			print("Error scanning directory: \(error)")
		}
		
		return photos
	}

}

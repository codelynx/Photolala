//
//  DirectoryScanner.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Foundation

class DirectoryScanner {
	static let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp", "gif", "webp"]

	static func scanDirectory(atPath path: NSString) -> [PhotoReference] {
		var photos: [PhotoReference] = []

		print("[DirectoryScanner] Starting scan of directory: \(path)")
		let startTime = Date()

		do {
			// Convert NSString path to URL
			let url = URL(fileURLWithPath: path as String)

			// Get directory contents
			print("[DirectoryScanner] Getting directory contents...")
			let contents = try FileManager.default.contentsOfDirectory(
				at: url,
				includingPropertiesForKeys: [.isRegularFileKey],
				options: [.skipsHiddenFiles]
			)

			print("[DirectoryScanner] Found \(contents.count) items in directory")

			// Filter for image files
			var processedCount = 0
			for fileURL in contents {
				processedCount += 1

				// Log progress every 100 files
				if processedCount % 100 == 0 {
					print("[DirectoryScanner] Processed \(processedCount)/\(contents.count) files...")
				}

				// Check if it's a regular file
				let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
				guard let isRegularFile = resourceValues.isRegularFile, isRegularFile else {
					continue
				}

				// Check if it's an image file
				let fileExtension = fileURL.pathExtension.lowercased()

				if self.imageExtensions.contains(fileExtension) {
					let filename = fileURL.lastPathComponent
					let photo = PhotoReference(directoryPath: path, filename: filename)
					photos.append(photo)
				}
			}

			let elapsed = Date().timeIntervalSince(startTime)
			print(
				"[DirectoryScanner] Scan completed: found \(photos.count) photos in \(String(format: "%.3f", elapsed))s"
			)

		} catch {
			print("[DirectoryScanner] Error scanning directory: \(error.localizedDescription)")
		}

		return photos
	}

}

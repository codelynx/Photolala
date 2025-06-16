//
//  ResourceHelper.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Foundation

enum ResourceHelper {
	/// Get the Photos resource directory URL
	/// Note: This requires the Photos folder to be added as a "Folder Reference" (blue folder) in Xcode
	static var photosResourceURL: URL? {
		Bundle.main.url(forResource: "Samples", withExtension: nil)
	}

	/// Get the Photos resource directory URL (alternative method)
	static var photosResourceURLAlt: URL? {
		Bundle.main.resourceURL?.appendingPathComponent("Samples")
	}

	/// List all photo files in the Photos resource directory
	static func listResourcePhotos() -> [URL] {
		guard let photosURL = photosResourceURL else {
			print("Photos resource directory not found")
			return []
		}

		do {
			let contents = try FileManager.default.contentsOfDirectory(
				at: photosURL,
				includingPropertiesForKeys: [.isRegularFileKey],
				options: [.skipsHiddenFiles]
			)
			return contents.filter { url in
				// Filter for image files
				let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp"]
				return imageExtensions.contains(url.pathExtension.lowercased())
			}
		} catch {
			print("Error listing resource photos: \(error)")
			return []
		}
	}

	/// Check if Photos exists as a folder reference
	static func checkPhotosResource() {
		if let url = photosResourceURL {
			print("✅ Photos folder found at: \(url.path)")

			// Check if it's a directory
			var isDirectory: ObjCBool = false
			if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
				if isDirectory.boolValue {
					print("✅ Photos is a directory (folder reference)")
				} else {
					print("❌ Photos exists but is not a directory")
				}
			}

			// List contents
			let photos = self.listResourcePhotos()
			print("Found \(photos.count) photos:")
			photos.forEach { print("  - \($0.lastPathComponent)") }
		} else {
			print("❌ Photos resource not found - may need to add as folder reference")

			// Check if files exist as flat resources
			let testFile = "IMG_0023.HEIC"
			if let flatURL = Bundle.main.url(forResource: "IMG_0023", withExtension: "HEIC") {
				print("⚠️  Found \(testFile) as flat resource at: \(flatURL.path)")
				print("   Photos were added as individual files, not as folder reference")
			}
		}
	}
}

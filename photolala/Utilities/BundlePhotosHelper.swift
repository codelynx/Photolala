//
//  BundlePhotosHelper.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Foundation

struct BundlePhotosHelper {
	/// Get all photo resources from the main bundle
	static func getAllBundlePhotos() -> [URL] {
		let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp"]
		var photoURLs: [URL] = []
		
		// First check if we have a Photos folder reference
		if let photosURL = Bundle.main.url(forResource: "Photos", withExtension: nil) {
			do {
				let contents = try FileManager.default.contentsOfDirectory(
					at: photosURL,
					includingPropertiesForKeys: nil,
					options: [.skipsHiddenFiles]
				)
				
				photoURLs = contents.filter { url in
					imageExtensions.contains(url.pathExtension.lowercased())
				}
				
				print("Found \(photoURLs.count) photos in Photos folder")
				return photoURLs
			} catch {
				print("Error reading Photos folder: \(error)")
			}
		}
		
		// Fallback: Get all resources from bundle root
		guard let resourcePath = Bundle.main.resourcePath else { return [] }
		let resourceURL = URL(fileURLWithPath: resourcePath)
		
		do {
			let allFiles = try FileManager.default.contentsOfDirectory(
				at: resourceURL,
				includingPropertiesForKeys: nil,
				options: [.skipsHiddenFiles]
			)
			
			// Filter for image files
			photoURLs = allFiles.filter { url in
				imageExtensions.contains(url.pathExtension.lowercased())
			}
			
			print("Found \(photoURLs.count) photos in bundle root")
			
		} catch {
			print("Error scanning bundle resources: \(error)")
		}
		
		return photoURLs
	}
	
	/// Create a virtual "bundle photos" directory URL
	static var virtualBundlePhotosURL: URL {
		// Use a special URL scheme to indicate bundle photos
		URL(string: "bundle-photos://main")!
	}
	
	/// Check if a URL represents bundle photos
	static func isBundlePhotosURL(_ url: URL) -> Bool {
		url.scheme == "bundle-photos"
	}
}
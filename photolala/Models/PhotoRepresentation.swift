//
//  PhotoRepresentation.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Foundation
import Observation
import SwiftUI

@Observable
class PhotoRepresentation: Identifiable, Hashable {
	var id: String { filePath }
	let directoryPath: NSString
	let filename: String
	var thumbnail: XImage?
	var thumbnailLoadingState: LoadingState = .idle
	
	enum LoadingState {
		case idle
		case loading
		case loaded
		case failed(Error)
	}
	
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

	/*
	// Thumbnail loading
	func loadThumbnail() {
		guard thumbnailLoadingState == .idle else { return }
		
		thumbnailLoadingState = .loading
		
		Task {
			do {
				// First check if thumbnail exists in cache
				let data = try Data(contentsOf: fileURL)
				let md5 = PhotoManager.shared.computeMD5(data)
				let identifier = PhotoManager.Identifier.md5(md5, data.count)
				
				// Try to load from cache first
				if let cachedThumbnail = PhotoManager.shared.thumbnail(for: identifier) {
					await MainActor.run {
						self.thumbnail = cachedThumbnail
						self.thumbnailLoadingState = .loaded
					}
					return
				}
				
				// Generate thumbnail if not cached
				if let generatedThumbnail = try PhotoManager.shared.thumbnail(rawData: data) {
					await MainActor.run {
						self.thumbnail = generatedThumbnail
						self.thumbnailLoadingState = .loaded
					}
				}
			} catch {
				await MainActor.run {
					self.thumbnailLoadingState = .failed(error)
				}
			}
		}
	}
	*/
}

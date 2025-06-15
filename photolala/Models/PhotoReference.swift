//
//  PhotoReference.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Foundation
import Observation
import SwiftUI

@Observable
class PhotoReference: Identifiable, Hashable {
	var id: String { filePath }
	let directoryPath: NSString
	let filename: String
	var thumbnail: XImage?
	var thumbnailLoadingState: LoadingState = .idle
	var metadata: PhotoMetadata?
	var metadataLoadingState: LoadingState = .idle
	var fileCreationDate: Date?  // Quick access for initial sorting - closer to photo taken date
	
	enum LoadingState: Equatable {
		case idle
		case loading
		case loaded
		case failed(Error)
		
		static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
			switch (lhs, rhs) {
			case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
				return true
			case (.failed(_), .failed(_)):
				return true // Consider all failures equal for simplicity
			default:
				return false
			}
		}
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
		// Don't load file date in init - let it be loaded on demand
		// This prevents blocking during directory scanning
	}
	
	func loadFileCreationDateIfNeeded() {
		guard fileCreationDate == nil else { return }
		
		let startTime = Date()
		print("[PhotoReference] Loading file date for: \(filename)")
		
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
			// Use creation date as it's closer to when photo was taken
			self.fileCreationDate = attributes[.creationDate] as? Date
			
			let elapsed = Date().timeIntervalSince(startTime)
			if elapsed > 0.1 {
				print("[PhotoReference] Warning: Slow file attribute access for \(filename): \(String(format: "%.3f", elapsed))s")
			}
		} catch {
			// Silently fail, will use current date as fallback
			print("[PhotoReference] Failed to get file date for \(filename): \(error)")
		}
	}
	
	// Hashable
	func hash(into hasher: inout Hasher) {
		hasher.combine(self.directoryPath)
		hasher.combine(self.filename)
	}
	
	// Equatable
	static func == (lhs: PhotoReference, rhs: PhotoReference) -> Bool {
		lhs.directoryPath == rhs.directoryPath && lhs.filename == rhs.filename
	}
	
	// Metadata loading
	func loadMetadata() async throws -> PhotoMetadata? {
		guard metadata == nil else { return metadata }
		metadataLoadingState = .loading
		
		do {
			metadata = try await PhotoManager.shared.metadata(for: self)
			metadataLoadingState = .loaded
			return metadata
		} catch {
			metadataLoadingState = .failed(error)
			throw error
		}
	}
	
	// Combined loading for efficiency
	func loadPhotoData() async throws {
		// Skip if already loading or loaded
		guard thumbnailLoadingState != .loading && metadataLoadingState != .loading else { return }
		
		// Skip if both already loaded
		if thumbnail != nil && metadata != nil { return }
		
		thumbnailLoadingState = .loading
		metadataLoadingState = .loading
		
		do {
			let (loadedThumbnail, loadedMetadata) = try await PhotoManager.shared.loadPhotoData(for: self)
			
			if let loadedThumbnail = loadedThumbnail {
				self.thumbnail = loadedThumbnail
				self.thumbnailLoadingState = .loaded
			}
			
			if let loadedMetadata = loadedMetadata {
				self.metadata = loadedMetadata
				self.metadataLoadingState = .loaded
			}
		} catch {
			thumbnailLoadingState = .failed(error)
			metadataLoadingState = .failed(error)
			throw error
		}
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

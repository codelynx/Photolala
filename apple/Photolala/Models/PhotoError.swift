//
//  PhotoError.swift
//  Photolala
//
//  Created by Claude on 2025/07/29.
//

import Foundation

/// Errors that can occur when processing photos
enum PhotoError: LocalizedError {
	case emptyFile(filename: String)
	case corruptedFile(filename: String)
	case unreadableFile(filename: String)
	case processingFailed(filename: String, underlyingError: Error)
	
	var errorDescription: String? {
		switch self {
		case .emptyFile(let filename):
			return "The file '\(filename)' is empty (0 bytes)"
		case .corruptedFile(let filename):
			return "The file '\(filename)' appears to be corrupted"
		case .unreadableFile(let filename):
			return "Unable to read the file '\(filename)'"
		case .processingFailed(let filename, let error):
			return "Failed to process '\(filename)': \(error.localizedDescription)"
		}
	}
	
	var recoverySuggestion: String? {
		switch self {
		case .emptyFile, .corruptedFile:
			return "This file may need to be removed or restored from a backup"
		case .unreadableFile:
			return "Check file permissions and ensure the file exists"
		case .processingFailed:
			return "Try reloading or check if the file format is supported"
		}
	}
	
	var isCorrupted: Bool {
		switch self {
		case .emptyFile, .corruptedFile:
			return true
		default:
			return false
		}
	}
}

/// Represents a corrupted photo file that needs user attention
struct CorruptedPhotoInfo: Identifiable, Hashable {
	let id = UUID()
	let photo: PhotoFile
	let error: PhotoError
	let detectedAt: Date = Date()
	
	static func == (lhs: CorruptedPhotoInfo, rhs: CorruptedPhotoInfo) -> Bool {
		lhs.id == rhs.id
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
}

/// Manager for handling corrupted photos
@MainActor
class CorruptedPhotoManager: ObservableObject {
	static let shared = CorruptedPhotoManager()
	
	@Published var corruptedPhotos: [CorruptedPhotoInfo] = []
	@Published var showCorruptedPhotosAlert = false
	
	private init() {}
	
	func addCorruptedPhoto(_ photo: PhotoFile, error: PhotoError) {
		// Check if already tracked
		guard !corruptedPhotos.contains(where: { $0.photo.filePath == photo.filePath }) else { return }
		
		corruptedPhotos.append(CorruptedPhotoInfo(photo: photo, error: error))
		
		// Show alert if this is the first corrupted photo
		if corruptedPhotos.count == 1 {
			showCorruptedPhotosAlert = true
		}
	}
	
	func removeCorruptedPhoto(_ info: CorruptedPhotoInfo) {
		corruptedPhotos.removeAll { $0.id == info.id }
	}
	
	func clearAll() {
		corruptedPhotos.removeAll()
	}
}
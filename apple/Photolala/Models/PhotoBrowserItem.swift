//
//  PhotoBrowserItem.swift
//  Photolala
//
//  Simplified photo item for browser view with opaque identifiers
//

import Foundation

// MARK: - Photo Browser Item

/// Minimal photo representation for browser view
/// Uses opaque identifiers that only the source understands
struct PhotoBrowserItem: Identifiable, Hashable, Sendable {
	/// Opaque identifier that the source understands
	let id: String

	/// Display name for UI (e.g., filename)
	let displayName: String
}

// MARK: - Photo Browser Metadata

/// Metadata loaded lazily through photo source
struct PhotoBrowserMetadata: Sendable {
	let fileSize: Int64?
	let creationDate: Date?
	let modificationDate: Date?
	let width: Int?
	let height: Int?
	let mimeType: String?

	/// Human-readable file size
	var formattedFileSize: String? {
		guard let fileSize = fileSize else { return nil }
		return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
	}

	/// Aspect ratio for layout calculations
	var aspectRatio: Double? {
		guard let width = width, let height = height, height > 0 else { return nil }
		return Double(width) / Double(height)
	}
}

// MARK: - Photo Source Error

enum PhotoSourceError: LocalizedError {
	case itemNotFound
	case notAuthorized
	case loadFailed(Error)
	case invalidData
	case sourceUnavailable

	var errorDescription: String? {
		switch self {
		case .itemNotFound:
			return "Photo item not found"
		case .notAuthorized:
			return "Not authorized to access photos"
		case .loadFailed(let error):
			return "Failed to load photo: \(error.localizedDescription)"
		case .invalidData:
			return "Invalid photo data"
		case .sourceUnavailable:
			return "Photo source is unavailable"
		}
	}
}
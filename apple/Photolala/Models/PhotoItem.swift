//
//  PhotoItem.swift
//  Photolala
//
//  Protocol for representing photos from various sources (local, Apple Photos, etc.)
//

import Foundation
import CryptoKit

// MARK: - PhotoItem Protocol

/// Protocol for any photo item that can be uploaded to S3
protocol PhotoItem: Sendable {
	/// Unique identifier for the photo item
	nonisolated var id: String { get }

	/// Display name for UI
	nonisolated var displayName: String { get }

	/// Image format if known
	nonisolated var format: ImageFormat? { get }

	/// Load full photo data
	func loadFullData() async throws -> Data

	/// Load thumbnail data (PTM-256 format)
	func loadThumbnail() async throws -> Data

	/// Compute full MD5 hash
	func computeMD5() async throws -> String
}

// MARK: - Local Photo Implementation

/// Photo item from local file system
struct LocalPhotoItem: PhotoItem {
	let photoEntry: PhotoEntry
	let url: URL
	let id: String
	let displayName: String
	let format: ImageFormat?

	init(photoEntry: PhotoEntry, url: URL) {
		self.photoEntry = photoEntry
		self.url = url
		self.id = photoEntry.id.fastKey.stringValue
		self.displayName = photoEntry.fileName
		self.format = photoEntry.id.fastKey.detectedFormat
	}

	func loadFullData() async throws -> Data {
		try Data(contentsOf: url)
	}

	func loadThumbnail() async throws -> Data {
		// Compute MD5 if needed
		let md5String = try await computeMD5()
		let photoMD5 = PhotoMD5(md5String)

		// Get thumbnail URL from cache
		let thumbnailURL = try await ThumbnailCache.shared.getThumbnail(
			for: photoMD5,
			sourceURL: url
		)

		// Convert to Data for S3 upload
		return try Data(contentsOf: thumbnailURL)
	}

	func computeMD5() async throws -> String {
		// Return cached MD5 if available
		if let md5 = photoEntry.id.fullMD5?.value {
			return md5
		}

		// Compute MD5 from file
		let photoMD5 = try await PhotoMD5(contentsOf: url)
		return photoMD5.value
	}
}

// MARK: - Apple Photos Implementation

/// Photo item from Apple Photos library (future implementation)
struct ApplePhotoItem: PhotoItem {
	let assetID: String  // PHAsset identifier
	private var cachedMD5: String?
	private var cachedFormat: ImageFormat?

	nonisolated var id: String {
		assetID
	}

	nonisolated var displayName: String {
		// Will be implemented with PHAsset
		"Photo \(assetID.prefix(8))"
	}

	nonisolated var format: ImageFormat? {
		cachedFormat
	}

	func loadFullData() async throws -> Data {
		// TODO: Implement with Photos framework
		// This will request full resolution image from PHAsset
		// Also detect format at this point
		fatalError("Apple Photos support not yet implemented")
	}

	func loadThumbnail() async throws -> Data {
		// TODO: Request thumbnail from Photos framework
		// Convert to PTM-256 format if needed
		fatalError("Apple Photos support not yet implemented")
	}

	func computeMD5() async throws -> String {
		// Must load full data first for Apple Photos
		let data = try await loadFullData()
		let digest = Insecure.MD5.hash(data: data)
		let md5 = digest.map { String(format: "%02x", $0) }.joined()
		return md5
	}
}

// MARK: - Upload Result

/// Result of uploading a photo item
enum UploadResult: Sendable {
	case completed
	case failed(Error)
	case skipped  // Already exists in S3

	nonisolated var isSuccess: Bool {
		switch self {
		case .completed, .skipped:
			return true
		case .failed:
			return false
		}
	}

	var description: String {
		switch self {
		case .completed:
			return "Uploaded"
		case .failed(let error):
			return "Failed: \(error.localizedDescription)"
		case .skipped:
			return "Already exists"
		}
	}
}

// MARK: - Upload Error

enum PhotoUploadError: LocalizedError {
	case invalidData
	case md5ComputationFailed
	case thumbnailGenerationFailed
	case networkError(Error)

	var errorDescription: String? {
		switch self {
		case .invalidData:
			return "Invalid photo data"
		case .md5ComputationFailed:
			return "Failed to compute MD5 hash"
		case .thumbnailGenerationFailed:
			return "Failed to generate thumbnail"
		case .networkError(let error):
			return "Network error: \(error.localizedDescription)"
		}
	}
}
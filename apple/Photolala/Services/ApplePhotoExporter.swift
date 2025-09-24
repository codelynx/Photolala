//
//  ApplePhotoExporter.swift
//  Photolala
//
//  Exports PHAssets from Apple Photos Library to temporary files for processing
//

import Foundation
import Photos
import PhotosUI
import AVFoundation
import OSLog

/// Result of exporting a PHAsset
struct ExportedAsset {
	let assetIdentifier: String
	let temporaryURL: URL
	let fileSize: Int64
	let creationDate: Date?
	let originalFilename: String?
	let uti: String?

	/// Clean up the temporary file
	func cleanup() {
		try? FileManager.default.removeItem(at: temporaryURL)
	}
}

/// Exports PHAssets to temporary files for processing
@MainActor
class ApplePhotoExporter {
	private let logger = Logger(subsystem: "com.photolala", category: "ApplePhotoExporter")

	// Export options
	private let imageManager = PHImageManager.default()
	private let exportDirectory: URL

	// Active exports for cleanup
	private var activeExports: [String: URL] = [:]

	init() {
		// Create temporary directory for exports
		let tempDir = FileManager.default.temporaryDirectory
			.appendingPathComponent("PhotoExports", isDirectory: true)
			.appendingPathComponent(UUID().uuidString, isDirectory: true)

		try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		self.exportDirectory = tempDir

		logger.debug("Export directory: \(tempDir.path)")
	}

	deinit {
		// Clean up export directory synchronously
		// Remove all exported files
		for url in activeExports.values {
			try? FileManager.default.removeItem(at: url)
		}
		// Remove export directory
		try? FileManager.default.removeItem(at: exportDirectory)
	}

	// MARK: - Public API

	/// Export a PHAsset to a temporary file
	func exportAsset(_ assetIdentifier: String) async throws -> ExportedAsset {
		// Fetch the asset
		let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
		guard let asset = fetchResult.firstObject else {
			throw ExportError.assetNotFound(assetIdentifier)
		}

		return try await exportAsset(asset)
	}

	/// Export a PHAsset to a temporary file
	func exportAsset(_ asset: PHAsset) async throws -> ExportedAsset {
		logger.info("Exporting asset: \(asset.localIdentifier)")

		// Determine export filename
		let resources = PHAssetResource.assetResources(for: asset)
		let primaryResource = resources.first { $0.type == .photo } ?? resources.first
		let originalFilename = primaryResource?.originalFilename ?? "photo.jpg"
		let exportFilename = "\(UUID().uuidString)_\(originalFilename)"
		let exportURL = exportDirectory.appendingPathComponent(exportFilename)

		// Track for cleanup
		activeExports[asset.localIdentifier] = exportURL

		// Export based on media type
		switch asset.mediaType {
		case .image:
			try await exportImage(asset, to: exportURL, uti: primaryResource?.uniformTypeIdentifier)
		case .video:
			try await exportVideo(asset, to: exportURL)
		default:
			throw ExportError.unsupportedMediaType
		}

		// Get file size
		let attributes = try FileManager.default.attributesOfItem(atPath: exportURL.path)
		let fileSize = attributes[.size] as? Int64 ?? 0

		return ExportedAsset(
			assetIdentifier: asset.localIdentifier,
			temporaryURL: exportURL,
			fileSize: fileSize,
			creationDate: asset.creationDate,
			originalFilename: originalFilename,
			uti: primaryResource?.uniformTypeIdentifier
		)
	}

	/// Export multiple assets concurrently
	func exportAssets(_ assetIdentifiers: [String],
					  progress: ((Int, Int) -> Void)? = nil) async throws -> [ExportedAsset] {
		var results: [ExportedAsset] = []

		for (index, identifier) in assetIdentifiers.enumerated() {
			progress?(index, assetIdentifiers.count)

			do {
				let exported = try await exportAsset(identifier)
				results.append(exported)
			} catch {
				logger.error("Failed to export \(identifier): \(error)")
				// Continue with other exports
			}
		}

		progress?(assetIdentifiers.count, assetIdentifiers.count)
		return results
	}

	/// Clean up a specific export
	func cleanupExport(for assetIdentifier: String) {
		if let url = activeExports.removeValue(forKey: assetIdentifier) {
			try? FileManager.default.removeItem(at: url)
			logger.debug("Cleaned up export for \(assetIdentifier)")
		}
	}

	/// Clean up all exports
	func cleanup() {
		// Remove all exported files
		for url in activeExports.values {
			try? FileManager.default.removeItem(at: url)
		}
		activeExports.removeAll()

		// Remove export directory
		try? FileManager.default.removeItem(at: exportDirectory)
		logger.info("Cleaned up all exports")
	}

	// MARK: - Private Export Methods

	private func exportImage(_ asset: PHAsset, to url: URL, uti: String?) async throws {
		// Request options for highest quality
		let options = PHImageRequestOptions()
		options.version = .current
		options.deliveryMode = .highQualityFormat
		options.isNetworkAccessAllowed = true
		options.isSynchronous = false

		// Use PHAssetResourceManager for original file
		guard let resource = PHAssetResource.assetResources(for: asset)
			.first(where: { $0.type == .photo }) else {
			throw ExportError.noPhotoResource
		}

		return try await withCheckedThrowingContinuation { continuation in
			let requestOptions = PHAssetResourceRequestOptions()
			requestOptions.isNetworkAccessAllowed = true

			PHAssetResourceManager.default().writeData(
				for: resource,
				toFile: url,
				options: requestOptions
			) { error in
				if let error = error {
					continuation.resume(throwing: ExportError.exportFailed(error.localizedDescription))
				} else {
					continuation.resume()
				}
			}
		}
	}

	private func exportVideo(_ asset: PHAsset, to url: URL) async throws {
		// Request video export
		let options = PHVideoRequestOptions()
		options.version = .current
		options.deliveryMode = .highQualityFormat
		options.isNetworkAccessAllowed = true

		return try await withCheckedThrowingContinuation { continuation in
			imageManager.requestExportSession(
				forVideo: asset,
				options: options,
				exportPreset: AVAssetExportPresetPassthrough
			) { session, _ in
				guard let session = session else {
					continuation.resume(throwing: ExportError.exportSessionFailed)
					return
				}

				session.outputURL = url
				session.outputFileType = .mov

				Task {
					await session.export()

					switch session.status {
					case .completed:
						continuation.resume()
					case .failed, .cancelled:
						let errorDescription = (session as NSObject).value(forKey: "error") as? NSError
						continuation.resume(throwing:
							ExportError.exportFailed(errorDescription?.localizedDescription ?? "Unknown error"))
					default:
						continuation.resume(throwing: ExportError.exportFailed("Unexpected status"))
					}
				}
			}
		}
	}
}

// MARK: - Errors

enum ExportError: LocalizedError {
	case assetNotFound(String)
	case unsupportedMediaType
	case noPhotoResource
	case exportSessionFailed
	case exportFailed(String)

	var errorDescription: String? {
		switch self {
		case .assetNotFound(let id):
			return "Asset not found: \(id)"
		case .unsupportedMediaType:
			return "Unsupported media type"
		case .noPhotoResource:
			return "No photo resource found"
		case .exportSessionFailed:
			return "Failed to create export session"
		case .exportFailed(let message):
			return "Export failed: \(message)"
		}
	}
}

// MARK: - Checkpoint Support

extension ExportedAsset: Codable {
	/// Save export info for resume capability
	func saveCheckpoint(to url: URL) throws {
		let encoder = JSONEncoder()
		let data = try encoder.encode(self)
		try data.write(to: url)
	}

	/// Load export info from checkpoint
	static func loadCheckpoint(from url: URL) throws -> ExportedAsset {
		let data = try Data(contentsOf: url)
		let decoder = JSONDecoder()
		return try decoder.decode(ExportedAsset.self, from: data)
	}
}

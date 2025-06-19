//
//  PhotoItem.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/19.
//

import Foundation
import SwiftUI

/// Common protocol for both local and S3 photos
protocol PhotoItem: Identifiable, Hashable {
	var id: String { get }
	var filename: String { get }
	var displayName: String { get }
	
	// Size and dimensions
	var fileSize: Int64? { get }
	var width: Int? { get }
	var height: Int? { get }
	var aspectRatio: Double? { get }
	
	// Dates
	var creationDate: Date? { get }
	var modificationDate: Date? { get }
	
	// Archive status
	var isArchived: Bool { get }
	var archiveStatus: ArchiveStatus { get }
	
	// MD5 hash for deduplication
	var md5Hash: String? { get }
	
	// Thumbnail support
	func loadThumbnail() async throws -> XImage?
	
	// Full image data
	func loadImageData() async throws -> Data
	
	// Context menu items specific to photo type
	func contextMenuItems() -> [PhotoContextMenuItem]
}

/// Enum to represent different photo sources
enum PhotoSource {
	case file(PhotoFile)
	case s3(PhotoS3)
}

/// Context menu item abstraction
struct PhotoContextMenuItem {
	let title: String
	let systemImage: String
	let action: () async -> Void
}

// MARK: - PhotoFile conformance
extension PhotoFile: PhotoItem {
	var displayName: String { filename }
	
	var fileSize: Int64? {
		// Get from file system or metadata
		metadata?.fileSize
	}
	
	var width: Int? { metadata?.pixelWidth }
	var height: Int? { metadata?.pixelHeight }
	var aspectRatio: Double? {
		guard let w = width, let h = height, h > 0 else { return nil }
		return Double(w) / Double(h)
	}
	
	var creationDate: Date? { fileCreationDate }
	var modificationDate: Date? { metadata?.fileModificationDate }
	
	var isArchived: Bool { archiveInfo != nil }
	var archiveStatus: ArchiveStatus {
		// Default to standard if not archived
		archiveInfo?.storageClass ?? .standard
	}
	
	func loadThumbnail() async throws -> XImage? {
		// Load thumbnail through PhotoManager
		if thumbnail == nil {
			try await loadPhotoData()
		}
		return thumbnail
	}
	
	func loadImageData() async throws -> Data {
		// Load from file system
		try Data(contentsOf: fileURL)
	}
	
	func contextMenuItems() -> [PhotoContextMenuItem] {
		var items: [PhotoContextMenuItem] = []
		
		// Show in Finder
		items.append(PhotoContextMenuItem(
			title: "Show in Finder",
			systemImage: "folder",
			action: { [weak self] in
				guard let self = self else { return }
				#if os(macOS)
				NSWorkspace.shared.selectFile(self.filePath, inFileViewerRootedAtPath: "")
				#endif
			}
		))
		
		// Archive-related items
		if isArchived {
			items.append(PhotoContextMenuItem(
				title: "Retrieve from Archive",
				systemImage: "arrow.down.circle",
				action: { 
					// Trigger archive retrieval
				}
			))
		}
		
		return items
	}
}

// MARK: - PhotoS3 conformance
extension PhotoS3: PhotoItem {
	var displayName: String { filename }
	
	var fileSize: Int64? { size }
	
	var creationDate: Date? { photoDate }
	var modificationDate: Date? { modified }
	
	var archiveStatus: ArchiveStatus {
		// For S3 photos, determine status based on storage class
		// This should be populated from S3 metadata
		if isArchived {
			// Default to deep archive for archived photos
			return .deepArchive
		}
		return .standard
	}
	
	var md5Hash: String? { md5 }
	
	func loadThumbnail() async throws -> XImage? {
		// Load from S3 or cache
		return try await S3DownloadService.shared.downloadThumbnail(for: self)
	}
	
	func loadImageData() async throws -> Data {
		// Download from S3
		return try await S3DownloadService.shared.downloadPhoto(for: self)
	}
	
	func contextMenuItems() -> [PhotoContextMenuItem] {
		var items: [PhotoContextMenuItem] = []
		
		// Download
		items.append(PhotoContextMenuItem(
			title: "Download",
			systemImage: "arrow.down.to.line",
			action: {
				// Trigger download
			}
		))
		
		// Archive-related items
		if isArchived {
			items.append(PhotoContextMenuItem(
				title: "Restore from Archive",
				systemImage: "arrow.down.circle",
				action: {
					// Trigger restore from archive
				}
			))
		}
		
		// Copy S3 URL
		items.append(PhotoContextMenuItem(
			title: "Copy S3 Path",
			systemImage: "doc.on.doc",
			action: { [self] in
				#if os(macOS)
				NSPasteboard.general.clearContents()
				NSPasteboard.general.setString(photoKey, forType: .string)
				#endif
			}
		))
		
		return items
	}
}

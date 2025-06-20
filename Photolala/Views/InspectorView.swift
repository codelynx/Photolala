//
//  InspectorView.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/19.
//

import SwiftUI

struct InspectorView: View {
	let selection: [any PhotoItem]
	@Environment(\.horizontalSizeClass) var horizontalSizeClass
	@Environment(\.dismiss) var dismiss
	
	init(selection: [any PhotoItem]) {
		self.selection = selection
		print("[InspectorView] Init with \(selection.count) items")
	}
	
	var body: some View {
		Group {
			if selection.isEmpty {
				EmptySelectionView()
			} else if selection.count == 1 {
				SinglePhotoInspector(photo: selection[0])
			} else {
				MultiplePhotosInspector(photos: selection)
			}
		}
		#if os(macOS)
		.background(Color(NSColor.controlBackgroundColor))
		#else
		.background(Color(UIColor.systemBackground))
		#endif
		.frame(minWidth: 260, idealWidth: 300, maxWidth: 320)
	}
}

// MARK: - Empty Selection

struct EmptySelectionView: View {
	var body: some View {
		VStack(spacing: 20) {
			Spacer()
			
			Image(systemName: "photo.stack")
				.font(.system(size: 48))
				.foregroundColor(.secondary)
			
			Text("Select photos to view details")
				.font(.headline)
				.foregroundColor(.secondary)
			
			Spacer()
		}
		.padding()
	}
}

// MARK: - Single Photo Inspector

struct SinglePhotoInspector: View {
	let photo: any PhotoItem
	@State private var thumbnail: XImage?
	@State private var isLoadingMetadata = false
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				// Thumbnail Preview
				ThumbnailSection(photo: photo, thumbnail: $thumbnail)
				
				Divider()
				
				// Photo Information
				PhotoInfoSection(photo: photo)
				
				Divider()
				
				// Quick Actions
				QuickActionsSection(photo: photo)
				
				// Metadata (collapsible)
				MetadataSection(photo: photo)
				
				// Backup Status (if applicable)
				if photo is PhotoS3 {
					BackupStatusSection(photo: photo as! PhotoS3)
				}
			}
			.padding()
		}
		.task {
			await loadThumbnail()
		}
	}
	
	private func loadThumbnail() async {
		thumbnail = try? await photo.loadThumbnail()
	}
}

// MARK: - Multiple Photos Inspector

struct MultiplePhotosInspector: View {
	let photos: [any PhotoItem]
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				// Grid Preview
				GridPreviewSection(photos: photos)
				
				Divider()
				
				// Summary Information
				SummarySection(photos: photos)
				
				Divider()
				
				// Quick Actions
				BulkActionsSection(photos: photos)
			}
			.padding()
		}
	}
}

// MARK: - Sections

struct ThumbnailSection: View {
	let photo: any PhotoItem
	@Binding var thumbnail: XImage?
	
	var body: some View {
		VStack {
			if let thumbnail = thumbnail {
				Image(thumbnail)
					.resizable()
					.scaledToFit()
					.frame(maxHeight: 200)
					.cornerRadius(8)
			} else {
				RoundedRectangle(cornerRadius: 8)
					.fill(Color.secondary.opacity(0.1))
					.frame(height: 200)
					.overlay(
						ProgressView()
					)
			}
		}
		.frame(maxWidth: .infinity)
	}
}

struct PhotoInfoSection: View {
	let photo: any PhotoItem
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Information")
				.font(.headline)
			
			if let size = photo.fileSize {
				InfoRow(label: "Size", value: formatFileSize(size))
			}
			
			if let width = photo.width, let height = photo.height {
				InfoRow(label: "Dimensions", value: "\(width) × \(height)")
			}
			
			if let date = photo.creationDate ?? photo.modificationDate {
				InfoRow(label: "Date", value: date.formatted())
			}
		}
	}
}

struct QuickActionsSection: View {
	let photo: any PhotoItem
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Quick Actions")
				.font(.headline)
			
			if photo is PhotoFile {
				ActionButton(title: "Show in Finder", systemImage: "folder") {
					Task {
						await showInFinder(photo)
					}
				}
			}
			
			ActionButton(title: "Share", systemImage: "square.and.arrow.up") {
				// TODO: Implement share
			}
			
			// TODO: Add star functionality when implemented
			// if let file = photo as? PhotoFile {
			// 	ActionButton(
			// 		title: file.isStarred ? "Unstar" : "Star for Backup",
			// 		systemImage: file.isStarred ? "star.fill" : "star"
			// 	) {
			// 		Task { await toggleStar(file) }
			// 	}
			// }
		}
	}
}

struct MetadataSection: View {
	let photo: any PhotoItem
	@State private var isExpanded = false
	
	var body: some View {
		DisclosureGroup(isExpanded: $isExpanded) {
			VStack(alignment: .leading, spacing: 4) {
				// TODO: Load and display EXIF data
				Text("EXIF data will be shown here")
					.font(.caption)
					.foregroundColor(.secondary)
			}
			.padding(.top, 8)
		} label: {
			Text("Metadata")
				.font(.headline)
		}
	}
}

struct BackupStatusSection: View {
	let photo: PhotoS3
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Backup Status")
				.font(.headline)
			
			InfoRow(label: "Storage Class", value: photo.storageClass.displayName)
			InfoRow(label: "Archived", value: photo.isArchived ? "Yes" : "No")
			
			if photo.isArchived {
				// TODO: Add retrieval options
			}
		}
	}
}

// MARK: - Helper Views

struct InfoRow: View {
	let label: String
	let value: String
	
	var body: some View {
		HStack {
			Text(label)
				.foregroundColor(.secondary)
			Spacer()
			Text(value)
				.lineLimit(1)
				.truncationMode(.middle)
		}
		.font(.system(.body, design: .rounded))
	}
}

struct ActionButton: View {
	let title: String
	let systemImage: String
	let action: () async -> Void
	
	var body: some View {
		Button {
			Task {
				await action()
			}
		} label: {
			Label(title, systemImage: systemImage)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.buttonStyle(.plain)
		.padding(.vertical, 4)
	}
}

struct GridPreviewSection: View {
	let photos: [any PhotoItem]
	@State private var thumbnails: [String: XImage] = [:]
	
	var body: some View {
		VStack {
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
				ForEach(photos.prefix(4), id: \.id) { photo in
					if let thumbnail = thumbnails[photo.id] {
						Image(thumbnail)
							.resizable()
							.scaledToFill()
							.frame(width: 60, height: 60)
							.clipped()
							.cornerRadius(4)
					} else {
						RoundedRectangle(cornerRadius: 4)
							.fill(Color.secondary.opacity(0.1))
							.frame(width: 60, height: 60)
							.task {
								await loadThumbnail(for: photo)
							}
					}
				}
			}
			
			if photos.count > 4 {
				Text("+\(photos.count - 4) more")
					.font(.caption)
					.foregroundColor(.secondary)
			}
		}
		.frame(maxWidth: .infinity)
	}
	
	private func loadThumbnail(for photo: any PhotoItem) async {
		if let thumbnail = try? await photo.loadThumbnail() {
			await MainActor.run {
				thumbnails[photo.id] = thumbnail
			}
		}
	}
}

struct SummarySection: View {
	let photos: [any PhotoItem]
	
	var totalSize: Int64 {
		photos.compactMap { $0.fileSize }.reduce(0, +)
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Summary")
				.font(.headline)
			
			InfoRow(label: "Photos", value: "\(photos.count)")
			InfoRow(label: "Total Size", value: formatFileSize(totalSize))
		}
	}
}

struct BulkActionsSection: View {
	let photos: [any PhotoItem]
	
	var localPhotos: [PhotoFile] {
		photos.compactMap { $0 as? PhotoFile }
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Actions")
				.font(.headline)
			
			if !localPhotos.isEmpty {
				ActionButton(title: "Show All in Finder", systemImage: "folder") {
					// TODO: Implement
				}
				
				// TODO: Add star functionality when implemented
				// let allStarred = localPhotos.allSatisfy { $0.isStarred }
				// ActionButton(
				// 	title: allStarred ? "Unstar All" : "Star All for Backup",
				// 	systemImage: allStarred ? "star.fill" : "star"
				// ) {
				// 	// TODO: Implement bulk star
				// }
			}
		}
	}
}

// MARK: - Helper Functions

private func formatFileSize(_ bytes: Int64) -> String {
	let formatter = ByteCountFormatter()
	formatter.countStyle = .file
	return formatter.string(fromByteCount: bytes)
}

private func showInFinder(_ photo: any PhotoItem) async {
	#if os(macOS)
	if let file = photo as? PhotoFile {
		await MainActor.run {
			_ = NSWorkspace.shared.selectFile(file.filePath, inFileViewerRootedAtPath: "")
		}
	}
	#endif
}

// TODO: Implement star functionality when available
// private func toggleStar(_ file: PhotoFile) async {
// 	// TODO: Implement star toggle
// }

// MARK: - Preview

struct InspectorView_Previews: PreviewProvider {
	static var previews: some View {
		InspectorView(selection: [])
			.frame(width: 300)
	}
}
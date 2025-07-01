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

				// Tag Section
				TagSection(photo: photo)

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
		.onChange(of: photo.id) {
			Task {
				await loadThumbnail()
			}
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
	@State private var fileSize: Int64?
	@State private var isLoadingFileSize = false

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Information")
				.font(.headline)

			// For PhotoApple, use async loaded file size; for others use cached value
			if let applePhoto = photo as? PhotoApple {
				if let size = fileSize {
					InfoRow(label: "Size", value: formatFileSize(size))
				} else if isLoadingFileSize {
					HStack {
						Text("Size")
							.foregroundColor(.secondary)
						Spacer()
						ProgressView()
							.scaleEffect(0.7)
					}
					.font(.system(.body, design: .rounded))
				}
			} else if let size = photo.fileSize {
				InfoRow(label: "Size", value: formatFileSize(size))
			}

			if let width = photo.width, let height = photo.height {
				InfoRow(label: "Dimensions", value: "\(width) × \(height)")
			}

			if let date = photo.creationDate ?? photo.modificationDate {
				InfoRow(label: "Date", value: date.formatted())
			}
		}
		.task {
			await loadFileSizeIfNeeded()
		}
		.onChange(of: photo.id) {
			Task {
				await loadFileSizeIfNeeded()
			}
		}
	}

	private func loadFileSizeIfNeeded() async {
		guard let applePhoto = photo as? PhotoApple else { return }
		
		isLoadingFileSize = true
		do {
			let size = try await applePhoto.loadFileSize()
			await MainActor.run {
				self.fileSize = size
				self.isLoadingFileSize = false
			}
		} catch {
			print("[PhotoInfoSection] Failed to load file size: \(error)")
			await MainActor.run {
				self.isLoadingFileSize = false
			}
		}
	}
}

struct QuickActionsSection: View {
	let photo: any PhotoItem
	@State private var applePhotoMD5: String?
	@State private var isLoadingMD5 = false

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Quick Actions")
				.font(.headline)

			// Star toggle for PhotoFile
			if let photoFile = photo as? PhotoFile,
			   !photoFile.isArchived {
				let backupStatus = photoFile.md5Hash != nil ?
					BackupQueueManager.shared.backupStatus[photoFile.md5Hash!] : nil
				let isStarred = backupStatus == .queued || backupStatus == .uploaded
				let isFailed = backupStatus == .failed

				if isFailed {
					// Show error state with retry option
					ActionButton(
						title: "Retry Backup",
						systemImage: "exclamationmark.circle.fill"
					) {
						Task { @MainActor in
							print("[InspectorView] Retry backup for: \(photoFile.filename)")
							BackupQueueManager.shared.addToQueue(photoFile)
						}
					}
					.foregroundColor(.red)
				} else {
					ActionButton(
						title: isStarred ? "Unstar" : "Star",
						systemImage: isStarred ? "star.fill" : "star"
					) {
						Task { @MainActor in
							print("[InspectorView] Star toggle clicked for: \(photoFile.filename)")
							print("[InspectorView] Current starred state: \(isStarred)")
							print("[InspectorView] Current backup status: \(String(describing: backupStatus))")
							print("[InspectorView] MD5 hash: \(photoFile.md5Hash ?? "nil")")
							BackupQueueManager.shared.toggleStar(for: photoFile)
							print("[InspectorView] Toggle completed")
						}
					}
				}
			}
			
			// Star toggle for Apple Photos
			if let applePhoto = photo as? PhotoApple {
				let backupStatus = applePhotoMD5 != nil ?
					BackupQueueManager.shared.backupStatus[applePhotoMD5!] : nil
				let isStarred = backupStatus == .queued || backupStatus == .uploaded
				let isFailed = backupStatus == .failed
				
				if isLoadingMD5 {
					HStack {
						Text("Computing...")
							.foregroundColor(.secondary)
						Spacer()
						ProgressView()
							.scaleEffect(0.7)
					}
					.padding(.horizontal, 8)
					.padding(.vertical, 4)
				} else if isFailed {
					// Show error state with retry option
					ActionButton(
						title: "Retry Backup",
						systemImage: "exclamationmark.circle.fill"
					) {
						Task { @MainActor in
							print("[InspectorView] Retry backup for Apple Photo: \(applePhoto.filename)")
							// We need to create a wrapper to add to queue
							await addApplePhotoToBackupQueue(applePhoto)
						}
					}
					.foregroundColor(.red)
				} else {
					ActionButton(
						title: isStarred ? "Unstar" : "Star",
						systemImage: isStarred ? "star.fill" : "star"
					) {
						Task { @MainActor in
							print("[InspectorView] Star toggle clicked for Apple Photo: \(applePhoto.filename)")
							print("[InspectorView] Current starred state: \(isStarred)")
							print("[InspectorView] Current backup status: \(String(describing: backupStatus))")
							print("[InspectorView] MD5 hash: \(applePhotoMD5 ?? "nil")")
							
							if isStarred {
								// Remove from queue
								if let md5 = applePhotoMD5 {
									BackupQueueManager.shared.removeFromQueueByHash(md5)
								}
							} else {
								// Add to queue - compute MD5 if needed
								await addApplePhotoToBackupQueue(applePhoto)
							}
							print("[InspectorView] Toggle completed")
						}
					}
				}
			}

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
		}
		.task {
			await loadApplePhotoMD5IfNeeded()
		}
		.onChange(of: photo.id) {
			// Reset state when photo changes
			applePhotoMD5 = nil
			isLoadingMD5 = false
			Task {
				await loadApplePhotoMD5IfNeeded()
			}
		}
	}
	
	private func loadApplePhotoMD5IfNeeded() async {
		guard let applePhoto = photo as? PhotoApple else {
			applePhotoMD5 = nil
			return
		}
		
		// Check if already in catalog
		let catalogService = PhotolalaCatalogServiceV2.shared
		if let entry = try? await catalogService.findByApplePhotoID(applePhoto.id) {
			await MainActor.run {
				self.applePhotoMD5 = entry.md5
			}
			return
		}
		
		// If user has starred/unstarred, we need to compute MD5
		// This will be done when they actually click the star button
	}
	
	private func addApplePhotoToBackupQueue(_ applePhoto: PhotoApple) async {
		isLoadingMD5 = true
		defer { isLoadingMD5 = false }
		
		do {
			// Compute MD5 if not already cached
			let md5: String
			if let cachedMD5 = applePhotoMD5 {
				md5 = cachedMD5
			} else {
				md5 = try await applePhoto.computeMD5Hash()
				applePhotoMD5 = md5
			}
			
			// Add to backup queue with photo ID and MD5 hash
			print("[InspectorView] Computed MD5 for Apple Photo: \(md5)")
			BackupQueueManager.shared.addApplePhotoToQueue(applePhoto.id, md5: md5)
		} catch {
			print("[InspectorView] Failed to compute MD5: \(error)")
		}
	}
}

struct MetadataSection: View {
	let photo: any PhotoItem
	@State private var isExpanded = false
	@State private var metadata: PhotoMetadata?
	@State private var extendedMetadata: ExtendedPhotoMetadata?
	@State private var isLoading = false

	var body: some View {
		DisclosureGroup(isExpanded: $isExpanded) {
			if isLoading {
				HStack {
					ProgressView()
						.scaleEffect(0.8)
					Text("Loading metadata...")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(.top, 8)
			} else if let metadata = metadata {
				VStack(alignment: .leading, spacing: 6) {
					// Camera info
					if let cameraInfo = metadata.cameraInfo {
						InfoRow(label: "Camera", value: cameraInfo)
					}
					
					// Date taken
					if let dateTaken = metadata.dateTaken {
						InfoRow(label: "Date Taken", value: dateTaken.formatted(date: .abbreviated, time: .shortened))
					}
					
					// GPS Location
					if let lat = metadata.gpsLatitude, let lon = metadata.gpsLongitude {
						InfoRow(label: "Location", value: String(format: "%.4f, %.4f", lat, lon))
					}
					
					// Extended EXIF data if available
					if let extended = extendedMetadata {
						Group {
							if let aperture = extended.apertureDisplay {
								InfoRow(label: "Aperture", value: aperture)
							}
							if let shutter = extended.exposureDisplay {
								InfoRow(label: "Shutter Speed", value: shutter)
							}
							if let iso = extended.isoDisplay {
								InfoRow(label: "ISO", value: iso)
							}
							if let focal = extended.focalLengthDisplay {
								InfoRow(label: "Focal Length", value: focal)
							}
						}
					}
					
					// Orientation
					if let orientation = metadata.orientation, orientation != 1 {
						InfoRow(label: "Orientation", value: "Rotated (\(orientation))")
					}
				}
				.padding(.top, 8)
			} else {
				Text("No metadata available")
					.font(.caption)
					.foregroundColor(.secondary)
					.padding(.top, 8)
			}
		} label: {
			Text("Metadata")
				.font(.headline)
		}
		.task {
			await loadMetadata()
		}
		.onChange(of: photo.id) {
			Task {
				await loadMetadata()
			}
		}
	}
	
	private func loadMetadata() async {
		isLoading = true
		
		// Load base metadata
		let baseMetadata = await UnifiedMetadataLoader.shared.loadMetadata(for: photo)
		
		// Load extended metadata if available
		let extended: ExtendedPhotoMetadata?
		if let baseMetadata = baseMetadata {
			extended = await UnifiedMetadataLoader.shared.loadExtendedMetadata(for: photo, baseMetadata: baseMetadata)
		} else {
			extended = nil
		}
		
		await MainActor.run {
			self.metadata = baseMetadata
			self.extendedMetadata = extended
			self.isLoading = false
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
	@State private var isHovered = false

	var body: some View {
		Button {
			Task {
				await action()
			}
		} label: {
			Label(title, systemImage: systemImage)
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.horizontal, 8)
				.padding(.vertical, 4)
				.background(
					RoundedRectangle(cornerRadius: 6)
						.fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
				)
		}
		.buttonStyle(.plain)
		.onHover { hovering in
			isHovered = hovering
		}
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

	var availablePhotos: [PhotoFile] {
		localPhotos.filter { !$0.isArchived }
	}

	var starredPhotos: [PhotoFile] {
		availablePhotos.filter { photo in
			guard let md5 = photo.md5Hash else { return false }
			let status = BackupQueueManager.shared.backupStatus[md5]
			return status == .queued || status == .uploaded
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Actions")
				.font(.headline)

			// Show status icons for mixed states
			if photos.count > 1 {
				StatusIconsView(selection: photos)
					.padding(.vertical, 4)
			}

			// Star toggle - only show if all available photos are in same state
			if availablePhotos.count == photos.count && !availablePhotos.isEmpty {
				if starredPhotos.count == 0 {
					// All unstarred
					ActionButton(title: "Star All", systemImage: "star") {
						Task { @MainActor in
							print("[InspectorView] Star All clicked for \(availablePhotos.count) photos")
							for photo in availablePhotos {
								print("[InspectorView] Adding to queue: \(photo.filename)")
								BackupQueueManager.shared.addToQueue(photo)
							}
							print("[InspectorView] Star All completed")
						}
					}
				} else if starredPhotos.count == availablePhotos.count {
					// All starred
					ActionButton(title: "Unstar All", systemImage: "star.fill") {
						Task { @MainActor in
							print("[InspectorView] Unstar All clicked for \(starredPhotos.count) photos")
							for photo in starredPhotos {
								print("[InspectorView] Removing from queue: \(photo.filename)")
								BackupQueueManager.shared.removeFromQueue(photo)
							}
							print("[InspectorView] Unstar All completed")
						}
					}
				}
				// Mixed state - no button shown
			}

			if !localPhotos.isEmpty {
				ActionButton(title: "Show All in Finder", systemImage: "folder") {
					// TODO: Implement
				}
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

// MARK: - Tag Section

struct TagSection: View {
	let photo: any PhotoItem
	@State private var currentTag: PhotoTag?
	@State private var isLoading = false

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Tag")
				.font(.headline)

			// Current tag status
			HStack {
				Text("Current")
					.foregroundColor(.secondary)
				Spacer()
				if isLoading {
					ProgressView()
						.scaleEffect(0.7)
				} else if let tag = currentTag {
					// TODO: Update for color flags
					Text("Flags: \(tag.flags.count)")
						.font(.caption)
				} else {
					Text("None")
						.foregroundColor(.secondary)
				}
			}
			.font(.system(.body, design: .rounded))

			Divider()
				.padding(.vertical, 4)

			// Compact flag buttons in horizontal stack
			HStack(spacing: 4) {
				ForEach(ColorFlag.allCases, id: \.self) { flag in
					Button(action: {
						Task {
							await toggleFlag(flag)
						}
					}) {
						let isActive = currentTag?.flags.contains(flag) == true
						flag.flagView
							.font(.system(size: 14))
							.frame(width: 28, height: 28)
							.background(
								RoundedRectangle(cornerRadius: 6)
									.fill(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
							)
							.overlay(
								RoundedRectangle(cornerRadius: 6)
									.stroke(isActive ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
							)
					}
					.buttonStyle(.plain)
					.help("Flag: \(String(describing: flag).capitalized) (\(flag.keyboardShortcut))")
				}
				
				Spacer()
				
				// Clear button
				if currentTag != nil && !currentTag!.flags.isEmpty {
					Button(action: {
						Task {
							await clearAllFlags()
						}
					}) {
						Image(systemName: "xmark.circle.fill")
							.foregroundColor(.secondary)
							.font(.system(size: 16))
					}
					.buttonStyle(.plain)
					.help("Clear all flags (0)")
				}
			}
			.frame(maxWidth: .infinity)
		}
		.task {
			await loadTag()
		}
		.onChange(of: photo.id) {
			Task {
				await loadTag()
			}
		}
	}

	private func loadTag() async {
		isLoading = true
		currentTag = await TagManager.shared.getTag(for: photo)
		isLoading = false
	}

	private func toggleFlag(_ flag: ColorFlag) async {
		await TagManager.shared.toggleFlag(flag, for: photo)
		await loadTag()
	}
	
	private func clearAllFlags() async {
		await TagManager.shared.clearFlags(for: photo)
		await loadTag()
	}
}

struct EmojiButton: View {
	let emoji: String
	let isSelected: Bool
	let action: () -> Void
	@State private var isHovered = false

	var body: some View {
		Button(action: action) {
			Text(emoji)
				.font(.title2)
				.frame(width: 44, height: 44)
				.background(
					RoundedRectangle(cornerRadius: 8)
						.fill(
							isSelected ? Color.accentColor.opacity(0.3) :
							isHovered ? Color.secondary.opacity(0.1) :
							Color.clear
						)
				)
				.overlay(
					RoundedRectangle(cornerRadius: 8)
						.stroke(
							isSelected ? Color.accentColor :
							isHovered ? Color.secondary.opacity(0.3) :
							Color.clear,
							lineWidth: 2
						)
				)
		}
		.buttonStyle(.plain)
		.onHover { hovering in
			isHovered = hovering
		}
	}
}

// MARK: - Preview

struct InspectorView_Previews: PreviewProvider {
	static var previews: some View {
		InspectorView(selection: [])
			.frame(width: 300)
	}
}

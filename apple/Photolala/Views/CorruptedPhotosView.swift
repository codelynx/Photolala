//
//  CorruptedPhotosView.swift
//  Photolala
//
//  Created by Claude on 2025/07/29.
//

import SwiftUI

struct CorruptedPhotosView: View {
	@ObservedObject var manager = CorruptedPhotoManager.shared
	@State private var showingDeleteConfirmation = false
	@State private var photosToDelete: Set<CorruptedPhotoInfo> = []
	
	var body: some View {
		VStack(spacing: 20) {
			// Header
			VStack(alignment: .leading, spacing: 8) {
				Label("Corrupted Photos Detected", systemImage: "exclamationmark.triangle.fill")
					.font(.headline)
					.foregroundColor(.orange)
				
				Text("\(manager.corruptedPhotos.count) photo\(manager.corruptedPhotos.count == 1 ? "" : "s") cannot be displayed due to file corruption or being empty.")
					.font(.subheadline)
					.foregroundColor(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			
			// List of corrupted photos
			List(manager.corruptedPhotos) { info in
				CorruptedPhotoRow(info: info, isSelected: photosToDelete.contains(info)) {
					if photosToDelete.contains(info) {
						photosToDelete.remove(info)
					} else {
						photosToDelete.insert(info)
					}
				}
			}
			.frame(maxHeight: 300)
			
			// Actions
			HStack {
				Button("Select All") {
					photosToDelete = Set(manager.corruptedPhotos)
				}
				.disabled(photosToDelete.count == manager.corruptedPhotos.count)
				
				Button("Deselect All") {
					photosToDelete.removeAll()
				}
				.disabled(photosToDelete.isEmpty)
				
				Spacer()
				
				Button("Ignore") {
					manager.showCorruptedPhotosAlert = false
				}
				
				Button("Remove Selected") {
					showingDeleteConfirmation = true
				}
				.disabled(photosToDelete.isEmpty)
				.buttonStyle(.borderedProminent)
			}
		}
		.padding()
		.frame(width: 600)
		.confirmationDialog(
			"Remove Corrupted Photos",
			isPresented: $showingDeleteConfirmation,
			titleVisibility: .visible
		) {
			Button("Move to Trash", role: .destructive) {
				moveSelectedToTrash()
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Move \(photosToDelete.count) corrupted photo\(photosToDelete.count == 1 ? "" : "s") to trash?")
		}
	}
	
	private func moveSelectedToTrash() {
		for info in photosToDelete {
			do {
				try FileManager.default.trashItem(at: info.photo.fileURL, resultingItemURL: nil)
				manager.removeCorruptedPhoto(info)
			} catch {
				print("Failed to move \(info.photo.filename) to trash: \(error)")
			}
		}
		photosToDelete.removeAll()
		
		if manager.corruptedPhotos.isEmpty {
			manager.showCorruptedPhotosAlert = false
		}
	}
}

struct CorruptedPhotoRow: View {
	let info: CorruptedPhotoInfo
	let isSelected: Bool
	let onToggle: () -> Void
	
	var body: some View {
		HStack {
			Image(systemName: isSelected ? "checkmark.square" : "square")
				.foregroundColor(isSelected ? .accentColor : .secondary)
				.onTapGesture {
					onToggle()
				}
			
			VStack(alignment: .leading, spacing: 4) {
				Text(info.photo.filename)
					.font(.system(.body, design: .monospaced))
					.lineLimit(1)
				
				HStack {
					Text(info.error.errorDescription ?? "Unknown error")
						.font(.caption)
						.foregroundColor(.red)
					
					Spacer()
					
					if let size = info.photo.fileSize {
						Text(formatFileSize(size))
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
			}
			
			Spacer()
		}
		.padding(.vertical, 4)
		.contentShape(Rectangle())
		.onTapGesture {
			onToggle()
		}
	}
}

// Alert modifier for showing corrupted photos
struct CorruptedPhotosAlert: ViewModifier {
	@ObservedObject var manager = CorruptedPhotoManager.shared
	
	func body(content: Content) -> some View {
		content
			.sheet(isPresented: $manager.showCorruptedPhotosAlert) {
				CorruptedPhotosView()
			}
	}
}

extension View {
	func corruptedPhotosAlert() -> some View {
		modifier(CorruptedPhotosAlert())
	}
}

// Helper function
private func formatFileSize(_ bytes: Int64) -> String {
	let formatter = ByteCountFormatter()
	formatter.countStyle = .file
	return formatter.string(fromByteCount: bytes)
}
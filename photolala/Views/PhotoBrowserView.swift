//
//  PhotoBrowserView.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI
import Observation

struct PhotoBrowserView: View {
	let directoryPath: NSString
	@State private var settings = ThumbnailDisplaySettings()
	@State private var selectionManager = SelectionManager()
	@State private var isSelectionModeActive = false
	@State private var photosCount = 0
	@State private var navigationPath = NavigationPath()
	@State private var selectedPhotoNavigation: PreviewNavigation?
	
	init(directoryPath: NSString) {
		self.directoryPath = directoryPath
	}
	
	var body: some View {
#if os(macOS)
		NavigationStack(path: $navigationPath) {
			collectionContent
				.navigationDestination(for: PreviewNavigation.self) { navigation in
					PhotoPreviewView(
						photos: navigation.photos,
						initialIndex: navigation.initialIndex
					)
					.navigationBarBackButtonHidden(true)
				}
		}
#else
		collectionContent
			.navigationDestination(item: $selectedPhotoNavigation) { navigation in
				PhotoPreviewView(
					photos: navigation.photos,
					initialIndex: navigation.initialIndex
				)
				.navigationBarBackButtonHidden(true)
			}
#endif
	}
	
	@ViewBuilder
	private var collectionContent: some View {
		Group {
#if os(iOS)
			PhotoCollectionView(
				directoryPath: directoryPath,
				settings: settings,
				selectionManager: selectionManager,
				onSelectPhoto: handlePhotoSelection,
				isSelectionModeActive: $isSelectionModeActive,
				photosCount: $photosCount
			)
#else
			PhotoCollectionView(
				directoryPath: directoryPath,
				settings: settings,
				selectionManager: selectionManager,
				onSelectPhoto: handlePhotoSelection
			)
#endif
		}
		.navigationTitle(directoryPath.lastPathComponent)
#if os(macOS)
		.navigationSubtitle(directoryPath as String)
#endif
		.toolbar {
#if os(iOS)
			ToolbarItem(placement: .navigationBarTrailing) {
				if photosCount > 0 && !isSelectionModeActive {
					Button("Select") {
						isSelectionModeActive = true
					}
				}
			}
#endif
			
			ToolbarItemGroup(placement: .automatic) {
				// Preview selected photos button
				if !selectionManager.selectedItems.isEmpty {
					Button(action: previewSelectedPhotos) {
						Label("Preview", systemImage: "eye")
					}
#if os(macOS)
					.help("Preview selected photos")
#endif
				}
				// Display mode toggle
				Button(action: {
					settings.displayMode = settings.displayMode == .scaleToFit ? .scaleToFill : .scaleToFit
				}) {
					Image(systemName: settings.displayMode == .scaleToFit ? "aspectratio" : "aspectratio.fill")
				}
#if os(macOS)
				.help(settings.displayMode == .scaleToFit ? "Switch to Fill" : "Switch to Fit")
#endif
				
#if os(iOS)
				// Size menu for iOS
				Menu {
					Button("Small") {
						settings.thumbnailOption = .small
					}
					Button("Medium") {
						settings.thumbnailOption = .medium
					}
					Button("Large") {
						settings.thumbnailOption = .large
					}
				} label: {
					Image(systemName: "slider.horizontal.3")
				}
#else
				// Size picker for macOS
				Picker("Size", selection: $settings.thumbnailOption) {
					Text("Small").tag(ThumbnailOption.small)
					Text("Medium").tag(ThumbnailOption.medium)
					Text("Large").tag(ThumbnailOption.large)
				}
				.pickerStyle(.segmented)
				.help("Thumbnail size")
#endif
			}
		}
	}
	
	private func handlePhotoSelection(_ photo: PhotoReference, _ allPhotos: [PhotoReference]) {
		print("[PhotoBrowserView] handlePhotoSelection called for: \(photo.filename)")
		
		// If there's an active selection, show only selected photos
		let photosToShow: [PhotoReference]
		let initialIndex: Int
		
		if !selectionManager.selectedItems.isEmpty {
			// Convert selection to array maintaining order
			photosToShow = allPhotos.filter { selectionManager.selectedItems.contains($0) }
			initialIndex = photosToShow.firstIndex(of: photo) ?? 0
			print("[PhotoBrowserView] Showing \(photosToShow.count) selected photos")
		} else {
			// Show all photos
			photosToShow = allPhotos
			initialIndex = allPhotos.firstIndex(of: photo) ?? 0
			print("[PhotoBrowserView] Showing all \(photosToShow.count) photos")
		}
		
		// Navigate to preview
		print("[PhotoBrowserView] Navigating to preview with index: \(initialIndex)")
		let navigation = PreviewNavigation(photos: photosToShow, initialIndex: initialIndex)
		
		#if os(macOS)
		navigationPath.append(navigation)
		#else
		selectedPhotoNavigation = navigation
		#endif
	}
	
	private func previewSelectedPhotos() {
		// Get the selected photos in order
		let selectedPhotos = selectionManager.selectedItems.sorted { photo1, photo2 in
			// Sort by filename to maintain consistent order
			photo1.filename < photo2.filename
		}
		
		guard !selectedPhotos.isEmpty else { return }
		
		print("[PhotoBrowserView] Previewing \(selectedPhotos.count) selected photos")
		
		// Start preview from the first selected photo
		let navigation = PreviewNavigation(photos: selectedPhotos, initialIndex: 0)
		
		#if os(macOS)
		navigationPath.append(navigation)
		#else
		selectedPhotoNavigation = navigation
		#endif
	}
}

// Navigation data model
struct PreviewNavigation: Hashable {
	let photos: [PhotoReference]
	let initialIndex: Int
}

#Preview {
	PhotoBrowserView(directoryPath: "/Users/example/Pictures")
}

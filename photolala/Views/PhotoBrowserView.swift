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
	@State private var photosCount = 0
	@State private var selectedPhotos: [PhotoReference] = []
	@State private var navigationPath = NavigationPath()
	@State private var selectedPhotoNavigation: PreviewNavigation?
	@State private var allPhotos: [PhotoReference] = []
	@State private var showingHelp = false
	
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
		.onKeyPress(.space) {
			handleSpaceKeyPress()
			return .handled
		}
		.onKeyPress(keys: ["s"]) { _ in
			// Print cache statistics
			PhotoManager.shared.printCacheStatistics()
			return .handled
		}
		.onKeyPress(keys: ["r"]) { _ in
			// Reset cache statistics
			PhotoManager.shared.resetStatistics()
			return .handled
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
			.sheet(isPresented: $showingHelp) {
				HelpView()
			}
			.onReceive(NotificationCenter.default.publisher(for: .showHelp)) { _ in
				showingHelp = true
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
				onSelectPhoto: handlePhotoSelection,
				onPhotosLoaded: { photos in
					self.allPhotos = photos
				},
				onSelectionChanged: { photos in
					self.selectedPhotos = photos
				},
				photosCount: $photosCount
			)
#else
			PhotoCollectionView(
				directoryPath: directoryPath,
				settings: settings,
				onSelectPhoto: handlePhotoSelection,
				onPhotosLoaded: { photos in
					self.allPhotos = photos
					self.photosCount = photos.count
				},
				onSelectionChanged: { photos in
					self.selectedPhotos = photos
				}
			)
#endif
		}
		.navigationTitle(directoryPath.lastPathComponent)
#if os(macOS)
		.navigationSubtitle(directoryPath as String)
#endif
		.onReceive(NotificationCenter.default.publisher(for: .deselectAll)) { _ in
			selectedPhotos = []
		}
		.toolbar {
			ToolbarItemGroup(placement: .automatic) {
				// Preview selected photos button
				if !selectedPhotos.isEmpty {
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
					Button("S") {
						settings.thumbnailOption = .small
					}
					Button("M") {
						settings.thumbnailOption = .medium
					}
					Button("L") {
						settings.thumbnailOption = .large
					}
				} label: {
					Image(systemName: "slider.horizontal.3")
				}
#else
				// Size picker for macOS
				Picker("Size", selection: $settings.thumbnailOption) {
					Text("S").tag(ThumbnailOption.small)
					Text("M").tag(ThumbnailOption.medium)
					Text("L").tag(ThumbnailOption.large)
				}
				.pickerStyle(.segmented)
				.help("Thumbnail size")
#endif
				
				// Sort picker
#if os(iOS)
				Menu {
					ForEach(PhotoSortOption.allCases, id: \.self) { option in
						Button(action: {
							settings.sortOption = option
						}) {
							Label(option.rawValue, systemImage: option.systemImage)
							if option == settings.sortOption {
								Image(systemName: "checkmark")
							}
						}
					}
				} label: {
					Label("Sort", systemImage: settings.sortOption.systemImage)
				}
#else
				// macOS: Use a picker with menu style
				Picker("Sort", selection: $settings.sortOption) {
					ForEach(PhotoSortOption.allCases, id: \.self) { option in
						Text(option.rawValue)
							.tag(option)
					}
				}
				.pickerStyle(.menu)
				.frame(width: 150)
				.help("Sort photos by")
#endif
				
				// Grouping picker
#if os(iOS)
				Menu {
					Button(action: {
						settings.groupingOption = .year
					}) {
						Label("Year", systemImage: "calendar")
						if settings.groupingOption == .year {
							Image(systemName: "checkmark")
						}
					}
					Button(action: {
						settings.groupingOption = .month
					}) {
						Label("Month", systemImage: "calendar.badge.clock")
						if settings.groupingOption == .month {
							Image(systemName: "checkmark")
						}
					}
					Button(action: {
						settings.groupingOption = .day
					}) {
						Label("Day", systemImage: "calendar.circle")
						if settings.groupingOption == .day {
							Image(systemName: "checkmark")
						}
					}
					
					Divider()
					
					Button(action: {
						settings.groupingOption = .none
					}) {
						Label("None", systemImage: "square.grid.3x3")
						if settings.groupingOption == .none {
							Image(systemName: "checkmark")
						}
					}
				} label: {
					if settings.groupingOption != .none {
						Label(settings.groupingOption.rawValue, systemImage: settings.groupingOption.systemImage)
					} else {
						Image(systemName: "calendar")
					}
				}
#else
				// macOS: Use a picker with menu style
				Picker("Group by", selection: $settings.groupingOption) {
					Text("Year").tag(PhotoGroupingOption.year)
					Text("Month").tag(PhotoGroupingOption.month)
					Text("Day").tag(PhotoGroupingOption.day)
					Divider()
					Text("None").tag(PhotoGroupingOption.none)
				}
				.pickerStyle(.menu)
				.frame(width: 120)
				.help("Group photos by date")
#endif
			}
		}
	}
	
	private func handleSpaceKeyPress() {
		// If we don't have photos yet, return
		guard !allPhotos.isEmpty else { return }
		
		// Always show all photos, but start from selected if any
		let photosToShow = allPhotos
		let initialIndex: Int
		
		if !selectedPhotos.isEmpty {
			// Find the first selected photo in the full list
			if let firstSelected = selectedPhotos.first,
			   let index = allPhotos.firstIndex(of: firstSelected) {
				initialIndex = index
			} else {
				initialIndex = 0
			}
		} else {
			initialIndex = 0
		}
		
		print("[PhotoBrowserView] Space key: Showing all \(photosToShow.count) photos, starting at index \(initialIndex)")
		
		let navigation = PreviewNavigation(photos: photosToShow, initialIndex: initialIndex)
		
		#if os(macOS)
		navigationPath.append(navigation)
		#else
		selectedPhotoNavigation = navigation
		#endif
	}
	
	private func handlePhotoSelection(_ photo: PhotoReference, _ allPhotos: [PhotoReference]) {
		print("[PhotoBrowserView] handlePhotoSelection called for: \(photo.filename)")
		
		// Store all photos for space key navigation
		self.allPhotos = allPhotos
		
		// If there's an active selection, show only selected photos
		let photosToShow: [PhotoReference]
		let initialIndex: Int
		
		if !selectedPhotos.isEmpty {
			// Convert selection to array maintaining order
			photosToShow = allPhotos.filter { selectedPhotos.contains($0) }
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
		let sortedPhotos = selectedPhotos.sorted { photo1, photo2 in
			// Sort by filename to maintain consistent order
			photo1.filename < photo2.filename
		}
		
		guard !sortedPhotos.isEmpty else { return }
		
		print("[PhotoBrowserView] Previewing \(sortedPhotos.count) selected photos")
		
		// Start preview from the first selected photo
		let navigation = PreviewNavigation(photos: sortedPhotos, initialIndex: 0)
		
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

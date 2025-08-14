//
//  ApplePhotosBrowserView.swift
//  Photolala
//
//  Browser view for Apple Photos Library
//

import SwiftUI
import Photos

struct ApplePhotosBrowserView: View {
	@StateObject private var photoProvider = ApplePhotosProvider()
	@State private var settings = ThumbnailDisplaySettings()
	@State private var selection: Set<PhotoApple> = []
	@State private var showingInspector = false
	@State private var scrollToSelection = false
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var showingAlbumPicker = false
	@State private var albums: [PHAssetCollection] = []
	@State private var selectedAlbum: PHAssetCollection?
	
	// Computed property to convert selection for inspector
	private var inspectorSelection: [any PhotoItem] {
		selection.map { $0 as any PhotoItem }
	}
	
	var body: some View {
		NavigationStack {
			UnifiedPhotoCollectionViewRepresentable(
			photoProvider: photoProvider,
			settings: $settings,
			onSelectPhoto: { photo, allPhotos in
				// Handle photo selection (e.g., for preview navigation)
				// The actual selection is managed by onSelectionChanged
			},
			onSelectionChanged: { photos in
				// Update selection
				selection = Set(photos.compactMap { $0 as? PhotoApple })
			},
			scrollToSelection: $scrollToSelection
		)
		.navigationTitle(photoProvider.displayTitle)
		#if os(macOS)
		.navigationSubtitle(photoProvider.displaySubtitle)
		#endif
		.photoInspector(
			isPresented: $showingInspector,
			selection: inspectorSelection
		)
		.onChange(of: showingInspector) { oldValue, newValue in
			// If showing inspector and we have selection, scroll to it
			if newValue && !selection.isEmpty {
				scrollToSelection = true
			}
		}
		.photoBrowserToolbar(
			settings: $settings,
			showingInspector: $showingInspector,
			isRefreshing: isLoading,
			onRefresh: { await refreshPhotos() },
			additionalItems: {
				ToolbarItem(placement: .primaryAction) {
					Button(action: { showingAlbumPicker.toggle() }) {
						Label("Albums", systemImage: "square.stack.3d.up")
					}
					.help("Show album picker")
				}
			}
		)
		.sheet(isPresented: $showingAlbumPicker) {
			AlbumPickerView(
				albums: albums,
				selectedAlbum: $selectedAlbum,
				onSelect: { album in
					Task {
						selectedAlbum = album
						showingAlbumPicker = false
						try? await photoProvider.selectAlbum(album)
					}
				}
			)
		}
		.task {
			await loadInitialData()
		}
		.alert("Error", isPresented: Binding(
			get: { errorMessage != nil },
			set: { _ in errorMessage = nil }
		)) {
			Button("OK") { errorMessage = nil }
		} message: {
			Text(errorMessage ?? "Unknown error")
		}
		}
	}
	
	// MARK: - Private Methods
	
	private func loadInitialData() async {
		isLoading = true
		
		// First ensure authorization has been requested
		await photoProvider.checkAndRequestAuthorization()
		
		// Now check authorization
		guard ApplePhotosProvider.isAuthorized() else {
			isLoading = false
			let status = ApplePhotosProvider.authorizationStatus()
			switch status {
			case .denied:
				errorMessage = "Photo Library access was denied. Please grant access in Settings > Privacy & Security > Photos."
			case .restricted:
				errorMessage = "Photo Library access is restricted on this device."
			case .notDetermined:
				errorMessage = "Photo Library access has not been determined. Please restart the app."
			default:
				errorMessage = "Photo Library access is required. Please grant access in Settings."
			}
			return
		}
		
		do {
			// Load albums
			albums = await photoProvider.fetchAlbums()
			
			// Load photos
			try await photoProvider.loadPhotos()
		} catch {
			errorMessage = error.localizedDescription
		}
		
		isLoading = false
	}
	
	private func refreshPhotos() async {
		isLoading = true
		do {
			try await photoProvider.refresh()
		} catch {
			errorMessage = error.localizedDescription
		}
		isLoading = false
	}
}

// MARK: - Album Picker View

struct AlbumPickerView: View {
	let albums: [PHAssetCollection]
	@Binding var selectedAlbum: PHAssetCollection?
	let onSelect: (PHAssetCollection?) -> Void
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		NavigationStack {
			List {
				// All Photos option
				Button(action: {
					onSelect(nil)
				}) {
					HStack {
						Image(systemName: "photo.on.rectangle")
							.font(.title2)
						VStack(alignment: .leading) {
							Text("All Photos")
								.font(.headline)
							Text("Show all photos in your library")
								.font(.caption)
								.foregroundColor(.secondary)
						}
						Spacer()
						if selectedAlbum == nil {
							Label("Selected", systemImage: "checkmark")
								.labelStyle(.iconOnly)
								.foregroundColor(.accentColor)
						}
					}
					.padding(.vertical, 4)
				}
				.buttonStyle(.plain)
				
				Divider()
				
				// Albums
				ForEach(albums, id: \.localIdentifier) { album in
					Button(action: {
						onSelect(album)
					}) {
						HStack {
							Image(systemName: iconForAlbum(album))
								.font(.title2)
							VStack(alignment: .leading) {
								Text(album.localizedTitle ?? "Untitled")
									.font(.headline)
								Text("\(PHAsset.fetchAssets(in: album, options: nil).count) photos")
									.font(.caption)
									.foregroundColor(.secondary)
							}
							Spacer()
							if selectedAlbum?.localIdentifier == album.localIdentifier {
								Label("Selected", systemImage: "checkmark")
									.labelStyle(.iconOnly)
									.foregroundColor(.accentColor)
							}
						}
						.padding(.vertical, 4)
					}
					.buttonStyle(.plain)
				}
			}
			.navigationTitle("Albums")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
			}
		}
		#if os(macOS)
		.frame(width: 400, height: 500)
		#endif
	}
	
	private func iconForAlbum(_ album: PHAssetCollection) -> String {
		switch album.assetCollectionSubtype {
		case .smartAlbumFavorites:
			return "heart"
		case .smartAlbumRecentlyAdded:
			return "clock"
		case .smartAlbumScreenshots:
			return "camera.viewfinder"
		case .smartAlbumSelfPortraits:
			return "person.crop.circle"
		case .smartAlbumLivePhotos:
			return "livephoto"
		case .smartAlbumPanoramas:
			return "pano"
		default:
			return "folder"
		}
	}
}

// MARK: - Preview

#Preview {
	NavigationStack {
		ApplePhotosBrowserView()
	}
}
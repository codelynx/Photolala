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
		UnifiedPhotoCollectionViewRepresentable(
			photoProvider: photoProvider,
			settings: $settings,
			selection: Binding(
				get: { Set(selection.map { $0 as any PhotoItem }) },
				set: { newSelection in
					selection = Set(newSelection.compactMap { $0 as? PhotoApple })
				}
			),
			onArchivedPhotoClick: { _ in
				// Apple Photos don't have archive status
			}
		)
		.navigationTitle(photoProvider.displayTitle)
		.navigationSubtitle(photoProvider.displaySubtitle)
		#if os(macOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
		.inspector(isPresented: $showingInspector) {
			InspectorView(selection: inspectorSelection)
				.inspectorColumnWidth(min: 250, ideal: 300, max: 400)
		}
		.photoBrowserToolbar(
			settings: $settings,
			showingInspector: $showingInspector,
			isRefreshing: isLoading,
			onRefresh: { await refreshPhotos() }
		)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button(action: { showingAlbumPicker.toggle() }) {
					Label("Albums", systemImage: "square.stack.3d.up")
				}
				.help("Show album picker")
			}
		}
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
	
	// MARK: - Private Methods
	
	private func loadInitialData() async {
		// Check authorization
		guard ApplePhotosProvider.isAuthorized() else {
			errorMessage = "Photo Library access is required. Please grant access in Settings."
			return
		}
		
		isLoading = true
		
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
							Image(systemName: "checkmark")
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
								Image(systemName: "checkmark")
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
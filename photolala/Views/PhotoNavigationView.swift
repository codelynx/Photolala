//
//  PhotoNavigationView.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI

struct PhotoNavigationView: View {
	let folderURL: URL
	@State private var navigationPath = NavigationPath()
	
	var body: some View {
		NavigationStack(path: $navigationPath) {
			PhotoCollectionView(
				folderURL: folderURL,
				onSelectPhoto: { photoURL, photos in
					// Navigate to photo detail
					navigationPath.append(PhotoDetailDestination(photoURL: photoURL, photos: photos))
				},
				onSelectFolder: { folderURL in
					// Navigate to subfolder
					navigationPath.append(folderURL)
				}
			)
			.navigationTitle(folderURL.lastPathComponent)
			#if os(macOS)
			.navigationSubtitle(folderURL.path)
			#endif
				.toolbar {
					ToolbarItem(placement: .navigation) {
						Button(action: goBack) {
							Label("Back", systemImage: "chevron.left")
						}
						.disabled(navigationPath.isEmpty)
					}
					
					ToolbarItem(placement: .primaryAction) {
						Button(action: openSubfolder) {
							Label("Open Folder", systemImage: "folder")
						}
					}
				}
				.navigationDestination(for: URL.self) { url in
					PhotoCollectionView(
						folderURL: url,
						onSelectPhoto: { photoURL, photos in
							navigationPath.append(PhotoDetailDestination(photoURL: photoURL, photos: photos))
						},
						onSelectFolder: { folderURL in
							navigationPath.append(folderURL)
						}
					)
					.navigationTitle(url.lastPathComponent)
					#if os(macOS)
					.navigationSubtitle(url.path)
					#endif
				}
				.navigationDestination(for: PhotoDetailDestination.self) { destination in
					PhotoDetailView(photoURL: destination.photoURL, photos: destination.photos)
				}
		}
		.frame(minWidth: 800, minHeight: 600)
	}
	
	private func goBack() {
		if !navigationPath.isEmpty {
			navigationPath.removeLast()
		}
	}
	
	private func openSubfolder() {
		// Example: Navigate to a subfolder
		// You would implement folder selection here
	}
}

// Navigation destination for photo details
struct PhotoDetailDestination: Hashable {
	let photoURL: URL
	let photos: [URL]
}

// Example photo detail view
struct PhotoDetailView: View {
	let photoURL: URL
	let photos: [URL]
	
	var body: some View {
		VStack {
			// Photo viewer implementation
			#if os(macOS)
			if let image = NSImage(contentsOf: photoURL) {
				Image(nsImage: image)
					.resizable()
					.scaledToFit()
			} else {
				Text("Loading...")
					.foregroundStyle(.secondary)
			}
			#else
			if let data = try? Data(contentsOf: photoURL),
			   let image = UIImage(data: data) {
				Image(uiImage: image)
					.resizable()
					.scaledToFit()
			} else {
				Text("Loading...")
					.foregroundStyle(.secondary)
			}
			#endif
		}
		.navigationTitle(photoURL.lastPathComponent)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}


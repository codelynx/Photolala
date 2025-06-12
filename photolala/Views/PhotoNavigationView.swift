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
	#if os(macOS)
	@Environment(\.openWindow) private var openWindow
	#endif
	
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
				.toolbar {
					ToolbarItem(placement: .navigation) {
						Button(action: goBack) {
							Label("Back", systemImage: "chevron.left")
						}
						.disabled(navigationPath.isEmpty)
					}
					
					#if os(macOS)
					ToolbarItem(placement: .primaryAction) {
						Menu {
							Button("Open in New Window") {
								openInNewWindow()
							}
							
							Divider()
							
							Button("Select Folder...") {
								selectNewFolder()
							}
						} label: {
							Label("Open", systemImage: "folder")
						}
					}
					#endif
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
	
	#if os(macOS)
	private func openInNewWindow() {
		// Get current folder from navigation path or use root
		let currentFolder = getCurrentFolder()
		openWindow(value: currentFolder)
	}
	
	private func selectNewFolder() {
		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.allowsMultipleSelection = false
		panel.message = "Select a folder to browse"
		panel.prompt = "Open"
		
		panel.begin { response in
			if response == .OK, let url = panel.url {
				// Navigate to the selected folder
				navigationPath.append(url)
			}
		}
	}
	
	private func getCurrentFolder() -> URL {
		// If we have items in navigation path, get the last one
		// Otherwise use the root folder
		// This is simplified - you might need to track the path more carefully
		return folderURL
	}
	#endif
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


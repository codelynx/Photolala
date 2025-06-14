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
	
	init(directoryPath: NSString) {
		self.directoryPath = directoryPath
	}
	
	var body: some View {
		Group {
			#if os(iOS)
			PhotoCollectionView(
				directoryPath: directoryPath,
				settings: settings,
				selectionManager: selectionManager,
				isSelectionModeActive: $isSelectionModeActive,
				photosCount: $photosCount
			)
			#else
			PhotoCollectionView(
				directoryPath: directoryPath,
				settings: settings,
				selectionManager: selectionManager
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
}

#Preview {
	PhotoBrowserView(directoryPath: "/Users/example/Pictures")
}

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
	
	init(directoryPath: NSString) {
		self.directoryPath = directoryPath
	}
	
	var body: some View {
		PhotoCollectionView(directoryPath: directoryPath, settings: settings)
			.navigationTitle(directoryPath.lastPathComponent)
			#if os(macOS)
			.navigationSubtitle(directoryPath as String)
			#endif
			.toolbar {
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
							settings.thumbnailSize = ThumbnailSize.small.value
						}
						Button("Medium") {
							settings.thumbnailSize = ThumbnailSize.medium.value
						}
						Button("Large") {
							settings.thumbnailSize = ThumbnailSize.large.value
						}
					} label: {
						Image(systemName: "slider.horizontal.3")
					}
					#else
					// Size picker for macOS
					Picker("Size", selection: $settings.thumbnailSize) {
						Text("Small").tag(ThumbnailSize.small.value)
						Text("Medium").tag(ThumbnailSize.medium.value)
						Text("Large").tag(ThumbnailSize.large.value)
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

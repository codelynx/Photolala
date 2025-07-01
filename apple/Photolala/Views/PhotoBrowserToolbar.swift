//
//  PhotoBrowserToolbar.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/21.
//

import SwiftUI

/// Common toolbar items shared between photo browsers
struct PhotoBrowserCoreToolbar: ToolbarContent {
	@Binding var settings: ThumbnailDisplaySettings
	@Binding var showingInspector: Bool
	let isRefreshing: Bool
	let onRefresh: () async -> Void
	
	var body: some ToolbarContent {
		ToolbarItemGroup(placement: .automatic) {
			// Display mode toggle
			Button(action: {
				settings.displayMode = settings
					.displayMode == .scaleToFit ? .scaleToFill : .scaleToFit
			}) {
				Image(systemName: settings.displayMode == .scaleToFit ? "aspectratio" : "aspectratio.fill")
			}
			#if os(macOS)
			.help(settings.displayMode == .scaleToFit ? "Switch to Fill" : "Switch to Fit")
			#endif
			
			// Item info toggle
			Button(action: {
				settings.showItemInfo.toggle()
			}) {
				Image(systemName: "squares.below.rectangle")
			}
			#if os(macOS)
			.help(settings.showItemInfo ? "Hide item info" : "Show item info")
			#endif
			
			// Size controls
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
			
			// Refresh button
			Button(action: {
				Task {
					await onRefresh()
				}
			}) {
				Label("Refresh", systemImage: "arrow.clockwise")
			}
			.disabled(isRefreshing)
			#if os(macOS)
			.help("Refresh folder contents")
			#endif
			
			// Inspector button
			Button(action: {
				showingInspector.toggle()
			}) {
				Label("Inspector", systemImage: "info.circle")
			}
			#if os(macOS)
			.help(showingInspector ? "Hide Inspector" : "Show Inspector")
			#endif
		}
	}
}

// MARK: - View Extension for Easy Application

extension View {
	/// Applies the common photo browser toolbar with additional custom items
	func photoBrowserToolbar(
		settings: Binding<ThumbnailDisplaySettings>,
		showingInspector: Binding<Bool>,
		isRefreshing: Bool,
		onRefresh: @escaping () async -> Void,
		@ToolbarContentBuilder additionalItems: () -> some ToolbarContent = { EmptyToolbarContent() }
	) -> some View {
		self.toolbar {
			// Core items first
			PhotoBrowserCoreToolbar(
				settings: settings,
				showingInspector: showingInspector,
				isRefreshing: isRefreshing,
				onRefresh: onRefresh
			)
			
			// Additional browser-specific items
			additionalItems()
		}
	}
}

// MARK: - Empty Toolbar Content for Default Parameter

struct EmptyToolbarContent: ToolbarContent {
	var body: some ToolbarContent {
		ToolbarItem(placement: .automatic) {
			EmptyView()
		}
	}
}
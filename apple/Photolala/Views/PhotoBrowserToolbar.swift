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
			#if os(iOS)
			// Combined view options menu for iOS
			Menu {
				// Thumbnail size section
				Section("Thumbnail Size") {
					Button {
						settings.thumbnailOption = .small
					} label: {
						if settings.thumbnailOption == .small {
							Label("Small", systemImage: "checkmark")
						} else {
							Text("Small")
						}
					}
					Button {
						settings.thumbnailOption = .medium
					} label: {
						if settings.thumbnailOption == .medium {
							Label("Medium", systemImage: "checkmark")
						} else {
							Text("Medium")
						}
					}
					Button {
						settings.thumbnailOption = .large
					} label: {
						if settings.thumbnailOption == .large {
							Label("Large", systemImage: "checkmark")
						} else {
							Text("Large")
						}
					}
				}
				
				Divider()
				
				// Display options section
				Section("Display Options") {
					Button {
						settings.displayMode = settings.displayMode == .scaleToFit ? .scaleToFill : .scaleToFit
					} label: {
						Label(
							settings.displayMode == .scaleToFit ? "Scale to Fill" : "Scale to Fit",
							systemImage: settings.displayMode == .scaleToFit ? "aspectratio.fill" : "aspectratio"
						)
					}
					
					Button {
						settings.showItemInfo.toggle()
					} label: {
						if settings.showItemInfo {
							Label("Hide Info Bar", systemImage: "squares.below.rectangle")
								.labelStyle(.titleAndIcon)
								.padding(.horizontal, 4)
								.background(Color.primary)
								.foregroundColor(Color(XPlatform.primaryBackgroundColor))
								.cornerRadius(4)
						} else {
							Label("Show Info Bar", systemImage: "squares.below.rectangle")
						}
					}
				}
			} label: {
				Image(systemName: "gearshape")
			}
			#else
			// Keep separate controls for macOS
			// Display mode toggle
			Button(action: {
				settings.displayMode = settings
					.displayMode == .scaleToFit ? .scaleToFill : .scaleToFit
			}) {
				Image(systemName: settings.displayMode == .scaleToFit ? "aspectratio" : "aspectratio.fill")
			}
			.help(settings.displayMode == .scaleToFit ? "Switch to Fill" : "Switch to Fit")
			
			// Item info toggle
			Button(action: {
				settings.showItemInfo.toggle()
			}) {
				Image(systemName: "squares.below.rectangle")
					.padding(4)
					.background(settings.showItemInfo ? Color.primary : Color.clear)
					.foregroundColor(settings.showItemInfo ? Color(XPlatform.primaryBackgroundColor) : .primary)
					.cornerRadius(4)
			}
			.buttonStyle(.plain)
			.help(settings.showItemInfo ? "Hide item info" : "Show item info")
			
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
				Label("Inspector", systemImage: showingInspector ? "info.circle.fill" : "info.circle")
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
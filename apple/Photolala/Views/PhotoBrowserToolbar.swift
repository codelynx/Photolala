//
//  PhotoBrowserToolbar.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/21.
//

import SwiftUI
import XPlatform

/// Common toolbar items shared between photo browsers
struct PhotoBrowserCoreToolbar: ToolbarContent {
	@Binding var settings: ThumbnailDisplaySettings
	@Binding var showingInspector: Bool
	let isRefreshing: Bool
	let onRefresh: () async -> Void
	var onGroupingChange: ((PhotoGroupingOption) async -> Void)?
	
	var body: some ToolbarContent {
		ToolbarItemGroup(placement: .automatic) {
			// Unified View Menu for both platforms
			Menu {
				// Display submenu
				Menu("Display") {
					Picker(selection: $settings.displayMode) {
						Text("Scale to Fit").tag(ThumbnailDisplayMode.scaleToFit)
						Text("Scale to Fill").tag(ThumbnailDisplayMode.scaleToFill)
					} label: {
						EmptyView()
					}
					.pickerStyle(.inline)
				}
				
				// Show Item Info toggle
				Button {
					settings.showItemInfo.toggle()
				} label: {
					Label("Show Item Info", systemImage: settings.showItemInfo ? "checkmark" : "")
						.labelStyle(.titleAndIcon)
				}
				
				Divider()
				
				// Thumbnail size submenu
				Menu("Thumbnail Size") {
					Picker(selection: $settings.thumbnailOption) {
						Text("Small").tag(ThumbnailOption.small)
						Text("Medium").tag(ThumbnailOption.medium)
						Text("Large").tag(ThumbnailOption.large)
					} label: {
						EmptyView()
					}
					.pickerStyle(.inline)
				}
				
				// Group by picker (only show if we have a grouping change handler)
				if let onGroupingChange = onGroupingChange {
					Divider()
					
					Section("Group By") {
						Picker(selection: Binding(
							get: { settings.groupingOption },
							set: { newValue in
								settings.groupingOption = newValue
								Task {
									await onGroupingChange(newValue)
								}
							}
						)) {
							Text("None").tag(PhotoGroupingOption.none)
							Text("Year").tag(PhotoGroupingOption.year)
							Text("Year/Month").tag(PhotoGroupingOption.yearMonth)
						} label: {
							EmptyView()
						}
						.pickerStyle(.inline)
					}
				}
			} label: {
				#if os(iOS)
				Image(systemName: "gearshape")
				#else
				Label("View", systemImage: "chevron.down")
					.labelStyle(.titleAndIcon)
				#endif
			}
			
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
		onGroupingChange: ((PhotoGroupingOption) async -> Void)? = nil,
		@ToolbarContentBuilder additionalItems: () -> some ToolbarContent = { EmptyToolbarContent() }
	) -> some View {
		self.toolbar {
			// Core items first
			PhotoBrowserCoreToolbar(
				settings: settings,
				showingInspector: showingInspector,
				isRefreshing: isRefreshing,
				onRefresh: onRefresh,
				onGroupingChange: onGroupingChange
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
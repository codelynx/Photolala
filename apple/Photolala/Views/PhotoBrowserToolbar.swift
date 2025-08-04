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
				// Display section
				Section("Display") {
					Button {
						settings.displayMode = .scaleToFit
					} label: {
						Label("Scale to Fit", systemImage: settings.displayMode == .scaleToFit ? "checkmark" : "")
							.labelStyle(.titleAndIcon)
					}
					
					Button {
						settings.displayMode = .scaleToFill
					} label: {
						Label("Scale to Fill", systemImage: settings.displayMode == .scaleToFill ? "checkmark" : "")
							.labelStyle(.titleAndIcon)
					}
					
					Divider()
					
					Button {
						settings.showItemInfo.toggle()
					} label: {
						Label(settings.showItemInfo ? "Hide Item Info" : "Show Item Info", 
							  systemImage: settings.showItemInfo ? "checkmark" : "")
							.labelStyle(.titleAndIcon)
					}
				}
				
				Divider()
				
				// Thumbnail size section
				Section("Thumbnail Size") {
					Button {
						settings.thumbnailOption = .small
					} label: {
						Label("Small", systemImage: settings.thumbnailOption == .small ? "checkmark" : "")
							.labelStyle(.titleAndIcon)
					}
					
					Button {
						settings.thumbnailOption = .medium
					} label: {
						Label("Medium", systemImage: settings.thumbnailOption == .medium ? "checkmark" : "")
							.labelStyle(.titleAndIcon)
					}
					
					Button {
						settings.thumbnailOption = .large
					} label: {
						Label("Large", systemImage: settings.thumbnailOption == .large ? "checkmark" : "")
							.labelStyle(.titleAndIcon)
					}
				}
				
				// Group by section (only show if we have a grouping change handler)
				if let onGroupingChange = onGroupingChange {
					Divider()
					
					Section("Group By") {
						Button {
							settings.groupingOption = .none
							Task {
								await onGroupingChange(.none)
							}
						} label: {
							Label("None", systemImage: settings.groupingOption == .none ? "checkmark" : "")
								.labelStyle(.titleAndIcon)
						}
						
						Button {
							settings.groupingOption = .year
							Task {
								await onGroupingChange(.year)
							}
						} label: {
							Label("Year", systemImage: settings.groupingOption == .year ? "checkmark" : "")
								.labelStyle(.titleAndIcon)
						}
						
						Button {
							settings.groupingOption = .yearMonth
							Task {
								await onGroupingChange(.yearMonth)
							}
						} label: {
							Label("Year/Month", systemImage: settings.groupingOption == .yearMonth ? "checkmark" : "")
								.labelStyle(.titleAndIcon)
						}
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
//
//  InspectorContainer.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/19.
//

import SwiftUI

struct InspectorContainer: View {
	@Binding var isShowingInspector: Bool
	let selection: [any PhotoItem]
	@Environment(\.horizontalSizeClass) var horizontalSizeClass
	
	// Force view update when selection changes
	private var selectionID: String {
		selection.map { $0.id }.joined(separator: ",")
	}
	
	var body: some View {
		#if os(macOS)
		// Always use sidebar on macOS
		InspectorView(selection: selection)
			.id(selectionID)
		#else
		if horizontalSizeClass == .regular {
			// iPad in regular width - use sidebar
			InspectorView(selection: selection)
		} else {
			// iPhone or iPad in compact width - use sheet
			NavigationView {
				InspectorView(selection: selection)
					.navigationTitle("Details")
					.navigationBarTitleDisplayMode(.inline)
					.toolbar {
						ToolbarItem(placement: .navigationBarTrailing) {
							Button("Done") {
								isShowingInspector = false
							}
						}
					}
			}
		}
		#endif
	}
}

// MARK: - View Extension for Inspector

extension View {
	func inspector(
		isPresented: Binding<Bool>,
		selection: [any PhotoItem]
	) -> some View {
		#if os(macOS)
		// On macOS, show as a sidebar that adjusts content
		HStack(spacing: 0) {
			self
				.frame(maxWidth: .infinity)
			
			if isPresented.wrappedValue {
				Divider()
				
				InspectorContainer(
					isShowingInspector: isPresented,
					selection: selection
				)
				.frame(width: 300)
				.background(Color(NSColor.controlBackgroundColor))
				.transition(.move(edge: .trailing).combined(with: .opacity))
			}
		}
		.animation(.easeInOut(duration: 0.3), value: isPresented.wrappedValue)
		#else
		// On iOS/iPadOS, show as sheet or popover based on size class
		self.sheet(isPresented: isPresented) {
			InspectorContainer(
				isShowingInspector: isPresented,
				selection: selection
			)
		}
		#endif
	}
}
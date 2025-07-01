//
//  InspectorContainer.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/19.
//

import SwiftUI

// MARK: - View Extension for Inspector

extension View {
	func photoInspector(
		isPresented: Binding<Bool>,
		selection: [any PhotoItem]
	) -> some View {
		self.inspector(isPresented: isPresented) {
			InspectorView(selection: selection)
				.inspectorColumnWidth(min: 260, ideal: 300, max: 400)
		}
	}
}
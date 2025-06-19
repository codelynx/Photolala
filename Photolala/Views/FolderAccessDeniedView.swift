//
//  FolderAccessDeniedView.swift
//  Photolala
//
//  Created by Kenta Yoshikawa on 2025/06/18.
//

import SwiftUI

struct FolderAccessDeniedView: View {
	let folderURL: URL
	@Environment(\.openWindow) private var openWindow
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		VStack(spacing: 20) {
			Image(systemName: "exclamationmark.triangle")
				.font(.system(size: 48))
				.foregroundColor(.orange)
			
			Text("Cannot access directory")
				.font(.headline)
			
			Text(folderURL.lastPathComponent)
				.foregroundStyle(.secondary)
			
			Text("The folder may have been moved, deleted, or you no longer have permission to access it.")
				.font(.caption)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal)
			
			HStack(spacing: 12) {
				Button("Close Window") {
					dismiss()
				}
				.keyboardShortcut(.escape)
				
				Button("Select New Folder...") {
					selectNewFolder()
				}
				.keyboardShortcut(.return, modifiers: [])
			}
		}
		.frame(minWidth: 400, minHeight: 300)
		.padding()
	}
	
	private func selectNewFolder() {
		#if os(macOS)
		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.allowsMultipleSelection = false
		panel.message = "Select a folder to browse photos"
		panel.prompt = "Open"
		
		panel.begin { response in
			if response == .OK, let url = panel.url {
				// Save bookmark for the selected folder
				BookmarkManager.shared.saveBookmark(for: url)
				// Close this window
				dismiss()
				// Open new window with the selected folder
				openWindow(value: url)
			}
		}
		#endif
	}
}
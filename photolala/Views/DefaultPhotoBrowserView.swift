//
//  DefaultPhotoBrowserView.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI

struct DefaultPhotoBrowserView: View {
	@State private var selectedFolderURL: URL?
	
	var body: some View {
		Group {
			if let folderURL = selectedFolderURL {
				PhotoNavigationView(folderURL: folderURL)
			} else {
				// Empty state when no folder is selected
				VStack(spacing: 20) {
					Image(systemName: "folder.badge.questionmark")
						.font(.system(size: 64))
						.foregroundStyle(.secondary)
					
					Text("No Folder Selected")
						.font(.title2)
						.foregroundStyle(.secondary)
					
					Text("Press ⌘O to open a folder")
						.font(.callout)
						.foregroundStyle(.tertiary)
					
					Button("Open Folder...") {
						selectFolder()
					}
					.controlSize(.large)
					.buttonStyle(.borderedProminent)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.frame(minWidth: 600, minHeight: 400)
			}
		}
		.onAppear {
			// Optionally open a default folder (like Pictures)
			if selectedFolderURL == nil {
				openDefaultFolder()
			}
		}
		.onOpenURL { url in
			// Handle opening folders via drag & drop or other means
			var isDirectory: ObjCBool = false
			if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
			   isDirectory.boolValue {
				selectedFolderURL = url
			}
		}
	}
	
	private func selectFolder() {
		#if os(macOS)
		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.allowsMultipleSelection = false
		panel.message = "Select a folder to browse photos"
		panel.prompt = "Open"
		
		panel.begin { response in
			if response == .OK, let url = panel.url {
				selectedFolderURL = url
			}
		}
		#endif
	}
	
	private func openDefaultFolder() {
		// Try to open Pictures folder by default
		if let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
			// Check if it exists and is accessible
			var isDirectory: ObjCBool = false
			if FileManager.default.fileExists(atPath: picturesURL.path, isDirectory: &isDirectory),
			   isDirectory.boolValue {
				selectedFolderURL = picturesURL
			}
		}
	}
}
//
//  PhotolalaCommands.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI

struct PhotolalaCommands: Commands {
	@Environment(\.openWindow) private var openWindow
	
	var body: some Commands {
		// File menu customization
		CommandGroup(after: .newItem) {
			Button("Open Folder...") {
				openFolder()
			}
			.keyboardShortcut("O", modifiers: .command)
			
			Divider()
		}
		
		// Window menu customization
		CommandGroup(replacing: .windowSize) {
			// Custom window commands if needed
		}
	}
	
	private func openFolder() {
		#if os(macOS)
		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.allowsMultipleSelection = false
		panel.message = "Select a folder to browse photos"
		panel.prompt = "Open"
		
		panel.begin { response in
			if response == .OK, let url = panel.url {
				print("[PhotolalaCommands] Opening folder: \(url.path)")
				// Open new window with the selected folder
				openWindow(value: url)
			}
		}
		#endif
	}
}
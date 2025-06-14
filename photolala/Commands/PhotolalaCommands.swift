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
		
		// View menu
		CommandMenu("View") {
			Button("Cache Statistics...") {
				#if os(macOS)
				showCacheStatistics()
				#endif
			}
			.keyboardShortcut("I", modifiers: [.command, .shift])
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
	
	#if os(macOS)
	private func showCacheStatistics() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered,
			defer: false
		)
		
		window.title = "Cache Statistics"
		window.center()
		window.contentView = NSHostingView(rootView: CacheStatisticsView())
		window.makeKeyAndOrderFront(nil)
		
		// Keep window in front but not floating
		window.level = .normal
		window.isReleasedWhenClosed = false
	}
	#endif
}
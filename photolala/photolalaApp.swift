//
//  photolalaApp.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/09.
//

import SwiftUI

@main
struct photolalaApp: App {
	var body: some Scene {
		#if os(macOS)
		// Main window - opens on launch
		WindowGroup("Photolala") {
			DefaultPhotoBrowserView()
		}
		.commands {
			PhotolalaCommands()
		}
		
		// Additional windows for opening folders
		WindowGroup("Photo Browser", for: URL.self) { $folderURL in
			if let folderURL {
				PhotoNavigationView(folderURL: folderURL)
			} else {
				Text("No folder selected")
					.foregroundStyle(.secondary)
					.frame(minWidth: 400, minHeight: 300)
			}
		}
		#else
		// iOS/iPadOS keeps the welcome view for now
		WindowGroup {
			NavigationStack {
				WelcomeView()
			}
		}
		#endif
	}
}

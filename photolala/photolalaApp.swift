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
		// Folder browser windows only - no default window
		WindowGroup("Photolala", for: URL.self) { $folderURL in
			if let folderURL {
				PhotoBrowserView(directoryPath: folderURL.path as NSString)
			} else {
				Text("No folder selected")
					.foregroundStyle(.secondary)
					.frame(minWidth: 400, minHeight: 300)
			}
		}
		.defaultSize(width: 800, height: 600)
		.commands {
			PhotolalaCommands()
		}
		#else
		// iOS/iPadOS keeps the welcome view
		WindowGroup {
			NavigationStack {
				WelcomeView()
			}
		}
		#endif
	}
}

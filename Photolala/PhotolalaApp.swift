//
//  PhotolalaApp.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/09.
//

import SwiftUI

#if os(macOS)
	class AppDelegate: NSObject, NSApplicationDelegate {
		func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
			// Disable window restoration
			false
		}
	}
#endif

@main
struct PhotolalaApp: App {
	let photoManager = PhotoManager.shared

	#if os(macOS)
		@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	#endif

	init() {
		print("[photolalaApp] App initialized")

		// Initialize managers
		_ = IdentityManager.shared
		_ = S3BackupManager.shared
	}

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
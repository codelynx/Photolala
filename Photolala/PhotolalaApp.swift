//
//  PhotolalaApp.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/09.
//

import SwiftUI

#if os(macOS)
	class AppDelegate: NSObject, NSApplicationDelegate {
		func applicationWillFinishLaunching(_ notification: Notification) {
			// Disable automatic window restoration
			UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
			
			// Clear any existing window restoration data
			if let bundleID = Bundle.main.bundleIdentifier {
				UserDefaults.standard.removePersistentDomain(forName: bundleID)
			}
		}
		
		func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
			// Disable window restoration
			false
		}
		
		private func application(_ app: NSApplication, willEncodeRestorableState coder: NSCoder) -> Bool {
			// Don't encode any state
			false
		}
		
		func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
			// Don't reopen windows
			true
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
				}
//				else {
//					Text("No folder selected")
//						.foregroundStyle(.secondary)
//						.frame(minWidth: 400, minHeight: 300)
//				}
			}
			.defaultSize(width: 1200, height: 600)
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

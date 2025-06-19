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
			// Enable secure window restoration
			true
		}
		
		func applicationWillTerminate(_ notification: Notification) {
			// Clean up any security-scoped resources
			// This is handled automatically by BookmarkManager
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
		_ = BookmarkManager.shared
	}

	var body: some Scene {
		#if os(macOS)
			// Folder browser windows only - no default window
			WindowGroup("Photolala", for: URL.self) { $folderURL in
				if let folderURL {
					// Ensure we have access to the directory
					if let accessibleURL = ensureAccess(to: folderURL) {
						PhotoBrowserView(directoryPath: accessibleURL.path as NSString)
							.onAppear {
								// Save bookmark when window opens
								BookmarkManager.shared.saveBookmark(for: accessibleURL)
							}
					} else {
						FolderAccessDeniedView(folderURL: folderURL)
					}
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

#if os(macOS)
// Helper function to ensure access to a directory
@MainActor
private func ensureAccess(to url: URL) -> URL? {
	// First try to access directly (for newly selected folders)
	if FileManager.default.isReadableFile(atPath: url.path) {
		return url
	}
	
	// Try to restore access using bookmark
	if let restoredURL = BookmarkManager.shared.restoreAccess(to: url.path) {
		return restoredURL
	}
	
	// No access available
	return nil
}
#endif
//
//  PhotolalaApp.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/09.
//

import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if os(macOS)
	class AppDelegate: NSObject, NSApplicationDelegate {
		func applicationWillFinishLaunching(_ notification: Notification) {
			// Disable automatic window restoration
			UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
			
			// Clear any existing window restoration data
			if let bundleID = Bundle.main.bundleIdentifier {
				UserDefaults.standard.removePersistentDomain(forName: bundleID)
			}
			
			// Also disable window restoration at the app level
			NSApp.disableRelaunchOnLogin()
		}
		
		func applicationDidFinishLaunching(_ notification: Notification) {
			// Ensure no windows are restored
			NSApp.windows.forEach { window in
				if window.identifier?.rawValue.contains("NSWindow") == true {
					window.close()
				}
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
		_ = BackupQueueManager.shared
		
		// Note: BackupQueueManager automatically restores its cached data
		// from UserDefaults on init. Apple Photo backup status is now
		// stored in the SwiftData catalog.
		
		// Print cache root directory for debugging
		let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("com.electricwoods.photolala")
		print("[CacheManager] Cache root directory: \(cacheRoot.path)")
		
		// Perform cache migration if needed
		CacheManager.shared.performMigrationIfNeeded()
		
		// Configure Google Sign-In
		configureGoogleSignIn()
	}
	
	private func configureGoogleSignIn() {
		#if canImport(GoogleSignIn)
		// Web Client ID for server-side verification (same as Android)
		let webClientID = "105828093997-qmr9jdj3h4ia0tt2772cnrejh4k0p609.apps.googleusercontent.com"
		
		// Extract iOS client ID from Info.plist
		guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
			  let plist = NSDictionary(contentsOfFile: path),
			  let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]],
			  let urlSchemes = urlTypes.first?["CFBundleURLSchemes"] as? [String],
			  let reversedClientId = urlSchemes.first(where: { $0.hasPrefix("com.googleusercontent.apps.") }) else {
			print("[GoogleSignIn] Warning: Google Sign-In client ID not found in Info.plist")
			return
		}
		
		// Extract client ID from reversed client ID
		let components = reversedClientId.replacingOccurrences(of: "com.googleusercontent.apps.", with: "")
		let clientId = components + ".apps.googleusercontent.com"
		
		print("[GoogleSignIn] Configuring with client ID: \(clientId)")
		
		GIDSignIn.sharedInstance.configuration = GIDConfiguration(
			clientID: clientId,
			serverClientID: webClientID
		)
		#endif
	}
	

	var body: some Scene {
		#if os(macOS)
			// Folder browser windows only - no default window
			WindowGroup("Photolala", for: URL.self) { $folderURL in
				Group {
					if let folderURL {
						DirectoryPhotoBrowserView(directoryPath: folderURL.path as NSString)
							.environmentObject(IdentityManager.shared)
					}
//					else {
//						Text("No folder selected")
//							.foregroundStyle(.secondary)
//							.frame(minWidth: 400, minHeight: 300)
//					}
				}
				.onOpenURL { url in
					handleOpenURL(url)
				}
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
						.environmentObject(IdentityManager.shared)
				}
				.onOpenURL { url in
					handleOpenURL(url)
				}
			}
		#endif
	}
	
	private func handleOpenURL(_ url: URL) {
		#if canImport(GoogleSignIn)
		// Try Google Sign-In first
		Task {
			if await GoogleAuthProvider.shared.handle(url: url) {
				print("[GoogleSignIn] Handled URL callback")
				return
			}
		}
		#endif
		
		// Handle other URL schemes if needed
		print("[PhotolalaApp] Unhandled URL: \(url)")
	}
}

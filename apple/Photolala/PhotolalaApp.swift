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
			// The welcome window should open automatically from the main WindowGroup
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
			if !flag {
				// If no visible windows, open the welcome window
				if let welcomeCommand = NSApp.mainMenu?.item(withTitle: "Window")?.submenu?.item(withTitle: "Welcome") {
					NSApp.sendAction(welcomeCommand.action!, to: welcomeCommand.target, from: welcomeCommand)
				}
			}
			return true
		}
		
		func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
			// Prevent opening untitled windows
			return false
		}
	}
#endif

@main
struct PhotolalaApp: App {
	let photoManager = PhotoManager.shared

	#if os(macOS)
		@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	#elseif os(iOS)
		@UIApplicationDelegateAdaptor(AppDelegateiOS.self) var appDelegateiOS
	#endif

	init() {

		// Initialize managers
		_ = IdentityManager.shared
		_ = S3BackupManager.shared
		_ = BackupQueueManager.shared
		
		// Note: BackupQueueManager automatically restores its cached data
		// from UserDefaults on init. Apple Photo backup status is now
		// stored in the SwiftData catalog.
		
		
		// Perform cache migration if needed
		CacheManager.shared.performMigrationIfNeeded()
		
		// Configure Google Sign-In
		configureGoogleSignIn()
	}
	
	private func configureGoogleSignIn() {
		#if canImport(GoogleSignIn)
		GIDSignIn.sharedInstance.configuration = GIDConfiguration(
			clientID: GoogleOAuthConfiguration.clientID,
			serverClientID: GoogleOAuthConfiguration.webClientID
		)
		#endif
	}
	

	var body: some Scene {
		#if os(macOS)
			// Main window group - shows welcome screen by default
			WindowGroup {
				WelcomeView()
					.environmentObject(IdentityManager.shared)
					.frame(minWidth: 600, minHeight: 700)
					.onOpenURL { url in
						handleOpenURL(url)
					}
			}
			.windowResizability(.contentSize)
			.defaultSize(width: 600, height: 700)
			
			// Folder browser windows (for programmatic opening)
			WindowGroup("Folder Browser", for: URL.self) { $folderURL in
				Group {
					if let folderURL {
						DirectoryPhotoBrowserView(directoryPath: folderURL.path as NSString)
							.environmentObject(IdentityManager.shared)
					} else {
						// This should never show since we only open this programmatically
						EmptyView()
					}
				}
				.onOpenURL { url in
					handleOpenURL(url)
				}
			}
			.defaultSize(width: 1200, height: 600)
			.handlesExternalEvents(matching: [])
			
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
		// Check if this is a Google Sign-In callback
		if url.scheme?.hasPrefix("com.googleusercontent.apps") == true {
			
			#if os(macOS)
			// On macOS, we're using the web flow, so handle the callback manually
			Task {
				await GoogleAuthProvider.handleOAuthCallback(url)
			}
			return
			#else
			// On iOS, let the Google Sign-In SDK handle it
			if GIDSignIn.sharedInstance.handle(url) {
				return
			} else {
			}
			#endif
		}
		#endif
		
		// Handle other URL schemes if needed
	}
}

//
//  PhotoCommands.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/07/04.
//

import SwiftUI

// Helper struct to expose window commands to views
struct PhotoCommands {
	#if os(macOS)
	static func openApplePhotosLibrary() {
		// Close existing window if open
		if let existingWindow = PhotolalaCommands.applePhotosWindow {
			existingWindow.close()
		}
		
		// Open new window with Apple Photos Library
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
			styleMask: [.titled, .closable, .resizable, .miniaturizable],
			backing: .buffered,
			defer: false
		)
		
		window.title = "Apple Photos Library"
		window.center()
		window.contentView = NSHostingView(rootView: ApplePhotosBrowserView())
		
		// Set minimum and maximum window sizes
		window.minSize = NSSize(width: 800, height: 600)
		// No maximum size - allow unlimited resizing
		
		window.makeKeyAndOrderFront(nil)
		
		// Keep window in front but not floating
		window.level = .normal
		window.isReleasedWhenClosed = false
		
		// Store reference to keep window alive
		PhotolalaCommands.applePhotosWindow = window
	}
	
	static func openS3Browser() {
		#if DEBUG
		// Skip login check in debug mode
		#else
		// Check if user is signed in
		if !IdentityManager.shared.isSignedIn {
			// Show sign in prompt
			showSignIn()
			return
		}
		#endif
		
		// Close existing window if open
		if let existingWindow = PhotolalaCommands.cloudBrowserWindow {
			existingWindow.close()
		}
		
		// Open S3 browser window
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
			styleMask: [.titled, .closable, .resizable, .miniaturizable],
			backing: .buffered,
			defer: false
		)
		
		window.title = "Cloud Photos"
		window.center()
		window.contentView = NSHostingView(rootView: S3PhotoBrowserView())
		
		// Set minimum and maximum window sizes
		window.minSize = NSSize(width: 600, height: 400)
		// No maximum size - allow unlimited resizing
		
		window.makeKeyAndOrderFront(nil)
		
		// Keep window in front but not floating
		window.level = .normal
		window.isReleasedWhenClosed = false
		
		// Store reference to keep window alive
		PhotolalaCommands.cloudBrowserWindow = window
	}
	
	static func showSubscriptionView() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 1_000, height: 700),
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered,
			defer: false
		)

		window.title = "Manage Subscription"
		window.center()
		window.contentView = NSHostingView(rootView: SubscriptionView())
		window.makeKeyAndOrderFront(nil)

		// Keep window in front but not floating
		window.level = .normal
		window.isReleasedWhenClosed = false
	}
	
	static func showSignIn() {
		// Close existing window if open
		if let existingWindow = PhotolalaCommands.signInWindow {
			existingWindow.close()
		}
		
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		
		window.title = "Sign In to Photolala"
		window.center()
		window.contentView = NSHostingView(
			rootView: AuthenticationChoiceView()
				.environmentObject(IdentityManager.shared)
				.frame(width: 600, height: 700)
				.background(Color(NSColor.windowBackgroundColor))
		)
		window.makeKeyAndOrderFront(nil)
		
		// Keep window in front but not floating
		window.level = .normal
		window.isReleasedWhenClosed = false
		
		// Store reference to keep window alive
		PhotolalaCommands.signInWindow = window
	}
	#endif
}
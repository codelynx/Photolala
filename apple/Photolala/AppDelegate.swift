//
//  AppDelegate.swift
//  Photolala
//
//  Optional AppDelegate for additional control over app lifecycle
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
	private var isHandlingOAuthCallback = false

	func application(_ application: NSApplication, open urls: [URL]) {
		// Handle URLs opened via the app
		for url in urls {
			if url.scheme == "com.googleusercontent.apps.75309194504-g1a4hr3pc68301vuh21tibauh9ar1nkv" {
				// Mark that we're handling OAuth to prevent window creation
				isHandlingOAuthCallback = true

				// Handle Google OAuth callback
				GoogleSignInCoordinator.handleCallback(url)

				// Reset flag after a delay
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
					self?.isHandlingOAuthCallback = false
				}

				return
			}
		}
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		// Additional setup after app launch
		print("App launched successfully")
	}

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		// Don't create new window during OAuth callback
		if isHandlingOAuthCallback {
			return false
		}
		// If we have visible windows (like TestSignInView), don't create a new one
		return !flag
	}

	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		// Don't open untitled window during OAuth callback
		return !isHandlingOAuthCallback
	}
}
#else
class AppDelegate: UIResponder, UIApplicationDelegate {
	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
		// Handle URLs opened via the app
		if url.scheme == "com.googleusercontent.apps.75309194504-g1a4hr3pc68301vuh21tibauh9ar1nkv" {
			// Handle Google OAuth callback
			GoogleSignInCoordinator.handleCallback(url)
			return true
		}
		return false
	}

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Additional setup after app launch
		print("App launched successfully")
		return true
	}
}
#endif
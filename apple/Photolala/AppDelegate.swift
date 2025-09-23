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
		print("[AppDelegate] Received URLs: \(urls)")
		for url in urls {
			print("[AppDelegate] Processing URL: \(url.absoluteString)")
			print("[AppDelegate] URL scheme: \(url.scheme ?? "nil")")

			if url.scheme == GoogleOAuthConfiguration.urlScheme {
				print("[AppDelegate] ✓ Google OAuth callback detected")
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
		print("[AppDelegate] No matching OAuth URL scheme found")
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		// Additional setup after app launch
		print("App launched successfully")

		// Register for URL events
		NSAppleEventManager.shared().setEventHandler(
			self,
			andSelector: #selector(handleGetURLEvent(_:with:)),
			forEventClass: AEEventClass(kInternetEventClass),
			andEventID: AEEventID(kAEGetURL)
		)
		print("[AppDelegate] Registered for URL events")
	}

	@objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, with replyEvent: NSAppleEventDescriptor) {
		guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
		      let url = URL(string: urlString) else {
			print("[AppDelegate] Invalid URL in Apple Event")
			return
		}

		print("[AppDelegate] Received URL via Apple Event: \(url.absoluteString)")

		// Handle Google OAuth callback
		if url.scheme == GoogleOAuthConfiguration.urlScheme {
			print("[AppDelegate] ✓ Google OAuth callback detected via Apple Event")
			isHandlingOAuthCallback = true
			GoogleSignInCoordinator.handleCallback(url)

			// Reset flag after a delay
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
				self?.isHandlingOAuthCallback = false
			}
		}
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
		if url.scheme == GoogleOAuthConfiguration.urlScheme {
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
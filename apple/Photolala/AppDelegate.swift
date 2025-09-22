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
	func application(_ application: NSApplication, open urls: [URL]) {
		// Handle URLs opened via the app
		for url in urls {
			if url.scheme == "com.googleusercontent.apps.75309194504-g1a4hr3pc68301vuh21tibauh9ar1nkv" {
				// Handle Google OAuth callback
				GoogleSignInCoordinator.handleCallback(url)
			}
		}
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		// Additional setup after app launch
		print("App launched successfully")
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
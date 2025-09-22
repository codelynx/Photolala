//
//  PhotolalaApp.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/09/20.
//

import SwiftUI

@main
struct PhotolalaApp: App {
	// Use AppDelegate for proper URL handling on macOS
	#if os(macOS)
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	#else
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	#endif

	init() {
		print("=========================================")
		print("[App] Photolala starting...")
		print("[App] URL handler registered for Google OAuth")
		print("=========================================")
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.onOpenURL { url in
					print("[App] Received URL: \(url.absoluteString)")
					// Handle OAuth callbacks
					if url.scheme == "com.googleusercontent.apps.75309194504-g1a4hr3pc68301vuh21tibauh9ar1nkv" {
						print("[App] Google OAuth callback detected, handling...")
						Task {
							await GoogleSignInCoordinator.handleOAuthCallback(url)
						}
					} else {
						print("[App] Unknown URL scheme: \(url.scheme ?? "nil")")
					}
				}
		}
		#if os(macOS) && DEBUG
		.commands {
			DeveloperMenuCommands()
		}
		#endif
	}
}

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

	#if os(iOS)
	@State private var showBasketView = false
	#endif

	init() {
		print("=========================================")
		print("[App] Photolala starting...")
		print("[App] URL handler registered for Google OAuth")
		print("=========================================")
	}

	var body: some Scene {
		WindowGroup {
			HomeView()
				#if os(iOS)
				.portraitOnlyForiPhone()
				.sheet(isPresented: $showBasketView) {
					NavigationStack {
						PhotoBasketHostView()
					}
				}
				#endif
				#if os(macOS)
				.frame(minWidth: 600, minHeight: 700)
				#endif
			// OAuth callbacks are handled by AppDelegate
		}
		#if os(macOS)
		.handlesExternalEvents(matching: ["main"])  // Only open for main window events
		#endif
		.commands {
			#if os(macOS) && DEVELOPER
			DeveloperMenuCommands()
			#endif
			// Basket commands
			CommandGroup(after: .toolbar) {
				Button("Open Photo Basket") {
					#if os(macOS)
					PhotoWindowManager.shared.openBasketWindow()
					#else
					showBasketView = true
					#endif
				}
				.keyboardShortcut("b", modifiers: .command)

				Divider()

				Button("Clear Basket") {
					PhotoBasket.shared.clear()
				}
				.keyboardShortcut("b", modifiers: [.command, .shift])
				.disabled(PhotoBasket.shared.isEmpty)
			}
		}
	}
}

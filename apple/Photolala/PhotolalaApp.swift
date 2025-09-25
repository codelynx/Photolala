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

		// Create global catalog service for cloud operations
		let globalCatalogURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
			.appendingPathComponent("Photolala", isDirectory: true)
			.appendingPathComponent("GlobalCatalog", isDirectory: true)
		try? FileManager.default.createDirectory(at: globalCatalogURL, withIntermediateDirectories: true)

		// Configure BasketActionService with no services initially
		// Both catalog and S3 will be added after initialization
		BasketActionService.configure(s3Service: nil, catalogService: nil)
		print("[App] BasketActionService created with no services (will initialize async)")

		// Asynchronously initialize catalog and configure services
		Task { @MainActor in
			do {
				// Create and initialize global catalog
				let globalCatalogService = CatalogService(catalogDirectory: globalCatalogURL)
				try await globalCatalogService.initializeCatalog()
				print("[App] Global catalog initialized successfully")

				// Get S3 service
				let s3Service = try await S3Service.forCurrentAWSEnvironment()
				print("[App] S3Service initialized successfully")

				// Configure BasketActionService with both initialized services
				BasketActionService.configure(s3Service: s3Service, catalogService: globalCatalogService)
				print("[App] BasketActionService configured with initialized catalog and S3 services (cache sync will start automatically)")
			} catch {
				print("[App] Warning: Failed to initialize services: \(error)")
				// Star/unstar operations will not be available
			}
		}
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

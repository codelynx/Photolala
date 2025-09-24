//
//  PhotoWindowManager.swift
//  Photolala
//
//  Manages photo browser windows on macOS
//

#if os(macOS)
import AppKit
import SwiftUI
import Combine

@MainActor
class PhotoWindowManager {
	static let shared = PhotoWindowManager()

	private var windowControllers: [NSWindowController] = []
	private var observerTokens: [NSWindowController: NSObjectProtocol] = [:]

	private init() {}

	func openWindow(for url: URL) {

		// Create the photo source
		let source = LocalPhotoSource(directoryURL: url)
		let environment = PhotoBrowserEnvironment(source: source)

		// Create the content view with NavigationStack
		let contentView = NavigationStack {
			PhotoBrowserView(environment: environment, title: url.lastPathComponent)
				.navigationTitle(url.lastPathComponent)
				.navigationSubtitle(url.path)
		}

		// Create and configure window
		let window = createWindow(
			withTitle: url.lastPathComponent,
			contentView: AnyView(contentView)
		)

		// Create window controller
		let windowController = NSWindowController(window: window)
		windowControllers.append(windowController)

		// Clean up when window closes
		let token = NotificationCenter.default.addObserver(
			forName: NSWindow.willCloseNotification,
			object: window,
			queue: .main
		) { [weak self] _ in
			self?.cleanupWindowController(windowController)
		}
		observerTokens[windowController] = token

		// Show the window
		windowController.showWindow(nil)
		window.makeKeyAndOrderFront(nil)
	}

	func openApplePhotosWindow() {

		// Create Apple Photos source
		let source = ApplePhotosSource()
		let environment = PhotoBrowserEnvironment(source: source)

		// Create the content view with NavigationStack
		let contentView = NavigationStack {
			PhotoBrowserView(environment: environment, title: "Photos Library")
				.navigationTitle("Photos Library")
				.navigationSubtitle("Apple Photos")
		}

		// Create and configure window
		let window = createWindow(
			withTitle: "Photos Library",
			contentView: AnyView(contentView)
		)

		// Create window controller
		let windowController = NSWindowController(window: window)
		windowControllers.append(windowController)

		// Clean up when window closes
		let token = NotificationCenter.default.addObserver(
			forName: NSWindow.willCloseNotification,
			object: window,
			queue: .main
		) { [weak self] _ in
			self?.cleanupWindowController(windowController)
		}
		observerTokens[windowController] = token

		// Show the window
		windowController.showWindow(nil)
		window.makeKeyAndOrderFront(nil)
	}

	func openCloudPhotosWindow(environment: PhotoBrowserEnvironment) {
		// Create the content view with NavigationStack
		let contentView = NavigationStack {
			PhotoBrowserView(environment: environment, title: "Cloud Photos")
				.navigationTitle("Cloud Photos")
				.navigationSubtitle("Photolala Cloud")
		}

		// Create and configure window
		let window = createWindow(
			withTitle: "Cloud Photos",
			contentView: AnyView(contentView)
		)

		// Create window controller
		let windowController = NSWindowController(window: window)
		windowControllers.append(windowController)

		// Clean up when window closes
		let token = NotificationCenter.default.addObserver(
			forName: NSWindow.willCloseNotification,
			object: window,
			queue: .main
		) { [weak self] _ in
			self?.cleanupWindowController(windowController)
		}
		observerTokens[windowController] = token

		// Show the window
		windowController.showWindow(nil)
		window.makeKeyAndOrderFront(nil)
	}

	func openBasketWindow() {
		// Create basket photo source
		let source = BasketPhotoProvider()
		let environment = PhotoBrowserEnvironment(source: source)

		// Create the content view with NavigationStack
		let contentView = NavigationStack {
			PhotoBrowserView(environment: environment, title: "Photo Basket")
				.navigationTitle("Photo Basket")
				.navigationSubtitle("\(PhotoBasket.shared.count) items")
		}

		// Create and configure window
		let window = createWindow(
			withTitle: "Photo Basket",
			contentView: AnyView(contentView)
		)

		// Create window controller
		let windowController = NSWindowController(window: window)
		windowControllers.append(windowController)

		// Clean up when window closes
		let token = NotificationCenter.default.addObserver(
			forName: NSWindow.willCloseNotification,
			object: window,
			queue: .main
		) { [weak self] _ in
			self?.cleanupWindowController(windowController)
		}
		observerTokens[windowController] = token

		// Show the window
		windowController.showWindow(nil)
		window.makeKeyAndOrderFront(nil)
	}

	private func cleanupWindowController(_ windowController: NSWindowController) {
		// Remove observer token
		if let token = observerTokens[windowController] {
			NotificationCenter.default.removeObserver(token)
			observerTokens.removeValue(forKey: windowController)
		}

		// Remove window controller
		windowControllers.removeAll { $0 === windowController }
	}

	private func createWindow(withTitle title: String, contentView: AnyView) -> NSWindow {
		// Create the hosting controller
		let hostingController = NSHostingController(rootView: contentView)

		// Create the window
		let window = NSWindow(contentViewController: hostingController)
		window.setContentSize(NSSize(width: 900, height: 700))
		window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
		window.title = title
		window.center()

		// Set window properties
		window.minSize = NSSize(width: 600, height: 400)
		window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]

		// Enable toolbar
		window.titlebarAppearsTransparent = false
		window.titleVisibility = .visible
		window.toolbarStyle = .unified

		return window
	}
}
#endif
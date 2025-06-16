//
//  PhotolalaCommands.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI

struct PhotolalaCommands: Commands {
	@Environment(\.openWindow) private var openWindow

	var body: some Commands {
		// File menu customization
		CommandGroup(after: .newItem) {
			Button("Open Folder...") {
				self.openFolder()
			}
			.keyboardShortcut("O", modifiers: .command)

			Divider()
		}

		// Edit menu customization
		CommandGroup(after: .pasteboard) {
			Divider()

			Button("Select All") {
				// This will be handled by the standard menu implementation
			}
			.keyboardShortcut("A", modifiers: .command)

			Button("Deselect All") {
				// This will be handled by focused values in the view
				NotificationCenter.default.post(name: .deselectAll, object: nil)
			}
			.keyboardShortcut("D", modifiers: .command)
		}

		// View menu
		CommandMenu("View") {
			Button("Cache Statistics...") {
				#if os(macOS)
					self.showCacheStatistics()
				#endif
			}
			.keyboardShortcut("I", modifiers: [.command, .shift])

			Divider()

			Button("S3 Backup...") {
				#if os(macOS)
					self.showS3BackupTest()
				#endif
			}

			Button("Manage Subscription...") {
				#if os(macOS)
					self.showSubscriptionView()
				#endif
			}

			#if DEBUG
				Divider()

				Button("IAP Test...") {
					#if os(macOS)
						self.showIAPTest()
					#endif
				}
			#endif
		}

		// Window menu customization
		CommandGroup(replacing: .windowSize) {
			// Custom window commands if needed
		}

		// Help menu - Add to existing help menu
		CommandGroup(replacing: .help) {
			Button("Photolala Help") {
				self.showHelp()
			}
			.keyboardShortcut("?", modifiers: .command)

			Divider()
		}
	}

	private func openFolder() {
		#if os(macOS)
			let panel = NSOpenPanel()
			panel.canChooseFiles = false
			panel.canChooseDirectories = true
			panel.allowsMultipleSelection = false
			panel.message = "Select a folder to browse photos"
			panel.prompt = "Open"

			panel.begin { response in
				if response == .OK, let url = panel.url {
					print("[PhotolalaCommands] Opening folder: \(url.path)")
					// Open new window with the selected folder
					self.openWindow(value: url)
				}
			}
		#endif
	}

	#if os(macOS)
		private func showCacheStatistics() {
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
				styleMask: [.titled, .closable, .resizable],
				backing: .buffered,
				defer: false
			)

			window.title = "Cache Statistics"
			window.center()
			window.contentView = NSHostingView(rootView: CacheStatisticsView())
			window.makeKeyAndOrderFront(nil)

			// Keep window in front but not floating
			window.level = .normal
			window.isReleasedWhenClosed = false
		}

		private func showS3BackupTest() {
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 700, height: 800),
				styleMask: [.titled, .closable, .resizable],
				backing: .buffered,
				defer: false
			)

			window.title = "S3 Backup"
			window.center()
			window.contentView = NSHostingView(rootView: S3BackupTestView())
			window.makeKeyAndOrderFront(nil)

			// Keep window in front but not floating
			window.level = .normal
			window.isReleasedWhenClosed = false
		}

		private func showSubscriptionView() {
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

		private func showIAPTest() {
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
				styleMask: [.titled, .closable, .resizable],
				backing: .buffered,
				defer: false
			)

			window.title = "IAP Testing"
			window.center()
			window.contentView = NSHostingView(rootView: IAPTestView())
			window.makeKeyAndOrderFront(nil)

			// Keep window in front but not floating
			window.level = .normal
			window.isReleasedWhenClosed = false
		}
	#endif

	private func showHelp() {
		#if os(macOS)
			// Use a static variable to keep the help window controller alive
			enum HelpWindow {
				static var controller: HelpWindowController?
			}

			if HelpWindow.controller == nil {
				HelpWindow.controller = HelpWindowController()
			}
			HelpWindow.controller?.showHelp()
		#else
			// On iOS, we need to present it differently
			NotificationCenter.default.post(name: .showHelp, object: nil)
		#endif
	}
}

// MARK: - Notification Names

extension Notification.Name {
	static let deselectAll = Notification.Name("com.electricwoods.photolala.deselectAll")
	static let showHelp = Notification.Name("com.electricwoods.photolala.showHelp")
}

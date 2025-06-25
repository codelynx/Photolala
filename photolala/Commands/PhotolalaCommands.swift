//
//  PhotolalaCommands.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI

struct PhotolalaCommands: Commands {
	#if os(macOS)
	// Keep strong references to windows to prevent them from being deallocated
	static var applePhotosWindow: NSWindow?
	static var cloudBrowserWindow: NSWindow?
	static var cacheStatisticsWindow: NSWindow?
	static var s3BackupWindow: NSWindow?
	static var iapDeveloperWindow: NSWindow?
	#endif
	@Environment(\.openWindow) private var openWindow

	var body: some Commands {
		// File menu customization
		CommandGroup(after: .newItem) {
			Button("Open Folder...") {
				self.openFolder()
			}
			.keyboardShortcut("O", modifiers: .command)
			
			#if os(macOS)
			Button("Open Apple Photos Library") {
				self.openApplePhotosLibrary()
			}
			.keyboardShortcut("L", modifiers: [.command, .shift])
			#endif

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

		// Add to existing View menu instead of creating a new one
		CommandGroup(after: .toolbar) {
			Divider()
			
			Button("Show Inspector") {
				// Post notification to toggle inspector
				NotificationCenter.default.post(name: .toggleInspector, object: nil)
			}
			.keyboardShortcut("I", modifiers: .command)
			
			Divider()
			
			Button("Show Cache Statistics...") {
				#if os(macOS)
					self.showCacheStatistics()
				#endif
			}
			.keyboardShortcut("I", modifiers: [.command, .shift])
		}
		
		// Create a new Photolala menu for app-specific features
		CommandMenu("Photolala") {
			Button("Manage Subscription...") {
				#if os(macOS)
					self.showSubscriptionView()
				#endif
			}
			
			Divider()
			
			Button("Cloud Backup Settings...") {
				#if os(macOS)
					self.showS3BackupTest()
				#endif
			}
			// .disabled(!FeatureFlags.isS3BackupEnabled) // Coming soon
			
			#if DEBUG
			Divider()
			
			Menu("Developer Tools") {
				Button("IAP Developer Tools...") {
					#if os(macOS)
						self.showIAPDeveloper()
					#endif
				}
				
				Divider()
				
				Button("Reveal Cache Folder in Finder") {
					self.revealCacheFolder()
				}
				.keyboardShortcut("R", modifiers: [.command, .option])
				
				Button("Log Cache Contents") {
					self.logCacheContents()
				}
				
				Divider()
				
				Button("Clear All Caches") {
					self.clearAllCaches()
				}
				
				Button("Clear Local Caches") {
					self.clearLocalCaches()
				}
				
				Button("Clear Cloud Caches") {
					self.clearCloudCaches()
				}
			}
			#endif
		}

		// Window menu customization
		CommandGroup(replacing: .windowSize) {
			// Custom window commands if needed
		}
		
		// Add special browsers to Window menu
		#if os(macOS)
		CommandGroup(before: .windowList) {
			Button("Apple Photos Library") {
				self.openApplePhotosLibrary()
			}
			.keyboardShortcut("L", modifiers: [.command, .option])
			
			Button("Cloud Browser") {
				self.openS3Browser()
			}
			.keyboardShortcut("B", modifiers: [.command, .option])
			
			Divider()
		}
		#endif

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
	
	private func openApplePhotosLibrary() {
		#if os(macOS)
			// Close existing window if open
			if let existingWindow = Self.applePhotosWindow {
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
			Self.applePhotosWindow = window
		#endif
	}
	
	private func openS3Browser() {
		#if os(macOS)
			#if DEBUG
			// Skip login check in debug mode
			#else
			// TEMPORARY: Skip login check for S3 testing
			// TODO: Uncomment this block for production
			/*
			// Check if user is signed in
			if !IdentityManager.shared.isSignedIn {
				// Show sign in prompt
				let window = NSWindow(
					contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
					styleMask: [.titled, .closable],
					backing: .buffered,
					defer: false
				)
				
				window.title = "Sign In Required"
				window.center()
				window.contentView = NSHostingView(rootView: SignInPromptView())
				window.makeKeyAndOrderFront(nil)
				return
			}
			*/
			#endif
			
			// Close existing window if open
			if let existingWindow = Self.cloudBrowserWindow {
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
			Self.cloudBrowserWindow = window
		#endif
	}

	#if os(macOS)
		private func showCacheStatistics() {
			// Close existing window if open
			if let existingWindow = Self.cacheStatisticsWindow {
				existingWindow.close()
			}
			
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
			
			// Store reference to keep window alive
			Self.cacheStatisticsWindow = window
		}

		private func showS3BackupTest() {
			// TODO: S3BackupTestView was removed - implement proper S3 backup UI if needed
			print("S3 Backup test view has been removed")
			
			// Temporary: Show alert instead
			let alert = NSAlert()
			alert.messageText = "S3 Backup Test"
			alert.informativeText = "The S3 backup test view has been removed. This functionality needs to be reimplemented."
			alert.runModal()
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

		private func showIAPDeveloper() {
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
				styleMask: [.titled, .closable, .resizable, .miniaturizable],
				backing: .buffered,
				defer: false
			)

			window.title = "IAP Developer Tools"
			window.center()
			window.contentView = NSHostingView(rootView: IAPDeveloperView())
			window.makeKeyAndOrderFront(nil)

			// Keep window in front but not floating
			window.level = .normal
			window.isReleasedWhenClosed = false
			
			// Force title to be shown
			window.titleVisibility = .visible
			window.titlebarAppearsTransparent = false
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
	
	// MARK: - Cache Management
	
	private func revealCacheFolder() {
		#if os(macOS)
		let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("com.electricwoods.photolala")
		
		// Create directory if it doesn't exist
		try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
		
		// Open in Finder
		NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: cacheRoot.path)
		
		print("[Cache] Revealed cache folder: \(cacheRoot.path)")
		#endif
	}
	
	private func clearAllCaches() {
		do {
			// Clear memory caches
			PhotoManager.shared.clearAllCaches()
			
			// Clear all disk caches using CacheManager
			try CacheManager.shared.clearAllCaches()
			
			print("[Cache] All caches cleared")
			self.showCacheClearedAlert(message: "All caches have been cleared")
		} catch {
			print("[Cache] Failed to clear caches: \(error)")
			self.showCacheClearedAlert(message: "Failed to clear some caches: \(error.localizedDescription)")
		}
	}
	
	private func clearLocalCaches() {
		do {
			// Clear memory caches
			PhotoManager.shared.clearAllCaches()
			
			// Clear local disk caches using CacheManager
			try CacheManager.shared.clearLocalCaches()
			
			print("[Cache] Local caches cleared")
			self.showCacheClearedAlert(message: "Local caches have been cleared")
		} catch {
			print("[Cache] Failed to clear local caches: \(error)")
			self.showCacheClearedAlert(message: "Failed to clear local caches: \(error.localizedDescription)")
		}
	}
	
	private func clearCloudCaches() {
		do {
			// Clear cloud caches using CacheManager
			try CacheManager.shared.clearCloudCaches(for: .s3)
			
			print("[Cache] Cloud caches cleared")
			self.showCacheClearedAlert(message: "Cloud caches have been cleared")
		} catch {
			print("[Cache] Failed to clear cloud caches: \(error)")
			self.showCacheClearedAlert(message: "Failed to clear cloud caches: \(error.localizedDescription)")
		}
	}
	
	private func clearCloudCacheDirectory() {
		let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
			.appendingPathComponent("com.electricwoods.photolala")
			.appendingPathComponent("cloud.s3")
		
		do {
			if FileManager.default.fileExists(atPath: cacheURL.path) {
				try FileManager.default.removeItem(at: cacheURL)
				print("[PhotolalaCommands] Cleared cloud cache at: \(cacheURL.path)")
			}
		} catch {
			print("[PhotolalaCommands] Failed to clear cloud cache: \(error)")
		}
	}
	
	private func clearCatalogCache() {
		// Clear .photolala directories in Library/Caches/Photolala
		let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
			.appendingPathComponent("Photolala")
		
		do {
			let contents = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
			for item in contents {
				if item.lastPathComponent == ".photolala" {
					try FileManager.default.removeItem(at: item)
					print("[PhotolalaCommands] Removed catalog cache: \(item.path)")
				}
			}
		} catch {
			print("[PhotolalaCommands] Failed to clear catalog cache: \(error)")
		}
	}
	
	private func showCacheClearedAlert(message: String) {
		#if os(macOS)
		DispatchQueue.main.async {
			let alert = NSAlert()
			alert.messageText = "Cache Cleared"
			alert.informativeText = message
			alert.alertStyle = .informational
			alert.addButton(withTitle: "OK")
			alert.runModal()
		}
		#endif
	}
	
	private func logCacheContents() {
		print("\n=== CACHE CONTENTS ===\n")
		
		// Memory Cache Info
		print("📱 MEMORY CACHES:")
		print(PhotoManager.shared.getCacheInfo())
		
		// Overall cache info
		print("\n📊 CACHE SIZES:")
		let totalSize = CacheManager.shared.cacheSize()
		let localSize = CacheManager.shared.localCacheSize()
		let cloudSize = CacheManager.shared.cloudCacheSize(for: .s3)
		print("  Total cache: \(formatBytes(totalSize))")
		print("  Local cache: \(formatBytes(localSize))")
		print("  Cloud cache (S3): \(formatBytes(cloudSize))")
		
		// Local Thumbnail Cache (new structure)
		print("\n💾 LOCAL THUMBNAIL CACHE:")
		let localThumbnailPath = CacheManager.shared.localThumbnailURL(for: "dummy").deletingLastPathComponent()
		self.logDirectoryContents(at: localThumbnailPath, prefix: "  ")
		
		// Legacy cache check
		if CacheManager.shared.hasLegacyCaches() {
			print("\n⚠️ LEGACY CACHES DETECTED:")
			if let legacyLocal = CacheManager.shared.legacyLocalThumbnailDirectory() {
				print("  Legacy local: \(legacyLocal.path)")
			}
			if let legacyS3 = CacheManager.shared.legacyS3ThumbnailDirectory() {
				print("  Legacy S3 thumbnails: \(legacyS3.path)")
			}
			if let legacyCatalog = CacheManager.shared.legacyS3CatalogDirectory() {
				print("  Legacy S3 catalog: \(legacyCatalog.path)")
			}
		}
		
		// Cloud S3 Cache (new structure)
		print("\n☁️ CLOUD S3 CACHE:")
		let rootURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
			.appendingPathComponent("com.electricwoods.photolala")
			.appendingPathComponent("cloud")
			.appendingPathComponent("s3")
		self.logDirectoryContents(at: rootURL, prefix: "  ", showSize: true)
		
		print("\n=== END CACHE CONTENTS ===\n")
	}
	
	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
	
	private func logDirectoryContents(at url: URL, prefix: String = "", showSize: Bool = false) {
		do {
			if !FileManager.default.fileExists(atPath: url.path) {
				print("\(prefix)Directory does not exist")
				return
			}
			
			let contents = try FileManager.default.contentsOfDirectory(at: url, 
				includingPropertiesForKeys: showSize ? [.fileSizeKey, .isDirectoryKey] : [.isDirectoryKey], 
				options: [.skipsHiddenFiles])
			
			if contents.isEmpty {
				print("\(prefix)Empty")
				return
			}
			
			var totalSize: Int64 = 0
			var fileCount = 0
			var dirCount = 0
			
			for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
				let values = try item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
				
				if values.isDirectory == true {
					dirCount += 1
					print("\(prefix)📁 \(item.lastPathComponent)/")
				} else {
					fileCount += 1
					if showSize, let size = values.fileSize {
						totalSize += Int64(size)
						let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
						print("\(prefix)📄 \(item.lastPathComponent) (\(sizeStr))")
					} else {
						print("\(prefix)📄 \(item.lastPathComponent)")
					}
				}
			}
			
			print("\(prefix)Total: \(fileCount) files, \(dirCount) directories", terminator: "")
			if showSize && totalSize > 0 {
				let totalSizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
				print(" (\(totalSizeStr))")
			} else {
				print()
			}
			
		} catch {
			print("\(prefix)Error reading directory: \(error.localizedDescription)")
		}
	}
	
	private func logCatalogContents(at url: URL, prefix: String = "") {
		do {
			let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
			var catalogCount = 0
			
			for item in contents where item.lastPathComponent == ".photolala" {
				catalogCount += 1
				print("\(prefix)📁 \(item.deletingLastPathComponent().lastPathComponent)/.photolala")
				
				// Count files in catalog
				if let catalogContents = try? FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
					print("\(prefix)  └─ \(catalogContents.count) files")
				}
			}
			
			if catalogCount == 0 {
				print("\(prefix)No catalog directories found")
			} else {
				print("\(prefix)Total: \(catalogCount) catalogs")
			}
			
		} catch {
			print("\(prefix)Error reading directory: \(error.localizedDescription)")
		}
	}
	
}

// MARK: - Notification Names

extension Notification.Name {
	static let deselectAll = Notification.Name("com.electricwoods.photolala.deselectAll")
	static let showHelp = Notification.Name("com.electricwoods.photolala.showHelp")
	static let toggleInspector = Notification.Name("com.electricwoods.photolala.toggleInspector")
}

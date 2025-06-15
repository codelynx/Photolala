//
//  PhotoCollectionViewController.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI
import Observation
#if os(macOS)
import AppKit
import Quartz
#else
import UIKit
#endif

// MARK: - PhotoCollectionViewController

class PhotoCollectionViewController: XViewController {
	let directoryPath: NSString
	weak var settings: ThumbnailDisplaySettings?
	private var lastSortOption: PhotoSortOption?

	@MainActor
	var photos: [PhotoReference] = []
	@MainActor
	var photoGroups: [PhotoGroup] = []
	var onSelectPhoto: ((PhotoReference, [PhotoReference]) -> Void)?
	var onSelectFolder: ((PhotoReference) -> Void)?
	var onPhotosLoadedWithReferences: (([PhotoReference]) -> Void)?
	var onSelectionChanged: (([PhotoReference]) -> Void)?
	
	var collectionView: XCollectionView!
	
	#if os(macOS)
	var clickedCollectionView: ClickedCollectionView? {
		return collectionView as? ClickedCollectionView
	}
	#endif
	
	#if os(macOS)
	private var quickLookPhotos: [PhotoReference] = []
	#endif
	
	// Get currently selected photos
	var selectedPhotos: [PhotoReference] {
		#if os(macOS)
		return collectionView.selectionIndexPaths.compactMap { indexPath in
			guard indexPath.section < photoGroups.count,
				  indexPath.item < photoGroups[indexPath.section].photos.count else { return nil }
			return photoGroups[indexPath.section].photos[indexPath.item]
		}
		#else
		return collectionView.indexPathsForSelectedItems?.compactMap { indexPath in
			guard indexPath.section < photoGroups.count,
				  indexPath.item < photoGroups[indexPath.section].photos.count else { return nil }
			return photoGroups[indexPath.section].photos[indexPath.item]
		} ?? []
		#endif
	}
	
	#if os(iOS)
	var onPhotosLoaded: ((Int) -> Void)?
	#endif
	
	init(directoryPath: NSString) {
		self.directoryPath = directoryPath
		super.init(nibName: nil, bundle: nil)
		self.title = directoryPath.lastPathComponent
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	// MARK: - View Lifecycle
	
#if os(macOS)
	override func loadView() {
		// Create the main view
		view = NSView()
		view.wantsLayer = true
		
		// Create collection view
		let scrollView = NSScrollView()
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.borderType = .noBorder
		scrollView.hasVerticalScroller = true
		scrollView.hasHorizontalScroller = false
		scrollView.autohidesScrollers = true
		
		let collectionView = ClickedCollectionView()
		collectionView.collectionViewLayout = createLayout()
		collectionView.delegate = self
		collectionView.dataSource = self
		collectionView.prefetchDataSource = self
		collectionView.isSelectable = true
		collectionView.allowsMultipleSelection = true
		collectionView.backgroundColors = [.clear]
		
		// Register item
		collectionView.register(PhotoCollectionViewItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("PhotoItem"))
		
		scrollView.documentView = collectionView
		self.collectionView = collectionView
		
		// Set up context menu
		setupContextMenu()
		
		view.addSubview(scrollView)
		
		// Constraints
		NSLayoutConstraint.activate([
			scrollView.topAnchor.constraint(equalTo: view.topAnchor),
			scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		loadPhotos()
		setupSettingsObserver()
		setupToolbar()
		
		// Listen for deselect all notification
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleDeselectAll),
			name: .deselectAll,
			object: nil
		)
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		// Make collection view first responder for keyboard events
		view.window?.makeFirstResponder(collectionView)
	}
	
	override var acceptsFirstResponder: Bool {
		return true
	}
	
	private func createLayout() -> NSCollectionViewLayout {
		let flowLayout = NSCollectionViewFlowLayout()
		let thumbnailOption = settings?.thumbnailOption ?? .default
		let cellSize = thumbnailOption.size
		
		flowLayout.itemSize = NSSize(width: cellSize, height: cellSize)
		flowLayout.sectionInset = NSEdgeInsets(
			top: thumbnailOption.sectionInset,
			left: thumbnailOption.sectionInset,
			bottom: thumbnailOption.sectionInset,
			right: thumbnailOption.sectionInset
		)
		flowLayout.minimumInteritemSpacing = thumbnailOption.spacing
		flowLayout.minimumLineSpacing = thumbnailOption.spacing
		return flowLayout
	}
#else
	override func viewDidLoad() {
		super.viewDidLoad()
		setupCollectionView()
		loadPhotos()
		setupSettingsObserver()
		setupToolbar()
		
		// Listen for deselect all notification
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleDeselectAll),
			name: .deselectAll,
			object: nil
		)
	}
	
	private func setupCollectionView() {
		let layout = UICollectionViewFlowLayout()
		let thumbnailOption = settings?.thumbnailOption ?? .default
		let cellSize = thumbnailOption.size
		
		layout.itemSize = CGSize(width: cellSize, height: cellSize)
		layout.sectionInset = UIEdgeInsets(
			top: thumbnailOption.sectionInset,
			left: thumbnailOption.sectionInset,
			bottom: thumbnailOption.sectionInset,
			right: thumbnailOption.sectionInset
		)
		layout.minimumInteritemSpacing = thumbnailOption.spacing
		layout.minimumLineSpacing = thumbnailOption.spacing
		
		collectionView = XCollectionView(frame: view.bounds, collectionViewLayout: layout)
		collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		collectionView.backgroundColor = .systemBackground
		collectionView.dataSource = self
		collectionView.delegate = self
		collectionView.prefetchDataSource = self
		collectionView.allowsMultipleSelection = true
		
		collectionView.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
		
		// Add double-tap gesture recognizer for navigation
		let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
		doubleTapGesture.numberOfTapsRequired = 2
		collectionView.addGestureRecognizer(doubleTapGesture)
		
		view.addSubview(collectionView)
	}
	
#endif
	
	@MainActor
	func reloadData() {
		// Preserve selection when reloading
		#if os(iOS)
		let selectedPaths = collectionView.indexPathsForSelectedItems ?? []
		#else
		let selectedPaths = collectionView.selectionIndexPaths
		#endif
		
		collectionView.reloadData()
		
		// Restore selection
		#if os(iOS)
		for indexPath in selectedPaths {
			collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
		}
		#else
		collectionView.selectionIndexPaths = selectedPaths
		#endif
	}
	
	// MARK: - Private Methods
	
	private func loadPhotos() {
		Task { @MainActor in
			// Use DirectoryScanner to get PhotoReference objects
			let scannedPhotos = DirectoryScanner.scanDirectory(atPath: directoryPath)
			
			// Apply sorting based on current settings
			let sortedPhotos = settings?.sortOption.sort(scannedPhotos) ?? scannedPhotos
			self.photos = sortedPhotos
			
			// Apply grouping based on current settings
			let groupingOption = settings?.groupingOption ?? .none
			self.photoGroups = PhotoManager.shared.groupPhotos(sortedPhotos, by: groupingOption)
			
			self.reloadData()
			
			// Notify SwiftUI about photos loaded
			#if os(iOS)
			self.onPhotosLoaded?(self.photos.count)
			#endif
			self.onPhotosLoadedWithReferences?(self.photos)
			
			// No need for metadata loading - we're using file dates only
		}
	}
	
	
	private func moveItem(from oldIndex: Int, to newIndex: Int) {
		#if os(macOS)
		collectionView.performBatchUpdates({
			let oldIndexPath = IndexPath(item: oldIndex, section: 0)
			let newIndexPath = IndexPath(item: newIndex, section: 0)
			collectionView.moveItem(at: oldIndexPath, to: newIndexPath)
		}, completionHandler: nil)
		#else
		collectionView.performBatchUpdates({
			let oldIndexPath = IndexPath(item: oldIndex, section: 0)
			let newIndexPath = IndexPath(item: newIndex, section: 0)
			collectionView.moveItem(at: oldIndexPath, to: newIndexPath)
		}, completion: nil)
		#endif
	}
	
	private func applySorting() {
		guard let settings = settings else { return }
		
		// Apply the new sort using file system dates only
		photos = settings.sortOption.sort(photos)
		reloadData()
	}
	
	private func setupSettingsObserver() {
		// Observe settings changes when settings object is available
		guard let settings = settings else { return }
		
		withObservationTracking {
			_ = settings.displayMode
			_ = settings.thumbnailSize
			_ = settings.sortOption
			_ = settings.groupingOption
		} onChange: { [weak self] in
			Task { @MainActor in
				let oldSortOption = self?.lastSortOption
				let newSortOption = settings.sortOption
				
				// If sort option or grouping changed, reload photos
				if oldSortOption != newSortOption || self?.photoGroups.isEmpty == true {
					self?.lastSortOption = newSortOption
					self?.loadPhotos()
				} else {
					// Otherwise just update layout
					self?.updateCollectionViewLayout()
				}
				self?.setupSettingsObserver() // Re-subscribe
			}
		}
	}
	
	func updateCollectionViewLayout() {
		guard let settings = settings else { return }
		
		let thumbnailOption = settings.thumbnailOption
		let cellSize = thumbnailOption.size
		
		#if os(macOS)
		if let flowLayout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
			flowLayout.itemSize = NSSize(width: cellSize, height: cellSize)
			flowLayout.sectionInset = NSEdgeInsets(
				top: thumbnailOption.sectionInset,
				left: thumbnailOption.sectionInset,
				bottom: thumbnailOption.sectionInset,
				right: thumbnailOption.sectionInset
			)
			flowLayout.minimumInteritemSpacing = thumbnailOption.spacing
			flowLayout.minimumLineSpacing = thumbnailOption.spacing
			
			// Update all visible items
			for item in collectionView.visibleItems() {
				if let photoItem = item as? PhotoCollectionViewItem {
					photoItem.settings = settings
					photoItem.updateDisplayMode()
					photoItem.updateCornerRadius()
				}
			}
		}
		#else
		if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
			flowLayout.itemSize = CGSize(width: cellSize, height: cellSize)
			flowLayout.sectionInset = UIEdgeInsets(
				top: thumbnailOption.sectionInset,
				left: thumbnailOption.sectionInset,
				bottom: thumbnailOption.sectionInset,
				right: thumbnailOption.sectionInset
			)
			flowLayout.minimumInteritemSpacing = thumbnailOption.spacing
			flowLayout.minimumLineSpacing = thumbnailOption.spacing
			
			// Update all visible cells
			for cell in collectionView.visibleCells {
				if let photoCell = cell as? PhotoCollectionViewCell {
					photoCell.settings = settings
					photoCell.updateDisplayMode()
					photoCell.updateCornerRadius()
				}
			}
		}
		#endif
		
		// Don't reload data as it clears selection - layout update is sufficient
		#if os(macOS)
		collectionView.collectionViewLayout?.invalidateLayout()
		#else
		collectionView.collectionViewLayout.invalidateLayout()
		#endif
	}
	
	private func setupToolbar() {
		// Toolbar is now handled by SwiftUI in PhotoBrowserView
	}
	
	@objc private func toggleDisplayMode() {
		guard let settings = settings else { return }
		settings.displayMode = settings.displayMode == .scaleToFit ? .scaleToFill : .scaleToFit
	}
	
	@objc private func handleDeselectAll() {
		#if os(macOS)
		// Clear native collection view selection
		collectionView.deselectAll(nil)
		#else
		// Deselect all items in collection view
		for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
			collectionView.deselectItem(at: indexPath, animated: true)
		}
		#endif
	}
	
	// MARK: - iOS Specific
	
	#if os(iOS)
	
	@objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
		let location = gesture.location(in: collectionView)
		if let indexPath = collectionView.indexPathForItem(at: location) {
			// Navigate to photo preview on double-tap
			handleNavigation(at: indexPath)
		}
	}
	#endif
	
	// MARK: - Navigation
	
	func handleNavigation(at indexPath: IndexPath) {
		guard indexPath.section < photoGroups.count,
			  indexPath.item < photoGroups[indexPath.section].photos.count else { return }
			  
		let photo = photoGroups[indexPath.section].photos[indexPath.item]
		let photoURL = photo.fileURL
		
		print("[PhotoCollectionViewController] handleNavigation called for: \(photo.filename)")
		
		// Check if it's a directory
		var isDirectory: ObjCBool = false
		if FileManager.default.fileExists(atPath: photoURL.path, isDirectory: &isDirectory) {
			if isDirectory.boolValue {
				print("[PhotoCollectionViewController] It's a directory, calling onSelectFolder")
				onSelectFolder?(photo)
			} else {
				print("[PhotoCollectionViewController] It's a photo, calling onSelectPhoto")
				onSelectPhoto?(photo, photos)
			}
		}
	}
	
}

// MARK: - Data Source

extension PhotoCollectionViewController: XCollectionViewDataSource {
	
	#if os(macOS)
	func numberOfSections(in collectionView: NSCollectionView) -> Int {
		return photoGroups.isEmpty ? 0 : photoGroups.count
	}
	#else
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return photoGroups.isEmpty ? 0 : photoGroups.count
	}
	#endif

	func collectionView(_ collectionView: XCollectionView, numberOfItemsInSection section: Int) -> Int {
		guard section < photoGroups.count else { return 0 }
		return photoGroups[section].photos.count
	}
	
	#if os(macOS)
	func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
		let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("PhotoItem"), for: indexPath) as! PhotoCollectionViewItem
		guard indexPath.section < photoGroups.count,
			  indexPath.item < photoGroups[indexPath.section].photos.count else {
			return item
		}
		let photo = photoGroups[indexPath.section].photos[indexPath.item]
		item.settings = settings
		item.photoRepresentation = photo
		item.updateDisplayMode()
		item.updateCornerRadius()
		return item
	}
	#endif

	#if os(iOS)
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCollectionViewCell
		guard indexPath.section < photoGroups.count,
			  indexPath.item < photoGroups[indexPath.section].photos.count else {
			return cell
		}
		let photo = photoGroups[indexPath.section].photos[indexPath.item]
		
		cell.settings = settings
		cell.photoRepresentation = photo
		cell.updateCornerRadius()
		
		// UICollectionView manages selection, but we need to sync when cells are reused
		let selectedPaths = collectionView.indexPathsForSelectedItems ?? []
		let shouldBeSelected = selectedPaths.contains(indexPath)
		if shouldBeSelected != cell.isSelected {
			cell.isSelected = shouldBeSelected
		}
		
		return cell
	}
	#endif

}

// MARK: - Delegate

extension PhotoCollectionViewController: XCollectionViewDelegate {
//	internal func collectionView(_ collectionView: XCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
//		// Handle selection
//	}
	
	#if os(macOS)
	override func mouseDown(with event: NSEvent) {
		print("[PhotoCollectionViewController] mouseDown called, clickCount: \(event.clickCount)")
		
		let locationInView = view.convert(event.locationInWindow, from: nil)
		let locationInCollectionView = collectionView.convert(locationInView, from: view)
		
		if let indexPath = collectionView.indexPathForItem(at: locationInCollectionView) {
			// Double-click: navigate
			if event.clickCount == 2 {
				print("[PhotoCollectionViewController] Double-click on item at indexPath: \(indexPath)")
				handleNavigation(at: indexPath)
				return
			}
			
			// Single click: check for toggle behavior
			if event.clickCount == 1 && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) {
				// If item is already selected, deselect it (toggle behavior)
				if collectionView.selectionIndexPaths.contains(indexPath) {
					collectionView.deselectItems(at: Set([indexPath]))
					// The delegate method will be called automatically
					return
				}
			}
		}
		
		// For other cases (Cmd+click, Shift+click, or selecting new item), let the collection view handle it
		super.mouseDown(with: event)
	}
	
	override func keyDown(with event: NSEvent) {
		// Check for Return/Enter key
		if event.keyCode == 36 { // Return key
			// Get the first selected item
			if let indexPath = collectionView.selectionIndexPaths.first {
				handleNavigation(at: indexPath)
				return
			}
		}
		// Let NSCollectionView handle other keys (arrows, etc.)
		super.keyDown(with: event)
	}
	
	// MARK: - Context Menu
	
	private func setupContextMenu() {
		// Create a placeholder menu that will be dynamically updated
		let menu = NSMenu()
		menu.delegate = self
		collectionView.menu = menu
	}
	
	
	private func createOpenWithMenu(for photo: PhotoReference) -> NSMenu {
		let menu = NSMenu()
		
		// Get applications that can open this file
		let fileURL = photo.fileURL
		let apps = LSCopyApplicationURLsForURL(fileURL as CFURL, .all)?.takeRetainedValue() as? [URL] ?? []
		
		// Get default app
		let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: fileURL)
		
		// Add default app first if available
		if let defaultApp = defaultApp {
			let appName = FileManager.default.displayName(atPath: defaultApp.path)
			let defaultItem = NSMenuItem(title: "\(appName) (default)", action: #selector(contextMenuOpenWith(_:)), keyEquivalent: "")
			defaultItem.target = self
			defaultItem.representedObject = (photo, defaultApp)
			menu.addItem(defaultItem)
			menu.addItem(.separator())
		}
		
		// Add other apps
		for appURL in apps {
			if appURL != defaultApp {
				let appName = FileManager.default.displayName(atPath: appURL.path)
				let item = NSMenuItem(title: appName, action: #selector(contextMenuOpenWith(_:)), keyEquivalent: "")
				item.target = self
				item.representedObject = (photo, appURL)
				menu.addItem(item)
			}
		}
		
		if menu.items.isEmpty {
			let noAppsItem = NSMenuItem(title: "No Applications", action: nil, keyEquivalent: "")
			noAppsItem.isEnabled = false
			menu.addItem(noAppsItem)
		}
		
		return menu
	}
	
	// MARK: - Context Menu Actions
	
	@objc private func contextMenuOpen(_ sender: NSMenuItem) {
		guard let photos = sender.representedObject as? [PhotoReference],
			  let firstPhoto = photos.first else { return }
		
		// Find the photo in our groups
		for (sectionIndex, group) in photoGroups.enumerated() {
			if let itemIndex = group.photos.firstIndex(of: firstPhoto) {
				let indexPath = IndexPath(item: itemIndex, section: sectionIndex)
				handleNavigation(at: indexPath)
				return
			}
		}
	}
	
	@objc private func contextMenuQuickLook(_ sender: NSMenuItem) {
		guard let photos = sender.representedObject as? [PhotoReference] else { return }
		
		// Import QuickLook
		if #available(macOS 10.15, *) {
			let panel = QLPreviewPanel.shared()
			panel?.dataSource = self
			panel?.delegate = self
			
			// Store photos for Quick Look
			self.quickLookPhotos = photos
			
			if panel?.isVisible == true {
				panel?.reloadData()
			} else {
				panel?.makeKeyAndOrderFront(nil)
			}
		}
	}
	
	@objc private func contextMenuOpenWith(_ sender: NSMenuItem) {
		guard let (photo, appURL) = sender.representedObject as? (PhotoReference, URL) else { return }
		
		NSWorkspace.shared.open([photo.fileURL], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
	}
	
	@objc private func contextMenuRevealInFinder(_ sender: NSMenuItem) {
		guard let photos = sender.representedObject as? [PhotoReference] else { return }
		
		if photos.count == 1 {
			NSWorkspace.shared.selectFile(photos[0].filePath, inFileViewerRootedAtPath: "")
		} else {
			// Reveal multiple files
			NSWorkspace.shared.activateFileViewerSelecting(photos.map { URL(fileURLWithPath: $0.filePath) })
		}
	}
	
	@objc private func contextMenuGetInfo(_ sender: NSMenuItem) {
		guard let photos = sender.representedObject as? [PhotoReference] else { return }
		
		// Open info panel for each photo
		for photo in photos {
			NSWorkspace.shared.activateFileViewerSelecting([photo.fileURL])
			
			// Use AppleScript to open Get Info
			let script = """
			tell application "Finder"
				activate
				open information window of (POSIX file "\(photo.filePath)" as alias)
			end tell
			"""
			
			if let appleScript = NSAppleScript(source: script) {
				var error: NSDictionary?
				appleScript.executeAndReturnError(&error)
			}
		}
	}
	#endif

	#if os(macOS)
	func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
		// Update visual state
		for indexPath in indexPaths {
			if let item = collectionView.item(at: indexPath) as? PhotoCollectionViewItem {
				item.updateSelectionState()
			}
		}
		
		// Notify of selection change
		onSelectionChanged?(selectedPhotos)
	}
	
	func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
		// Update visual state
		for indexPath in indexPaths {
			if let item = collectionView.item(at: indexPath) as? PhotoCollectionViewItem {
				item.updateSelectionState()
			}
		}
		
		// Notify of selection change
		onSelectionChanged?(selectedPhotos)
	}
	#else
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		// System has already selected the item
		// Notify of selection change
		onSelectionChanged?(selectedPhotos)
	}
	
	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		// System has already deselected the item
		// Notify of selection change
		onSelectionChanged?(selectedPhotos)
	}
	#endif
}

// MARK: - Prefetching Support

#if os(macOS)
extension PhotoCollectionViewController: NSCollectionViewPrefetching {
	func collectionView(_ collectionView: NSCollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
		let photos: [PhotoReference] = indexPaths.compactMap { indexPath in
			guard indexPath.section < self.photoGroups.count,
				  indexPath.item < self.photoGroups[indexPath.section].photos.count else { return nil }
			return self.photoGroups[indexPath.section].photos[indexPath.item]
		}
		
		Task {
			await PhotoManager.shared.prefetchThumbnails(for: photos)
		}
	}
	
	func collectionView(_ collectionView: NSCollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
		// Could implement cancellation if we track tasks
	}
}
#else
extension PhotoCollectionViewController: UICollectionViewDataSourcePrefetching {
	func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
		let photos: [PhotoReference] = indexPaths.compactMap { indexPath in
			guard indexPath.section < self.photoGroups.count,
				  indexPath.item < self.photoGroups[indexPath.section].photos.count else { return nil }
			return self.photoGroups[indexPath.section].photos[indexPath.item]
		}
		
		Task {
			await PhotoManager.shared.prefetchThumbnails(for: photos)
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
		// Could implement cancellation if we track tasks
	}
}
#endif

// MARK: - Quick Look Support

#if os(macOS)
extension PhotoCollectionViewController: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
	
	// MARK: QLPreviewPanelDataSource
	
	func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
		return quickLookPhotos.count
	}
	
	func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
		guard index < quickLookPhotos.count else { return nil }
		return quickLookPhotos[index].fileURL as QLPreviewItem
	}
	
	// MARK: QLPreviewPanelDelegate
	
	func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
		// Handle keyboard events if needed
		if event.type == .keyDown {
			// Could handle custom keyboard shortcuts here
		}
		return false
	}
	
	func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
		// Return the frame of the thumbnail for animation
		guard let fileURL = item as? URL,
			  let photoIndex = quickLookPhotos.firstIndex(where: { $0.fileURL == fileURL }) else {
			return NSRect.zero
		}
		
		let indexPath = IndexPath(item: photoIndex, section: 0)
		guard let item = collectionView.item(at: indexPath),
			  let window = view.window else {
			return NSRect.zero
		}
		
		// Convert item frame to screen coordinates
		let itemFrameInCollection = item.view.frame
		let itemFrameInWindow = collectionView.convert(itemFrameInCollection, to: nil)
		let itemFrameInScreen = window.convertToScreen(itemFrameInWindow)
		
		return itemFrameInScreen
	}
	
	override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
		return true
	}
	
	override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
		panel.dataSource = self
		panel.delegate = self
	}
	
	override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
		panel.dataSource = nil
		panel.delegate = nil
	}
}
#endif

// MARK: - Collection View Items

#if os(macOS)
class PhotoCollectionViewItem: NSCollectionViewItem {
	weak var settings: ThumbnailDisplaySettings?
	var photoRepresentation: PhotoReference? {
		didSet {
			loadThumbnail()
			updateSelectionState()
		}
	}
	
	override func loadView() {
		view = NSView()
		view.wantsLayer = true
		view.layer?.backgroundColor = NSColor.clear.cgColor
		
		let imageView = ScalableImageView()
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.wantsLayer = true
		imageView.layer?.masksToBounds = true
		imageView.layer?.borderWidth = 1
		imageView.layer?.borderColor = XColor.separatorColor.cgColor
		
		self.imageView = imageView
		view.addSubview(imageView)
		
		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: view.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}

	func configure(with photoRep: PhotoReference) {
		self.photoRepresentation = photoRep
	}
	
	override func mouseDown(with event: NSEvent) {
		print("[PhotoCollectionViewItem] mouseDown, clickCount: \(event.clickCount), modifiers: \(event.modifierFlags)")
		
		// Check for Control+click (right-click equivalent)
		if event.modifierFlags.contains(.control) {
			print("[PhotoCollectionViewItem] Control+click detected, triggering context menu")
			// Trigger rightMouseDown to show context menu
			self.rightMouseDown(with: event)
			return
		}
		
		if event.clickCount == 2 {
			// Find the collection view controller and call its navigation handler
			if let collectionView = self.collectionView,
			   let viewController = collectionView.delegate as? PhotoCollectionViewController,
			   let indexPath = collectionView.indexPath(for: self) {
				print("[PhotoCollectionViewItem] Double-click detected, calling handleNavigation")
				viewController.handleNavigation(at: indexPath)
				return
			}
		}
		
		super.mouseDown(with: event)
	}
	
	override func rightMouseDown(with event: NSEvent) {
		print("[PhotoCollectionViewItem] rightMouseDown called")
		// Pass the event to the collection view to handle the menu
		if let collectionView = self.collectionView {
			// Get the menu and show it
			if let menu = collectionView.menu(for: event) {
				print("[PhotoCollectionViewItem] Showing menu")
				NSMenu.popUpContextMenu(menu, with: event, for: self.view)
			} else {
				print("[PhotoCollectionViewItem] No menu returned from collection view")
			}
		} else {
			super.rightMouseDown(with: event)
		}
	}
	

	override func viewWillLayout() {
		super.viewWillLayout()
		// Thumbnail loading is handled in loadThumbnail() called from photoRepresentation didSet
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		self.imageView?.image = nil
		self.photoRepresentation = nil
	}

	private let loadingSymbol: String = "circle.dotted" // "photo"
	private let loadingErrorSymbol = "exclamationmark.triangle"

	private func loadThumbnail() {
		guard let photoRep = photoRepresentation else { return }
		
		// Show placeholder icon immediately
		if let placeholderImage = NSImage(systemSymbolName: self.loadingSymbol, accessibilityDescription: "Loading photo") {
			let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .light)
				.applying(NSImage.SymbolConfiguration(paletteColors: [XColor.tertiaryLabelColor]))
			imageView?.image = placeholderImage.withSymbolConfiguration(config)
		} else {
			imageView?.image = nil
		}
		
		// If thumbnail already exists, use it
		if let thumbnail = photoRep.thumbnail {
			imageView?.image = thumbnail
			return
		}
		
		// Start loading thumbnail on background queue
		Task {
			do {
				// Load thumbnail (runs on background queue)
				if let thumbnail = try await PhotoManager.shared.thumbnail(for: photoRep) {
					// Switch to main actor only for UI updates
					await MainActor.run {
						// Update if we're still showing the same photo
						guard self.photoRepresentation === photoRep else { return }
						
						photoRep.thumbnail = thumbnail
						self.imageView?.image = thumbnail
					}
				}
			} catch {
				// Switch to main actor for UI updates
				await MainActor.run {
					// Show error state with icon
					guard self.photoRepresentation === photoRep else { return }
					if let errorImage = NSImage(systemSymbolName: self.loadingErrorSymbol, accessibilityDescription: "Failed to load photo") {
						let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .light)
							.applying(NSImage.SymbolConfiguration(paletteColors: [XColor.systemRed.withAlphaComponent(0.5)]))
						self.imageView?.image = errorImage.withSymbolConfiguration(config)
					}
				}
			}
		}
	}
	
	@MainActor
	func updateThumbnail(thumbnail: XImage?, for photoRep: PhotoReference) {
		if photoRepresentation == photoRep {
			imageView?.image = thumbnail
		}
	}
	
	@MainActor
	func updateDisplayMode() {
		guard let settings = settings else { return }
		
		// Cast to ScalableImageView to access scaleMode
		if let scalableImageView = imageView as? ScalableImageView {
			switch settings.displayMode {
			case .scaleToFit:
				scalableImageView.scaleMode = .scaleToFit
			case .scaleToFill:
				scalableImageView.scaleMode = .scaleToFill
			}
		}
	}
	
	func updateCornerRadius() {
		guard let imageView = imageView, let settings = settings else { return }
		imageView.layer?.cornerRadius = settings.thumbnailOption.cornerRadius
	}
	
	func updateSelectionState() {
		guard let photoRep = photoRepresentation else { return }
		
		// Check collection view's selection state
		var isSelected = false
		if let collectionView = self.collectionView,
		   let indexPath = collectionView.indexPath(for: self) {
			isSelected = collectionView.selectionIndexPaths.contains(indexPath)
		}
		
		// Update border to show selection
		imageView?.layer?.borderWidth = isSelected ? 3 : 1
		imageView?.layer?.borderColor = isSelected ? NSColor.controlAccentColor.cgColor : XColor.separatorColor.cgColor
		
		// Update background for better visibility
		view.layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor : NSColor.clear.cgColor
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		updateSelectionState()
	}

}
#else
class PhotoCollectionViewCell: UICollectionViewCell {
	weak var settings: ThumbnailDisplaySettings?
	var photoRepresentation: PhotoReference? {
		didSet {
			loadThumbnail()
			updateSelectionState()
		}
	}
	
	private let imageView = UIImageView()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var isSelected: Bool {
		didSet {
			updateSelectionState()
		}
	}
	
	private func setupViews() {
		updateDisplayMode()
		imageView.clipsToBounds = true
		imageView.layer.borderWidth = 1
		imageView.layer.borderColor = XColor.separator.cgColor
		
		contentView.addSubview(imageView)
		imageView.translatesAutoresizingMaskIntoConstraints = false
		
		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
		])
	}
	
	private let loadingSymbol: String = "circle.dotted"
	private let loadingErrorSymbol = "exclamationmark.triangle"
	
	private func loadThumbnail() {
		guard let photoRep = photoRepresentation else { return }
		
		// Show placeholder icon immediately
		if let placeholderImage = UIImage(systemName: self.loadingSymbol) {
			let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .light)
			imageView.image = placeholderImage.withConfiguration(config)
			imageView.tintColor = XColor.tertiaryLabel
		} else {
			imageView.image = nil
		}
		imageView.backgroundColor = nil
		
		// If thumbnail already exists, use it
		if let thumbnail = photoRep.thumbnail {
			imageView.image = thumbnail
			imageView.tintColor = nil
			return
		}
		
		// Start loading thumbnail on background queue
		Task {
			do {
				// Load thumbnail (runs on background queue)
				if let thumbnail = try await PhotoManager.shared.thumbnail(for: photoRep) {
					// Switch to main actor only for UI updates
					await MainActor.run {
						// Update if we're still showing the same photo
						guard self.photoRepresentation === photoRep else { return }
						
						photoRep.thumbnail = thumbnail
						self.imageView.image = thumbnail
						self.imageView.tintColor = nil
					}
				}
			} catch {
				// Switch to main actor for UI updates
				await MainActor.run {
					// Show error state with icon
					guard self.photoRepresentation === photoRep else { return }
					if let errorImage = UIImage(systemName: self.loadingErrorSymbol) {
						let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .light)
						self.imageView.image = errorImage.withConfiguration(config)
						self.imageView.tintColor = XColor.systemRed.withAlphaComponent(0.5)
					}
				}
			}
		}
	}
	
	func updateDisplayMode() {
		guard let settings = settings else { return }
		
		switch settings.displayMode {
		case .scaleToFit:
			imageView.contentMode = .scaleAspectFit
		case .scaleToFill:
			imageView.contentMode = .scaleAspectFill
		}
	}
	
	func updateCornerRadius() {
		guard let settings = settings else { return }
		imageView.layer.cornerRadius = settings.thumbnailOption.cornerRadius
	}
	
	func updateSelectionState() {
		guard let photoRep = photoRepresentation else { return }
		
		// Use the cell's isSelected property
		let isSelected = self.isSelected
		
		// Always show selection state when selected
		if isSelected {
			imageView.layer.borderWidth = 4
			imageView.layer.borderColor = UIColor.systemBlue.cgColor
			contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
		} else {
			imageView.layer.borderWidth = 1
			imageView.layer.borderColor = XColor.separator.cgColor
			contentView.backgroundColor = UIColor.clear
		}
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		imageView.image = nil
		photoRepresentation = nil
		// Don't update selection state here - isSelected will be set by collection view
	}
}
#endif

// MARK: - SwiftUI Hosting View

struct PhotoCollectionView: XViewControllerRepresentable {
	let directoryPath: NSString
	let settings: ThumbnailDisplaySettings
	var onSelectPhoto: ((PhotoReference, [PhotoReference]) -> Void)?
	var onSelectFolder: ((PhotoReference) -> Void)?
	var onPhotosLoaded: (([PhotoReference]) -> Void)?
	var onSelectionChanged: (([PhotoReference]) -> Void)?
	#if os(iOS)
	@Binding var photosCount: Int
	#endif
	
	#if os(macOS)
	func makeNSViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(directoryPath: directoryPath)
		controller.settings = settings
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		controller.onPhotosLoadedWithReferences = onPhotosLoaded
		controller.onSelectionChanged = onSelectionChanged
		return controller
	}
	
	func updateNSViewController(_ nsViewController: PhotoCollectionViewController, context: Context) {
		nsViewController.settings = settings
		nsViewController.onSelectPhoto = onSelectPhoto
		nsViewController.onSelectFolder = onSelectFolder
		nsViewController.onSelectionChanged = onSelectionChanged
		// Trigger layout update when settings change
		nsViewController.updateCollectionViewLayout()
	}
	#endif

	#if os(iOS)
	func makeUIViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(directoryPath: directoryPath)
		controller.settings = settings
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		controller.onPhotosLoaded = { count in
			DispatchQueue.main.async {
				self.photosCount = count
			}
		}
		controller.onPhotosLoadedWithReferences = onPhotosLoaded
		controller.onSelectionChanged = onSelectionChanged
		return controller
	}
	
	func updateUIViewController(_ uiViewController: PhotoCollectionViewController, context: Context) {
		uiViewController.settings = settings
		uiViewController.onSelectPhoto = onSelectPhoto
		uiViewController.onSelectFolder = onSelectFolder
		uiViewController.onSelectionChanged = onSelectionChanged
		// Trigger layout update when settings change
		uiViewController.updateCollectionViewLayout()
	}
	#endif
	
}

// MARK: - NSMenuDelegate

#if os(macOS)
extension PhotoCollectionViewController: NSMenuDelegate {
	func menuNeedsUpdate(_ menu: NSMenu) {
		print("[PhotoCollectionViewController] menuNeedsUpdate called")
		
		// Clear existing items
		menu.removeAllItems()
		
		// Get the clicked index path from our custom collection view
		guard let clickedCollectionView = clickedCollectionView,
			  let clickedIndexPath = clickedCollectionView.clickedIndexPath else {
			print("[PhotoCollectionViewController] No clicked collection view or index path")
			return
		}
		
		print("[PhotoCollectionViewController] Building menu for indexPath: \(clickedIndexPath)")
		
		// Get selected photos
		let photos = selectedPhotos
		print("[PhotoCollectionViewController] Selected photos count: \(photos.count)")
		
		if photos.count == 1 {
			// Single photo selected - show preview
			let photo = photos[0]
			print("[PhotoCollectionViewController] Creating header for photo: \(photo.filename)")
			
			// Create header view with preview and metadata
			let headerItem = NSMenuItem()
			let headerView = PhotoContextMenuHeaderView(frame: .zero)
			headerView.configure(with: photo, displayMode: settings?.displayMode ?? .scaleToFit)
			headerItem.view = headerView
			menu.addItem(headerItem)
			
			menu.addItem(.separator())
		} else if photos.count > 1 {
			// Multiple photos selected - show count
			let headerItem = NSMenuItem()
			let multiView = PhotoContextMenuMultipleSelectionView(frame: .zero)
			multiView.configure(with: photos.count)
			headerItem.view = multiView
			menu.addItem(headerItem)
			
			menu.addItem(.separator())
		}
		
		// Open
		let openItem = NSMenuItem(title: "Open", action: #selector(contextMenuOpen(_:)), keyEquivalent: "")
		openItem.target = self
		openItem.representedObject = photos
		menu.addItem(openItem)
		
		// Quick Look
		let quickLookItem = NSMenuItem(title: "Quick Look", action: #selector(contextMenuQuickLook(_:)), keyEquivalent: " ")
		quickLookItem.target = self
		quickLookItem.representedObject = photos
		quickLookItem.keyEquivalentModifierMask = []
		menu.addItem(quickLookItem)
		
		// Open With submenu
		if photos.count == 1 {
			let openWithItem = NSMenuItem(title: "Open With", action: nil, keyEquivalent: "")
			openWithItem.submenu = createOpenWithMenu(for: photos[0])
			menu.addItem(openWithItem)
		}
		
		menu.addItem(.separator())
		
		// Reveal in Finder
		let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(contextMenuRevealInFinder(_:)), keyEquivalent: "R")
		revealItem.target = self
		revealItem.representedObject = photos
		menu.addItem(revealItem)
		
		// Get Info
		let infoItem = NSMenuItem(title: "Get Info", action: #selector(contextMenuGetInfo(_:)), keyEquivalent: "I")
		infoItem.target = self
		infoItem.representedObject = photos
		menu.addItem(infoItem)
	}
}
#endif

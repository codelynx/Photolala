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
#else
import UIKit
#endif

// MARK: - PhotoCollectionViewController

class PhotoCollectionViewController: XViewController {
	let directoryPath: NSString
	weak var settings: ThumbnailDisplaySettings?
	weak var selectionManager: SelectionManager?
	private var lastSortOption: PhotoSortOption?

	@MainActor
	var photos: [PhotoReference] = []
	var onSelectPhoto: ((PhotoReference, [PhotoReference]) -> Void)?
	var onSelectFolder: ((PhotoReference) -> Void)?
	var onPhotosLoadedWithReferences: (([PhotoReference]) -> Void)?
	
	var collectionView: XCollectionView!
	
	#if os(iOS)
	var isSelectionMode = false
	var selectButton: UIBarButtonItem!
	var cancelButton: UIBarButtonItem!
	var selectAllButton: UIBarButtonItem!
	var actionToolbar: UIToolbar!
	var onPhotosLoaded: ((Int) -> Void)?
	var onSelectionModeChanged: ((Bool) -> Void)?
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
		
		let collectionView = XCollectionView()
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
		setupSelectionModeUI()
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
		collectionView.allowsMultipleSelectionDuringEditing = true
		
		collectionView.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
		
		view.addSubview(collectionView)
	}
	
	private func setupSelectionModeUI() {
		// Create bar button items
		selectButton = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(enterSelectionMode))
		cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(exitSelectionMode))
		selectAllButton = UIBarButtonItem(title: "Select All", style: .plain, target: self, action: #selector(toggleSelectAll))
		
		// Initially show Select button
		navigationItem.rightBarButtonItem = selectButton
		
		// Create action toolbar (hidden initially)
		actionToolbar = UIToolbar()
		actionToolbar.translatesAutoresizingMaskIntoConstraints = false
		actionToolbar.isHidden = true
		
		// Set toolbar appearance for consistent background
		let toolbarAppearance = UIToolbarAppearance()
		toolbarAppearance.configureWithOpaqueBackground()
		toolbarAppearance.backgroundColor = .systemBackground
		actionToolbar.standardAppearance = toolbarAppearance
		actionToolbar.scrollEdgeAppearance = toolbarAppearance
		actionToolbar.compactAppearance = toolbarAppearance
		actionToolbar.compactScrollEdgeAppearance = toolbarAppearance
		
		view.addSubview(actionToolbar)
		
		// Setup toolbar constraints
		NSLayoutConstraint.activate([
			actionToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			actionToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			actionToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
		
		// Configure toolbar items
		let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareSelectedItems))
		let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteSelectedItems))
		let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		
		actionToolbar.items = [shareButton, flexibleSpace, deleteButton]
	}
#endif
	
	@MainActor
	func reloadData() {
		collectionView.reloadData()
	}
	
	// MARK: - Private Methods
	
	private func loadPhotos() {
		Task { @MainActor in
			// Use DirectoryScanner to get PhotoReference objects
			let scannedPhotos = DirectoryScanner.scanDirectory(atPath: directoryPath)
			
			// Apply sorting based on current settings
			let sortedPhotos = settings?.sortOption.sort(scannedPhotos) ?? scannedPhotos
			self.photos = sortedPhotos
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
		} onChange: { [weak self] in
			Task { @MainActor in
				let oldSortOption = self?.lastSortOption
				let newSortOption = settings.sortOption
				
				// If sort option changed, re-sort photos
				if oldSortOption != newSortOption {
					self?.lastSortOption = newSortOption
					self?.applySorting()
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
		
		collectionView.reloadData()
	}
	
	private func setupToolbar() {
		// Toolbar is now handled by SwiftUI in PhotoBrowserView
	}
	
	@objc private func toggleDisplayMode() {
		guard let settings = settings else { return }
		settings.displayMode = settings.displayMode == .scaleToFit ? .scaleToFill : .scaleToFit
	}
	
	@objc private func handleDeselectAll() {
		selectionManager?.clearSelection()
		
		#if os(macOS)
		// Clear native collection view selection
		collectionView.deselectAll(nil)
		#else
		// If in selection mode, update UI
		if isSelectionMode {
			// Deselect all items in collection view
			for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
				collectionView.deselectItem(at: indexPath, animated: true)
			}
			updateSelectionTitle()
			updateToolbarButtons()
		}
		#endif
	}
	
	// MARK: - iOS Selection Mode
	
	#if os(iOS)
	@objc func enterSelectionMode() {
		isSelectionMode = true
		collectionView.allowsMultipleSelection = true
		onSelectionModeChanged?(true)
		
		// Update navigation bar
		navigationItem.leftBarButtonItem = cancelButton
		navigationItem.rightBarButtonItem = selectAllButton
		updateSelectionTitle()
		
		// Show action toolbar
		actionToolbar.isHidden = false
		updateToolbarButtons()
		
		// Adjust collection view bottom inset for toolbar
		var contentInset = collectionView.contentInset
		contentInset.bottom = 44 // toolbar height
		collectionView.contentInset = contentInset
		
		// Update visible cells for selection mode
		for cell in collectionView.visibleCells {
			if let photoCell = cell as? PhotoCollectionViewCell {
				photoCell.setSelectionMode(true)
			}
		}
	}
	
	@objc func exitSelectionMode() {
		isSelectionMode = false
		collectionView.allowsMultipleSelection = false
		onSelectionModeChanged?(false)
		
		// Clear selection
		selectionManager?.clearSelection()
		
		// Reset navigation bar
		navigationItem.leftBarButtonItem = nil
		navigationItem.rightBarButtonItem = selectButton
		navigationItem.title = directoryPath.lastPathComponent
		
		// Hide action toolbar
		actionToolbar.isHidden = true
		
		// Reset collection view inset
		var contentInset = collectionView.contentInset
		contentInset.bottom = 0
		collectionView.contentInset = contentInset
		
		// Update visible cells to hide checkboxes
		for cell in collectionView.visibleCells {
			if let photoCell = cell as? PhotoCollectionViewCell {
				photoCell.setSelectionMode(false)
			}
		}
	}
	
	@objc private func toggleSelectAll() {
		guard let selectionManager = selectionManager else { return }
		
		if selectionManager.selectedItems.count == photos.count {
			// Deselect all
			for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
				collectionView.deselectItem(at: indexPath, animated: true)
			}
			selectionManager.clearSelection()
		} else {
			// Select all
			for (index, photo) in photos.enumerated() {
				let indexPath = IndexPath(item: index, section: 0)
				collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
				selectionManager.addToSelection(photo)
			}
		}
		
		updateSelectionTitle()
		updateToolbarButtons()
	}
	
	private func updateSelectionTitle() {
		guard let selectionManager = selectionManager else { return }
		let count = selectionManager.selectionCount
		
		if count == 0 {
			navigationItem.title = "Select Items"
		} else {
			navigationItem.title = "\(count) Selected"
		}
		
		// Update Select All button title
		if count == photos.count && count > 0 {
			selectAllButton.title = "Deselect All"
		} else {
			selectAllButton.title = "Select All"
		}
	}
	
	private func updateToolbarButtons() {
		guard let selectionManager = selectionManager else { return }
		let hasSelection = selectionManager.selectionCount > 0
		
		// Enable/disable toolbar buttons based on selection
		for item in actionToolbar.items ?? [] {
			item.isEnabled = hasSelection
		}
	}
	
	@objc private func shareSelectedItems() {
		guard let selectionManager = selectionManager else { return }
		let selectedURLs = selectionManager.selectedItems.map { $0.fileURL }
		
		if !selectedURLs.isEmpty {
			let activityController = UIActivityViewController(activityItems: selectedURLs, applicationActivities: nil)
			
			// For iPad
			if let popover = activityController.popoverPresentationController {
				popover.barButtonItem = actionToolbar.items?.first
			}
			
			present(activityController, animated: true)
		}
	}
	
	@objc private func deleteSelectedItems() {
		// Show confirmation alert
		guard let selectionManager = selectionManager else { return }
		let count = selectionManager.selectionCount
		
		let alert = UIAlertController(
			title: "Delete \(count) Photo\(count == 1 ? "" : "s")?",
			message: "This action cannot be undone.",
			preferredStyle: .alert
		)
		
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
			// TODO: Implement actual deletion
			print("Would delete \(count) items")
		})
		
		present(alert, animated: true)
	}
	#endif
	
	// MARK: - Navigation
	
	func handleNavigation(at indexPath: IndexPath) {
		let photo = photos[indexPath.item]
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

	func collectionView(_ collectionView: XCollectionView, numberOfItemsInSection section: Int) -> Int {
		return photos.count
	}
	
	#if os(macOS)
	func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
		let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("PhotoItem"), for: indexPath) as! PhotoCollectionViewItem
		let photo = photos[indexPath.item]
		item.settings = settings
		item.selectionManager = selectionManager
		item.photoRepresentation = photo
		item.updateCornerRadius()
		return item
	}
	#endif

	#if os(iOS)
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCollectionViewCell
		let photo = photos[indexPath.item]
		cell.settings = settings
		cell.selectionManager = selectionManager
		cell.photoRepresentation = photo
		cell.updateCornerRadius()
		cell.setSelectionMode(isSelectionMode)
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
		
		// Don't call super to prevent default selection behavior on double-click
		if event.clickCount == 2 {
			let locationInView = view.convert(event.locationInWindow, from: nil)
			let locationInCollectionView = collectionView.convert(locationInView, from: view)
			
			print("[PhotoCollectionViewController] Double-click at location: \(locationInCollectionView)")
			
			if let indexPath = collectionView.indexPathForItem(at: locationInCollectionView) {
				print("[PhotoCollectionViewController] Double-click on item at indexPath: \(indexPath)")
				handleNavigation(at: indexPath)
				return
			}
		}
		
		// For single clicks, let the collection view handle it
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
	#endif

	#if os(macOS)
	func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
		// Sync NSCollectionView selection with our SelectionManager
		guard let selectionManager = selectionManager else { return }
		
		// Add newly selected items
		for indexPath in indexPaths {
			if indexPath.item < photos.count {
				let photo = photos[indexPath.item]
				if !selectionManager.isSelected(photo) {
					selectionManager.addToSelection(photo)
				}
			}
		}
		
		// Update visual state
		for indexPath in indexPaths {
			if let item = collectionView.item(at: indexPath) as? PhotoCollectionViewItem {
				item.updateSelectionState()
			}
		}
	}
	
	func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
		// Sync deselection
		guard let selectionManager = selectionManager else { return }
		
		// Remove deselected items
		for indexPath in indexPaths {
			if indexPath.item < photos.count {
				let photo = photos[indexPath.item]
				selectionManager.removeFromSelection(photo)
			}
		}
		
		// Update visual state
		for indexPath in indexPaths {
			if let item = collectionView.item(at: indexPath) as? PhotoCollectionViewItem {
				item.updateSelectionState()
			}
		}
	}
	#else
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		if isSelectionMode {
			// In selection mode: sync with SelectionManager
			guard let selectionManager = selectionManager else { return }
			let photo = photos[indexPath.item]
			selectionManager.addToSelection(photo)
			
			if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
				cell.updateSelectionState()
			}
			
			updateSelectionTitle()
			updateToolbarButtons()
		} else {
			// Normal mode: navigate
			collectionView.deselectItem(at: indexPath, animated: false)
			handleNavigation(at: indexPath)
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		if isSelectionMode {
			// Sync deselection
			guard let selectionManager = selectionManager else { return }
			let photo = photos[indexPath.item]
			selectionManager.removeFromSelection(photo)
			
			if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
				cell.updateSelectionState()
			}
			
			updateSelectionTitle()
			updateToolbarButtons()
		}
	}
	#endif
}

// MARK: - Prefetching Support

#if os(macOS)
extension PhotoCollectionViewController: NSCollectionViewPrefetching {
	func collectionView(_ collectionView: NSCollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
		let photos = indexPaths.compactMap { indexPath in
			indexPath.item < self.photos.count ? self.photos[indexPath.item] : nil
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
		let photos = indexPaths.compactMap { indexPath in
			indexPath.item < self.photos.count ? self.photos[indexPath.item] : nil
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

// MARK: - Collection View Items

#if os(macOS)
class PhotoCollectionViewItem: NSCollectionViewItem {
	weak var settings: ThumbnailDisplaySettings?
	weak var selectionManager: SelectionManager?
	var photoRepresentation: PhotoReference? {
		didSet {
			loadThumbnail()
			updateSelectionState()
		}
	}
	
	override func loadView() {
		view = NSView()
		
		let imageView = NSImageView()
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.imageScaling = .scaleProportionallyUpOrDown
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
		print("[PhotoCollectionViewItem] mouseDown, clickCount: \(event.clickCount)")
		
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

	override func viewWillLayout() {
		super.viewWillLayout()
		// Thumbnail loading is handled in loadThumbnail() called from photoRepresentation didSet
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		self.imageView?.image = nil
		self.photoRepresentation = nil
	}

	private func loadThumbnail() {
		guard let photoRep = photoRepresentation else { return }
		
		// Show placeholder immediately
		imageView?.image = nil
		imageView?.layer?.backgroundColor = XColor.quaternaryLabelColor.cgColor
		
		// If thumbnail already exists, use it
		if let thumbnail = photoRep.thumbnail {
			imageView?.image = thumbnail
			imageView?.layer?.backgroundColor = nil
			return
		}
		
		// Start loading thumbnail only
		Task { @MainActor in
			do {
				// Load thumbnail
				if let thumbnail = try await PhotoManager.shared.thumbnail(for: photoRep) {
					// Update if we're still showing the same photo
					guard self.photoRepresentation === photoRep else { return }
					
					photoRep.thumbnail = thumbnail
					self.imageView?.image = thumbnail
					self.imageView?.layer?.backgroundColor = nil
				}
			} catch {
				// Show error state
				guard self.photoRepresentation === photoRep else { return }
				self.imageView?.layer?.backgroundColor = XColor.systemRed.withAlphaComponent(0.1).cgColor
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
		guard let imageView = imageView, let settings = settings else { return }
		
		switch settings.displayMode {
		case .scaleToFit:
			imageView.imageScaling = .scaleProportionallyUpOrDown
		case .scaleToFill:
			imageView.imageScaling = .scaleAxesIndependently
		}
	}
	
	func updateCornerRadius() {
		guard let imageView = imageView, let settings = settings else { return }
		imageView.layer?.cornerRadius = settings.thumbnailOption.cornerRadius
	}
	
	func updateSelectionState() {
		guard let photoRep = photoRepresentation,
			  let selectionManager = selectionManager else { return }
		
		let isSelected = selectionManager.isSelected(photoRep)
		let isFocused = selectionManager.focusedItem == photoRep
		
		// Update border to show selection
		imageView?.layer?.borderWidth = isSelected ? 3 : 1
		imageView?.layer?.borderColor = isSelected ? NSColor.controlAccentColor.cgColor : XColor.separatorColor.cgColor
		
		// Update background for better visibility
		view.layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor : NSColor.clear.cgColor
		
		// Add focus ring
		if isFocused {
			// Create focus ring effect
			view.layer?.borderWidth = 2
			view.layer?.borderColor = NSColor.keyboardFocusIndicatorColor.cgColor
			view.layer?.cornerRadius = 4
		} else {
			view.layer?.borderWidth = 0
		}
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		updateSelectionState()
	}

}
#else
class PhotoCollectionViewCell: UICollectionViewCell {
	weak var settings: ThumbnailDisplaySettings?
	weak var selectionManager: SelectionManager?
	var photoRepresentation: PhotoReference? {
		didSet {
			loadThumbnail()
			updateSelectionState()
		}
	}
	
	private let imageView = UIImageView()
	private let checkboxImageView = UIImageView()
	private var isInSelectionMode = false
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func setupViews() {
		updateDisplayMode()
		imageView.clipsToBounds = true
		imageView.layer.borderWidth = 1
		imageView.layer.borderColor = XColor.separator.cgColor
		
		// Setup checkbox
		checkboxImageView.contentMode = .scaleAspectFit
		checkboxImageView.isHidden = true
		
		contentView.addSubview(imageView)
		contentView.addSubview(checkboxImageView)
		imageView.translatesAutoresizingMaskIntoConstraints = false
		checkboxImageView.translatesAutoresizingMaskIntoConstraints = false
		
		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
			
			// Checkbox in top-right corner
			checkboxImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
			checkboxImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
			checkboxImageView.widthAnchor.constraint(equalToConstant: 24),
			checkboxImageView.heightAnchor.constraint(equalToConstant: 24)
		])
	}
	
	private func loadThumbnail() {
		guard let photoRep = photoRepresentation else { return }
		
		// Show placeholder immediately
		imageView.image = nil
		imageView.backgroundColor = XColor.quaternaryLabel
		
		// If thumbnail already exists, use it
		if let thumbnail = photoRep.thumbnail {
			imageView.image = thumbnail
			imageView.backgroundColor = nil
			return
		}
		
		// Start loading thumbnail only
		Task { @MainActor in
			do {
				// Load thumbnail
				if let thumbnail = try await PhotoManager.shared.thumbnail(for: photoRep) {
					// Update if we're still showing the same photo
					guard self.photoRepresentation === photoRep else { return }
					
					photoRep.thumbnail = thumbnail
					self.imageView.image = thumbnail
					self.imageView.backgroundColor = nil
				}
			} catch {
				// Show error state
				guard self.photoRepresentation === photoRep else { return }
				self.imageView.backgroundColor = XColor.systemRed.withAlphaComponent(0.1)
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
		guard let photoRep = photoRepresentation,
			  let selectionManager = selectionManager else { return }
		
		let isSelected = selectionManager.isSelected(photoRep)
		let isFocused = selectionManager.focusedItem == photoRep
		
		if isInSelectionMode {
			// In selection mode, use tinted border for selection
			if isSelected {
				imageView.layer.borderWidth = 4
				imageView.layer.borderColor = UIColor.systemBlue.cgColor
				contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
			} else {
				imageView.layer.borderWidth = 1
				imageView.layer.borderColor = XColor.separator.cgColor
				contentView.backgroundColor = UIColor.clear
			}
			
			// Hide checkbox since we're using border selection
			checkboxImageView.isHidden = true
		} else {
			// Normal mode - no selection visible on iOS
			imageView.layer.borderWidth = 1
			imageView.layer.borderColor = XColor.separator.cgColor
			contentView.backgroundColor = UIColor.clear
			contentView.layer.borderWidth = 0
			checkboxImageView.isHidden = true
		}
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		imageView.image = nil
		photoRepresentation = nil
		updateSelectionState()
		checkboxImageView.isHidden = true
		isInSelectionMode = false
	}
	
	func setSelectionMode(_ enabled: Bool) {
		isInSelectionMode = enabled
		updateSelectionState()
	}
}
#endif

// MARK: - SwiftUI Hosting View

struct PhotoCollectionView: XViewControllerRepresentable {
	let directoryPath: NSString
	let settings: ThumbnailDisplaySettings
	let selectionManager: SelectionManager
	var onSelectPhoto: ((PhotoReference, [PhotoReference]) -> Void)?
	var onSelectFolder: ((PhotoReference) -> Void)?
	var onPhotosLoaded: (([PhotoReference]) -> Void)?
	#if os(iOS)
	@Binding var isSelectionModeActive: Bool
	@Binding var photosCount: Int
	#endif
	
	#if os(macOS)
	func makeNSViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(directoryPath: directoryPath)
		controller.settings = settings
		controller.selectionManager = selectionManager
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		controller.onPhotosLoadedWithReferences = onPhotosLoaded
		return controller
	}
	
	func updateNSViewController(_ nsViewController: PhotoCollectionViewController, context: Context) {
		nsViewController.settings = settings
		nsViewController.selectionManager = selectionManager
		nsViewController.onSelectPhoto = onSelectPhoto
		nsViewController.onSelectFolder = onSelectFolder
		// Trigger layout update when settings change
		nsViewController.updateCollectionViewLayout()
	}
	#endif

	#if os(iOS)
	func makeUIViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(directoryPath: directoryPath)
		controller.settings = settings
		controller.selectionManager = selectionManager
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		controller.onPhotosLoaded = { count in
			DispatchQueue.main.async {
				self.photosCount = count
			}
		}
		controller.onPhotosLoadedWithReferences = onPhotosLoaded
		controller.onSelectionModeChanged = { isActive in
			DispatchQueue.main.async {
				self.isSelectionModeActive = isActive
			}
		}
		return controller
	}
	
	func updateUIViewController(_ uiViewController: PhotoCollectionViewController, context: Context) {
		uiViewController.settings = settings
		uiViewController.selectionManager = selectionManager
		uiViewController.onSelectPhoto = onSelectPhoto
		uiViewController.onSelectFolder = onSelectFolder
		// Trigger layout update when settings change
		uiViewController.updateCollectionViewLayout()
		
		// Handle selection mode changes from SwiftUI
		if isSelectionModeActive && !uiViewController.isSelectionMode {
			uiViewController.enterSelectionMode()
		} else if !isSelectionModeActive && uiViewController.isSelectionMode {
			uiViewController.exitSelectionMode()
		}
	}
	#endif
	
}

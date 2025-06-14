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

	@MainActor
	var photos: [PhotoRepresentation] = []
	var onSelectPhoto: ((PhotoRepresentation, [PhotoRepresentation]) -> Void)?
	var onSelectFolder: ((PhotoRepresentation) -> Void)?
	
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
		view.addSubview(actionToolbar)
		
		// Setup toolbar constraints
		NSLayoutConstraint.activate([
			actionToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			actionToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			actionToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
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
			// Use DirectoryScanner to get PhotoRepresentation objects
			let scannedPhotos = DirectoryScanner.scanDirectory(atPath: directoryPath)
			self.photos = scannedPhotos
			self.reloadData()
			
			#if os(iOS)
			// Notify SwiftUI about photos loaded
			self.onPhotosLoaded?(self.photos.count)
			#endif
		}
	}
	
	private func setupSettingsObserver() {
		// Observe settings changes when settings object is available
		guard let settings = settings else { return }
		
		withObservationTracking {
			_ = settings.displayMode
			_ = settings.thumbnailSize
		} onChange: { [weak self] in
			Task { @MainActor in
				self?.updateCollectionViewLayout()
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
		
		// Update visible cells to show checkboxes
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
	
	private func handleNavigation(at indexPath: IndexPath) {
		let photo = photos[indexPath.item]
		let photoURL = photo.fileURL
		
		// Check if it's a directory
		var isDirectory: ObjCBool = false
		if FileManager.default.fileExists(atPath: photoURL.path, isDirectory: &isDirectory) {
			if isDirectory.boolValue {
				onSelectFolder?(photo)
			} else {
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
		super.mouseDown(with: event)
		
		let point = collectionView.convert(event.locationInWindow, from: nil)
		
		if event.clickCount == 2 {
			// Handle double-click for navigation/preview
			if let indexPath = collectionView.indexPathForItem(at: point) {
				handleNavigation(at: indexPath)
			}
		}
		// Let NSCollectionView handle single clicks for selection
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

// MARK: - Collection View Items

#if os(macOS)
class PhotoCollectionViewItem: NSCollectionViewItem {
	weak var settings: ThumbnailDisplaySettings?
	weak var selectionManager: SelectionManager?
	var photoRepresentation: PhotoRepresentation? {
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

	func configure(with photoRep: PhotoRepresentation) {
		self.photoRepresentation = photoRep
	}

	override func viewWillLayout() {
		super.viewWillLayout()
		if let photoRepresentation = self.photoRepresentation {
			if let thumbnail = photoRepresentation.thumbnail {
				imageView?.image = thumbnail
			}
			else {
				Task {
					do {
						let photoRep = photoRepresentation
						let thumbnail = try await PhotoManager.shared.thumbnail(for: photoRep)
						self.updateThumbnail(thumbnail: thumbnail, for: photoRepresentation)
					} catch {
						// Silent fail for thumbnails
					}
				}
			}
		}
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		self.imageView?.image = nil
		self.photoRepresentation = nil
	}

	private func loadThumbnail() {
		guard let photoRep = photoRepresentation else { return }
		
		Task { @MainActor in
			do {
				if let thumbnail = try await PhotoManager.shared.thumbnail(for: photoRep) {
					self.imageView?.image = thumbnail
				}
			} catch {
				// Silently ignore thumbnail loading errors
			}
		}
	}
	
	@MainActor
	func updateThumbnail(thumbnail: XImage?, for photoRep: PhotoRepresentation) {
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
	var photoRepresentation: PhotoRepresentation? {
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
		
		Task { @MainActor in
			do {
				if let thumbnail = try await PhotoManager.shared.thumbnail(for: photoRep) {
					self.imageView.image = thumbnail
				}
			} catch {
				// Silently ignore thumbnail loading errors
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
			// In selection mode, show checkbox instead of border
			imageView.layer.borderWidth = 1
			imageView.layer.borderColor = XColor.separator.cgColor
			contentView.backgroundColor = UIColor.clear
			
			// Update checkbox image
			if isSelected {
				checkboxImageView.image = UIImage(systemName: "checkmark.circle.fill")
				checkboxImageView.tintColor = UIColor.systemBlue
			} else {
				checkboxImageView.image = UIImage(systemName: "circle")
				checkboxImageView.tintColor = UIColor.secondaryLabel
			}
		} else {
			// Normal mode - use border to show selection
			imageView.layer.borderWidth = isSelected ? 3 : 1
			imageView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : XColor.separator.cgColor
			
			// Update background for better visibility
			contentView.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.1) : UIColor.clear
			
			// Add focus ring
			if isFocused {
				// Create focus ring effect
				contentView.layer.borderWidth = 2
				contentView.layer.borderColor = UIColor.label.cgColor
				contentView.layer.cornerRadius = 4
			} else {
				contentView.layer.borderWidth = 0
			}
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
		checkboxImageView.isHidden = !enabled
		updateSelectionState()
	}
}
#endif

// MARK: - SwiftUI Hosting View

struct PhotoCollectionView: XViewControllerRepresentable {
	let directoryPath: NSString
	let settings: ThumbnailDisplaySettings
	let selectionManager: SelectionManager
	var onSelectPhoto: ((PhotoRepresentation, [PhotoRepresentation]) -> Void)?
	var onSelectFolder: ((PhotoRepresentation) -> Void)?
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

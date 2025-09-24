//
//  PhotoCollectionViewController.swift
//  Photolala
//
//  Native collection view controller for photo browsing
//

import SwiftUI
import Combine

#if os(macOS)
import AppKit

@MainActor
class PhotoCollectionViewController: NSViewController {
	// Collection view
	private var collectionView: NSCollectionView!
	private var scrollView: NSScrollView!

	// Data source
	private var dataSource: NSCollectionViewDiffableDataSource<Int, String>!

	// Environment
	var environment: PhotoBrowserEnvironment

	// Settings
	let settings: PhotoBrowserSettings
	private var lastDisplayMode: ThumbnailDisplayMode?
	private var lastShowInfoBar: Bool?

	// State
	var photos: [PhotoBrowserItem] = [] {
		didSet {
			updateSnapshot()
		}
	}

	var selection = Set<PhotoBrowserItem>() {
		didSet {
			updateSelection()
		}
	}

	// Callbacks
	var onItemTapped: ((PhotoBrowserItem) -> Void)?
	var onSelectionChanged: ((Set<PhotoBrowserItem>) -> Void)?

	init(environment: PhotoBrowserEnvironment, settings: PhotoBrowserSettings = PhotoBrowserSettings()) {
		self.environment = environment
		self.settings = settings
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		// Create scroll view
		scrollView = NSScrollView()
		scrollView.hasVerticalScroller = true
		scrollView.autohidesScrollers = false

		// Create collection view
		collectionView = NSCollectionView()
		collectionView.isSelectable = true
		collectionView.allowsMultipleSelection = environment.configuration.allowsMultipleSelection
		collectionView.delegate = self

		// Set up layout
		let layout = NSCollectionViewFlowLayout()
		layout.minimumLineSpacing = settings.itemSpacing
		layout.minimumInteritemSpacing = settings.itemSpacing
		layout.itemSize = settings.itemSize
		layout.sectionInset = NSEdgeInsets(
			top: settings.sectionInsets.top,
			left: settings.sectionInsets.leading,
			bottom: settings.sectionInsets.bottom,
			right: settings.sectionInsets.trailing
		)
		collectionView.collectionViewLayout = layout

		// Register cell
		collectionView.register(
			PhotoCell.self,
			forItemWithIdentifier: NSUserInterfaceItemIdentifier(PhotoCell.reuseIdentifier)
		)

		scrollView.documentView = collectionView
		view = scrollView

		setupDataSource()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.wantsLayer = true
		view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
	}

	override func viewWillLayout() {
		super.viewWillLayout()
		// Don't update on every layout to avoid loops
		if view.frame.width > 0 {
			updateItemSize()
		}
	}

	private func setupDataSource() {
		dataSource = NSCollectionViewDiffableDataSource(
			collectionView: collectionView
		) { [weak self] collectionView, indexPath, itemId in
			guard let self = self,
				  let item = self.photos.first(where: { $0.id == itemId }) else { return nil }

			let cell = collectionView.makeItem(
				withIdentifier: NSUserInterfaceItemIdentifier(PhotoCell.reuseIdentifier),
				for: indexPath
			) as! PhotoCell

			// Determine source context for basket operations
			var sourceURL: URL?
			var sourceIdentifier: String?

			if let localSource = self.environment.source as? LocalPhotoSource {
				// For local sources, we need the file URL
				sourceURL = localSource.fileURL(for: item.id)
				sourceIdentifier = sourceURL?.path ?? item.id
			} else if self.environment.source is S3PhotoSource {
				// For S3, the item ID is typically the S3 key
				sourceIdentifier = item.id
			} else if self.environment.source is ApplePhotosSource {
				// For Apple Photos, use the asset identifier
				sourceIdentifier = item.id
			}

			cell.configure(with: item, source: self.environment.source, displayMode: self.settings.displayMode, showInfoBar: self.settings.showInfoBar, sourceURL: sourceURL, sourceIdentifier: sourceIdentifier)
			return cell
		}
	}

	private func updateSnapshot() {
		var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
		snapshot.appendSections([0])
		let photoIds = photos.map { $0.id }
		snapshot.appendItems(photoIds, toSection: 0)
		dataSource.apply(snapshot, animatingDifferences: true)
	}

	private func updateSelection() {
		// Update collection view selection
		let indexPaths = selection.compactMap { item in
			photos.firstIndex(of: item).map { IndexPath(item: $0, section: 0) }
		}
		collectionView.selectionIndexPaths = Set(indexPaths)
	}

	func updateItemSize(forceReload: Bool = false) {
		guard let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else { return }

		let width = view.bounds.width

		// Skip if width is zero (view not laid out yet)
		guard width > 0 else { return }

		// Check if display mode or info bar changed
		let displayModeChanged = lastDisplayMode != nil && lastDisplayMode != settings.displayMode
		let infoBarChanged = lastShowInfoBar != nil && lastShowInfoBar != settings.showInfoBar
		lastDisplayMode = settings.displayMode
		lastShowInfoBar = settings.showInfoBar

		// Get optimized layout from settings
		let (optimizedSize, _) = settings.optimizeLayout(for: width)

		// Only update if size changed significantly (avoid layout loops)
		let currentSize = layout.itemSize
		let sizeChanged = abs(currentSize.width - optimizedSize.width) > 1 ||
		                  abs(currentSize.height - optimizedSize.height) > 1

		if sizeChanged {
			layout.itemSize = optimizedSize
			layout.minimumLineSpacing = settings.itemSpacing
			layout.minimumInteritemSpacing = settings.itemSpacing
			layout.sectionInset = NSEdgeInsets(
				top: settings.sectionInsets.top,
				left: settings.sectionInsets.leading,
				bottom: settings.sectionInsets.bottom,
				right: settings.sectionInsets.trailing
			)

			// Animate the change on macOS (be careful with transforms!)
			// Use frame-based animation, not layer transforms
			NSAnimationContext.runAnimationGroup { context in
				context.duration = 0.25
				context.allowsImplicitAnimation = true
				layout.invalidateLayout()
			}
		} else if forceReload || displayModeChanged || infoBarChanged {
			// Force reload cells to update display mode or info bar
			collectionView.reloadData()
		}
	}
}

// MARK: - NSCollectionViewDelegate

extension PhotoCollectionViewController: NSCollectionViewDelegate {
	func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
		updateSelectionFromCollectionView()
	}

	func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
		updateSelectionFromCollectionView()
	}

	private func updateSelectionFromCollectionView() {
		let selectedIndexes = collectionView.selectionIndexPaths.compactMap { $0.item }
		let selectedItems = Set(selectedIndexes.compactMap { photos[safe: $0] })
		selection = selectedItems
		onSelectionChanged?(selection)
	}

	func collectionView(_ collectionView: NSCollectionView, didDoubleClickAt indexPath: IndexPath) {
		guard let item = photos[safe: indexPath.item] else { return }
		onItemTapped?(item)
	}
}

#else
import UIKit

@MainActor
class PhotoCollectionViewController: UIViewController {
	// Collection view
	private var collectionView: UICollectionView!

	// Data source
	private var dataSource: UICollectionViewDiffableDataSource<Int, String>!

	// Environment
	var environment: PhotoBrowserEnvironment

	// Settings
	let settings: PhotoBrowserSettings
	private var lastDisplayMode: ThumbnailDisplayMode?
	private var lastShowInfoBar: Bool?

	// State
	var photos: [PhotoBrowserItem] = [] {
		didSet {
			updateSnapshot()
		}
	}

	var selection = Set<PhotoBrowserItem>() {
		didSet {
			updateSelection()
		}
	}

	// Callbacks
	var onItemTapped: ((PhotoBrowserItem) -> Void)?
	var onSelectionChanged: ((Set<PhotoBrowserItem>) -> Void)?

	init(environment: PhotoBrowserEnvironment, settings: PhotoBrowserSettings = PhotoBrowserSettings()) {
		self.environment = environment
		self.settings = settings
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		// Create layout
		let layout = UICollectionViewFlowLayout()
		layout.minimumLineSpacing = settings.itemSpacing
		layout.minimumInteritemSpacing = settings.itemSpacing
		layout.itemSize = settings.itemSize
		layout.sectionInset = UIEdgeInsets(
			top: settings.sectionInsets.top,
			left: settings.sectionInsets.leading,
			bottom: settings.sectionInsets.bottom,
			right: settings.sectionInsets.trailing
		)

		// Create collection view
		collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
		collectionView.backgroundColor = .systemBackground
		collectionView.allowsMultipleSelection = environment.configuration.allowsMultipleSelection
		collectionView.delegate = self

		// Register cell
		collectionView.register(
			PhotoCell.self,
			forCellWithReuseIdentifier: PhotoCell.reuseIdentifier
		)

		view = collectionView
		setupDataSource()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground
	}


	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		// Don't update on every layout to avoid loops
		if view.frame.width > 0 {
			updateItemSize()
		}
	}

	private func setupDataSource() {
		dataSource = UICollectionViewDiffableDataSource(
			collectionView: collectionView
		) { [weak self] collectionView, indexPath, itemId in
			guard let self = self,
				  let item = self.photos.first(where: { $0.id == itemId }) else { return nil }

			let cell = collectionView.dequeueReusableCell(
				withReuseIdentifier: PhotoCell.reuseIdentifier,
				for: indexPath
			) as! PhotoCell

			// Determine source context for basket operations
			var sourceURL: URL?
			var sourceIdentifier: String?

			if let localSource = self.environment.source as? LocalPhotoSource {
				// For local sources, we need the file URL
				sourceURL = localSource.fileURL(for: item.id)
				sourceIdentifier = sourceURL?.path ?? item.id
			} else if self.environment.source is S3PhotoSource {
				// For S3, the item ID is typically the S3 key
				sourceIdentifier = item.id
			} else if self.environment.source is ApplePhotosSource {
				// For Apple Photos, use the asset identifier
				sourceIdentifier = item.id
			}

			cell.configure(with: item, source: self.environment.source, displayMode: self.settings.displayMode, showInfoBar: self.settings.showInfoBar, sourceURL: sourceURL, sourceIdentifier: sourceIdentifier)
			return cell
		}
	}

	private func updateSnapshot() {
		var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
		snapshot.appendSections([0])
		let photoIds = photos.map { $0.id }
		snapshot.appendItems(photoIds, toSection: 0)
		dataSource.apply(snapshot, animatingDifferences: true)
	}

	private func updateSelection() {
		// Update collection view selection
		for (index, item) in photos.enumerated() {
			let indexPath = IndexPath(item: index, section: 0)
			if selection.contains(item) {
				collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
			} else {
				collectionView.deselectItem(at: indexPath, animated: false)
			}
		}
	}

	func updateItemSize(forceReload: Bool = false) {
		guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

		let width = view.bounds.width

		// Skip if width is zero (view not laid out yet)
		guard width > 0 else { return }

		// Check if display mode or info bar changed
		let displayModeChanged = lastDisplayMode != nil && lastDisplayMode != settings.displayMode
		let infoBarChanged = lastShowInfoBar != nil && lastShowInfoBar != settings.showInfoBar
		lastDisplayMode = settings.displayMode
		lastShowInfoBar = settings.showInfoBar

		// Get optimized layout from settings
		let (optimizedSize, _) = settings.optimizeLayout(for: width)

		// Only update if size changed significantly (avoid layout loops)
		let currentSize = layout.itemSize
		let sizeChanged = abs(currentSize.width - optimizedSize.width) > 1 ||
		                  abs(currentSize.height - optimizedSize.height) > 1

		if sizeChanged {
			layout.itemSize = optimizedSize
			layout.minimumLineSpacing = settings.itemSpacing
			layout.minimumInteritemSpacing = settings.itemSpacing
			layout.sectionInset = UIEdgeInsets(
				top: settings.sectionInsets.top,
				left: settings.sectionInsets.leading,
				bottom: settings.sectionInsets.bottom,
				right: settings.sectionInsets.trailing
			)

			// Animate the change
			UIView.animate(withDuration: 0.25) {
				self.collectionView.collectionViewLayout.invalidateLayout()
				self.collectionView.layoutIfNeeded()
			}
		} else if forceReload || displayModeChanged || infoBarChanged {
			// Force reload cells to update display mode or info bar
			collectionView.reloadData()
		}
	}
}

// MARK: - UICollectionViewDelegate

extension PhotoCollectionViewController: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		if environment.configuration.allowsMultipleSelection {
			updateSelectionFromCollectionView()
		} else {
			// Single selection - handle tap
			guard let item = photos[safe: indexPath.item] else { return }
			onItemTapped?(item)
		}
	}

	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		if environment.configuration.allowsMultipleSelection {
			updateSelectionFromCollectionView()
		}
	}

	private func updateSelectionFromCollectionView() {
		let selectedIndexPaths = collectionView.indexPathsForSelectedItems ?? []
		let selectedItems = Set(selectedIndexPaths.compactMap { photos[safe: $0.item] })
		selection = selectedItems
		onSelectionChanged?(selection)
	}
}
#endif

// MARK: - Array Extension

extension Array {
	subscript(safe index: Int) -> Element? {
		guard index >= 0, index < count else { return nil }
		return self[index]
	}
}
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
	let environment: PhotoBrowserEnvironment

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

	init(environment: PhotoBrowserEnvironment) {
		self.environment = environment
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
		layout.minimumLineSpacing = environment.configuration.gridSpacing
		layout.minimumInteritemSpacing = environment.configuration.gridSpacing
		layout.itemSize = environment.configuration.thumbnailSize
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
		updateItemSize()
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

			cell.configure(with: item, source: self.environment.source)
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

	private func updateItemSize() {
		guard let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else { return }

		let width = view.bounds.width
		let spacing = environment.configuration.gridSpacing
		let minColumns = environment.configuration.minimumColumns
		let maxColumns = environment.configuration.maximumColumns

		// Calculate optimal number of columns
		var columns = minColumns
		for cols in minColumns...maxColumns {
			let totalSpacing = spacing * CGFloat(cols + 1)
			let availableWidth = width - totalSpacing
			let itemWidth = availableWidth / CGFloat(cols)

			if itemWidth >= environment.configuration.thumbnailSize.width {
				columns = cols
			} else {
				break
			}
		}

		// Calculate item size
		let totalSpacing = spacing * CGFloat(columns + 1)
		let availableWidth = width - totalSpacing
		let itemWidth = floor(availableWidth / CGFloat(columns))
		let itemSize = CGSize(width: itemWidth, height: itemWidth)

		layout.itemSize = itemSize
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
	let environment: PhotoBrowserEnvironment

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

	init(environment: PhotoBrowserEnvironment) {
		self.environment = environment
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		// Create layout
		let layout = UICollectionViewFlowLayout()
		layout.minimumLineSpacing = environment.configuration.gridSpacing
		layout.minimumInteritemSpacing = environment.configuration.gridSpacing
		layout.itemSize = environment.configuration.thumbnailSize

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
		updateItemSize()
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

			cell.configure(with: item, source: self.environment.source)
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

	private func updateItemSize() {
		guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

		let width = view.bounds.width
		let spacing = environment.configuration.gridSpacing
		let minColumns = environment.configuration.minimumColumns
		let maxColumns = environment.configuration.maximumColumns

		// Calculate optimal number of columns
		var columns = minColumns
		for cols in minColumns...maxColumns {
			let totalSpacing = spacing * CGFloat(cols + 1)
			let availableWidth = width - totalSpacing
			let itemWidth = availableWidth / CGFloat(cols)

			if itemWidth >= environment.configuration.thumbnailSize.width {
				columns = cols
			} else {
				break
			}
		}

		// Calculate item size
		let totalSpacing = spacing * CGFloat(columns + 1)
		let availableWidth = width - totalSpacing
		let itemWidth = floor(availableWidth / CGFloat(columns))
		let itemSize = CGSize(width: itemWidth, height: itemWidth)

		layout.itemSize = itemSize
		layout.invalidateLayout()
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
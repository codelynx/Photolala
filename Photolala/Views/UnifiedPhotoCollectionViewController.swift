//
//  UnifiedPhotoCollectionViewController.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/19.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI
import Combine

/// Delegate protocol for UnifiedPhotoCollectionViewController
protocol UnifiedPhotoCollectionViewControllerDelegate: AnyObject {
	func photoCollection(_ controller: UnifiedPhotoCollectionViewController, didSelectPhoto photo: any PhotoItem, allPhotos: [any PhotoItem])
	func photoCollection(_ controller: UnifiedPhotoCollectionViewController, didUpdateSelection selectedPhotos: [any PhotoItem])
	func photoCollection(_ controller: UnifiedPhotoCollectionViewController, didRequestContextMenu for: any PhotoItem) -> XMenu?
}

/// A unified collection view controller that can display photos from any PhotoProvider
class UnifiedPhotoCollectionViewController: XViewController {
	// MARK: - Properties
	
	weak var delegate: UnifiedPhotoCollectionViewControllerDelegate?
	
	private let photoProvider: any PhotoProvider
	private var collectionView: XCollectionView!
	private var dataSource: XCollectionViewDiffableDataSource<Int, AnyHashable>!
	private var cancellables = Set<AnyCancellable>()
	
	// Settings
	var settings = ThumbnailDisplaySettings() {
		didSet {
			// Only update if view is loaded
			if isViewLoaded {
				updateLayout()
				updateVisibleCells()
			}
		}
	}
	
	// Selection tracking
	private var selectedPhotos = Set<AnyHashable>()
	
	// MARK: - Initialization
	
	init(photoProvider: any PhotoProvider) {
		self.photoProvider = photoProvider
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	// MARK: - View Lifecycle
	
	override func loadView() {
		#if os(macOS)
		let scrollView = NSScrollView()
		scrollView.autoresizingMask = [.width, .height]
		scrollView.hasVerticalScroller = true
		
		let layout = createLayout()
		collectionView = ClickedCollectionView(frame: .zero)
		collectionView.collectionViewLayout = layout
		collectionView.delegate = self
		collectionView.allowsMultipleSelection = true
		collectionView.isSelectable = true
		collectionView.allowsEmptySelection = true
		collectionView.backgroundColors = [.clear]
		
		// Set up collection view for context menus
		collectionView.menu = NSMenu() // Enable context menu support
		
		scrollView.documentView = collectionView
		self.view = scrollView
		#else
		let layout = createLayout()
		collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
		collectionView.delegate = self
		collectionView.allowsMultipleSelection = true
		collectionView.backgroundColor = .systemBackground
		self.view = collectionView
		#endif
		
		setupDataSource()
		bindToPhotoProvider()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Update layout with current settings
		updateLayout()
		
		// Load photos
		Task {
			try? await photoProvider.loadPhotos()
		}
	}
	
	// MARK: - Layout
	
	private func createLayout() -> XCollectionViewLayout {
		#if os(macOS)
		let layout = NSCollectionViewFlowLayout()
		let thumbnailOption = settings.thumbnailOption
		layout.minimumInteritemSpacing = thumbnailOption.spacing
		layout.minimumLineSpacing = thumbnailOption.spacing
		layout.itemSize = NSSize(width: thumbnailOption.size, height: thumbnailOption.size)
		layout.sectionInset = NSEdgeInsets(
			top: thumbnailOption.sectionInset,
			left: thumbnailOption.sectionInset,
			bottom: thumbnailOption.sectionInset,
			right: thumbnailOption.sectionInset
		)
		
		// Configure headers if grouping is enabled
		if settings.groupingOption != .none {
			layout.headerReferenceSize = NSSize(width: 0, height: 40)
		} else {
			layout.headerReferenceSize = NSSize.zero
		}
		
		return layout
		#else
		let thumbnailOption = settings.thumbnailOption
		let itemSize = NSCollectionLayoutSize(
			widthDimension: .absolute(thumbnailOption.size),
			heightDimension: .absolute(thumbnailOption.size)
		)
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		
		let groupSize = NSCollectionLayoutSize(
			widthDimension: .fractionalWidth(1.0),
			heightDimension: .absolute(thumbnailOption.size)
		)
		let group = NSCollectionLayoutGroup.horizontal(
			layoutSize: groupSize,
			subitems: [item]
		)
		group.interItemSpacing = .fixed(thumbnailOption.spacing)
		
		let section = NSCollectionLayoutSection(group: group)
		section.interGroupSpacing = thumbnailOption.spacing
		section.contentInsets = NSDirectionalEdgeInsets(
			top: thumbnailOption.sectionInset,
			leading: thumbnailOption.sectionInset,
			bottom: thumbnailOption.sectionInset,
			trailing: thumbnailOption.sectionInset
		)
		
		// Configure headers if grouping is enabled
		if settings.groupingOption != .none {
			let headerSize = NSCollectionLayoutSize(
				widthDimension: .fractionalWidth(1.0),
				heightDimension: .absolute(40)
			)
			let header = NSCollectionLayoutBoundarySupplementaryItem(
				layoutSize: headerSize,
				elementKind: UICollectionView.elementKindSectionHeader,
				alignment: .top
			)
			section.boundarySupplementaryItems = [header]
		}
		
		return UICollectionViewCompositionalLayout(section: section)
		#endif
	}
	
	private func updateLayout() {
		#if os(macOS)
		if let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
			let thumbnailOption = settings.thumbnailOption
			layout.itemSize = NSSize(width: thumbnailOption.size, height: thumbnailOption.size)
			layout.minimumInteritemSpacing = thumbnailOption.spacing
			layout.minimumLineSpacing = thumbnailOption.spacing
			layout.sectionInset = NSEdgeInsets(
				top: thumbnailOption.sectionInset,
				left: thumbnailOption.sectionInset,
				bottom: thumbnailOption.sectionInset,
				right: thumbnailOption.sectionInset
			)
			
			// Configure headers if grouping is enabled
			if settings.groupingOption != .none {
				layout.headerReferenceSize = NSSize(width: 0, height: 40)
			} else {
				layout.headerReferenceSize = NSSize.zero
			}
			
			layout.invalidateLayout()
		}
		#else
		collectionView.setCollectionViewLayout(createLayout(), animated: true)
		#endif
	}
	
	// MARK: - Data Source
	
	private func setupDataSource() {
		// Register cell
		#if os(macOS)
		collectionView.register(UnifiedPhotoCell.self, forItemWithIdentifier: UnifiedPhotoCell.identifier)
		
		dataSource = NSCollectionViewDiffableDataSource<Int, AnyHashable>(
			collectionView: collectionView
		) { [weak self] collectionView, indexPath, item in
			let cell = collectionView.makeItem(
				withIdentifier: UnifiedPhotoCell.identifier,
				for: indexPath
			) as! UnifiedPhotoCell
			
			if let photo = item.base as? (any PhotoItem) {
				cell.configure(with: photo, settings: self?.settings ?? ThumbnailDisplaySettings())
			}
			
			return cell
		}
		#else
		collectionView.register(UnifiedPhotoCell.self, forCellWithReuseIdentifier: UnifiedPhotoCell.identifier)
		
		dataSource = UICollectionViewDiffableDataSource<Int, AnyHashable>(
			collectionView: collectionView
		) { [weak self] collectionView, indexPath, item in
			let cell = collectionView.dequeueReusableCell(
				withReuseIdentifier: UnifiedPhotoCell.identifier,
				for: indexPath
			) as! UnifiedPhotoCell
			
			if let photo = item.base as? (any PhotoItem) {
				cell.configure(with: photo, settings: self?.settings ?? ThumbnailDisplaySettings())
			}
			
			return cell
		}
		#endif
	}
	
	// MARK: - Photo Provider Binding
	
	private func bindToPhotoProvider() {
		// Subscribe to photo updates
		photoProvider.photosPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] photos in
				self?.updatePhotos(photos)
			}
			.store(in: &cancellables)
		
		// Subscribe to loading state
		photoProvider.isLoadingPublisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] isLoading in
				// Update UI to show loading state if needed
				_ = isLoading
			}
			.store(in: &cancellables)
	}
	
	private func updatePhotos(_ photos: [any PhotoItem]) {
		var snapshot = NSDiffableDataSourceSnapshot<Int, AnyHashable>()
		snapshot.appendSections([0])
		
		// Convert photos to AnyHashable
		let hashablePhotos = photos.map { AnyHashable($0) }
		snapshot.appendItems(hashablePhotos, toSection: 0)
		
		#if os(macOS)
		dataSource.apply(snapshot, animatingDifferences: true)
		#else
		dataSource.apply(snapshot, animatingDifferences: true)
		#endif
		
		// Update selection to remove any photos that no longer exist
		selectedPhotos = selectedPhotos.intersection(Set(hashablePhotos))
		updateSelectionUI()
	}
	
	// MARK: - Selection Handling
	
	private func handleItemClick(at indexPath: IndexPath) {
		guard let item = dataSource.itemIdentifier(for: indexPath),
			  let photo = item.base as? (any PhotoItem) else { return }
		
		// Toggle selection
		if selectedPhotos.contains(item) {
			selectedPhotos.remove(item)
		} else {
			selectedPhotos.insert(item)
		}
		
		updateSelectionUI()
		
		// Notify delegate
		let allPhotos = photoProvider.photos
		delegate?.photoCollection(self, didSelectPhoto: photo, allPhotos: allPhotos)
		
		let selected = selectedPhotos.compactMap { $0.base as? (any PhotoItem) }
		delegate?.photoCollection(self, didUpdateSelection: selected)
	}
	
	#if os(macOS)
	@objc private func performContextMenuAction(_ sender: NSMenuItem) {
		guard let action = sender.representedObject as? () async -> Void else { return }
		Task {
			await action()
		}
	}
	#endif
	
	private func updateSelectionUI() {
		#if os(macOS)
		// Update collection view selection
		let selectedIndexPaths = selectedPhotos.compactMap { item in
			dataSource.indexPath(for: item)
		}
		collectionView.selectionIndexPaths = Set(selectedIndexPaths)
		#else
		// iOS handles selection differently
		#endif
	}
	
	// MARK: - Private Methods
	
	private func updateVisibleCells() {
		#if os(macOS)
		// Update all visible items
		for indexPath in collectionView.indexPathsForVisibleItems() {
			if let item = collectionView.item(at: indexPath) as? UnifiedPhotoCell,
			   let photo = dataSource.itemIdentifier(for: indexPath)?.base as? (any PhotoItem) {
				item.configure(with: photo, settings: settings)
			}
		}
		#else
		// Update all visible cells
		for cell in collectionView.visibleCells {
			if let photoCell = cell as? UnifiedPhotoCell,
			   let indexPath = collectionView.indexPath(for: cell),
			   let photo = dataSource.itemIdentifier(for: indexPath)?.base as? (any PhotoItem) {
				photoCell.configure(with: photo, settings: settings)
			}
		}
		#endif
	}
	
	// MARK: - Public Methods
	
	func refresh() async {
		try? await photoProvider.refresh()
	}
	
	func applyGrouping(_ option: PhotoGroupingOption) async {
		await photoProvider.applyGrouping(option)
	}
	
	func applySorting(_ option: PhotoSortOption) async {
		await photoProvider.applySorting(option)
	}
	
	
	func getSelectedPhotos() -> [any PhotoItem] {
		selectedPhotos.compactMap { $0.base as? (any PhotoItem) }
	}
}

// MARK: - Collection View Delegate

#if os(macOS)
extension UnifiedPhotoCollectionViewController: NSCollectionViewDelegate {
	func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
		// Update selection
		for indexPath in indexPaths {
			if let item = dataSource.itemIdentifier(for: indexPath) {
				selectedPhotos.insert(item)
			}
		}
		updateSelectionDelegate()
	}
	
	func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
		// Update selection
		for indexPath in indexPaths {
			if let item = dataSource.itemIdentifier(for: indexPath) {
				selectedPhotos.remove(item)
			}
		}
		updateSelectionDelegate()
	}
	
	private func updateSelectionDelegate() {
		let selected = selectedPhotos.compactMap { $0.base as? (any PhotoItem) }
		delegate?.photoCollection(self, didUpdateSelection: selected)
	}
	
	// MARK: - Context Menu
	
	func collectionView(_ collectionView: NSCollectionView, menuForItemsAt indexPaths: Set<IndexPath>) -> NSMenu? {
		guard let indexPath = indexPaths.first,
			  let item = dataSource.itemIdentifier(for: indexPath),
			  let photo = item.base as? (any PhotoItem) else { return nil }
		
		// Get context menu from delegate or use default
		if let menu = delegate?.photoCollection(self, didRequestContextMenu: photo) {
			return menu
		} else {
			// Create default context menu
			let menu = NSMenu()
			
			for menuItem in photo.contextMenuItems() {
				let item = NSMenuItem(
					title: menuItem.title,
					action: #selector(performContextMenuAction(_:)),
					keyEquivalent: ""
				)
				item.representedObject = menuItem.action
				item.target = self
				if !menuItem.systemImage.isEmpty {
					item.image = NSImage(systemSymbolName: menuItem.systemImage, accessibilityDescription: nil)
				}
				menu.addItem(item)
			}
			
			return menu.items.count > 0 ? menu : nil
		}
	}
}
#else
extension UnifiedPhotoCollectionViewController: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		handleItemClick(at: indexPath)
	}
}
#endif
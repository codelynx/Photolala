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
			} else {
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
		
		// Set up scroll monitoring for priority loading
		setupScrollMonitoring()
		
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
		// Add 24pt for info bar if shown
		let cellHeight = thumbnailOption.size + (settings.showItemInfo ? 24 : 0)
		layout.itemSize = NSSize(width: thumbnailOption.size, height: cellHeight)
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
		// Add 24pt for info bar if shown
		let cellHeight = thumbnailOption.size + (settings.showItemInfo ? 24 : 0)
		let itemSize = NSCollectionLayoutSize(
			widthDimension: .absolute(thumbnailOption.size),
			heightDimension: .absolute(cellHeight)
		)
		let item = NSCollectionLayoutItem(layoutSize: itemSize)
		
		let groupSize = NSCollectionLayoutSize(
			widthDimension: .fractionalWidth(1.0),
			heightDimension: .absolute(cellHeight)
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
			// Add 24pt for info bar if shown
			let cellHeight = thumbnailOption.size + (settings.showItemInfo ? 24 : 0)
			layout.itemSize = NSSize(width: thumbnailOption.size, height: cellHeight)
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
		// Get current snapshot
		var snapshot = dataSource.snapshot()
		
		// If no sections exist, create one
		if snapshot.numberOfSections == 0 {
			snapshot.appendSections([0])
		}
		
		// Convert photos to AnyHashable
		let newHashablePhotos = photos.map { AnyHashable($0) }
		let newPhotosSet = Set(newHashablePhotos)
		
		// Get current items
		let currentItems = snapshot.itemIdentifiers
		let currentItemsSet = Set(currentItems)
		
		// Find items to remove (in current but not in new)
		let itemsToRemove = currentItems.filter { !newPhotosSet.contains($0) }
		if !itemsToRemove.isEmpty {
			snapshot.deleteItems(itemsToRemove)
		}
		
		// Find items to add (in new but not in current)
		let itemsToAdd = newHashablePhotos.filter { !currentItemsSet.contains($0) }
		if !itemsToAdd.isEmpty {
			snapshot.appendItems(itemsToAdd, toSection: 0)
		}
		
		#if os(macOS)
		dataSource.apply(snapshot, animatingDifferences: true)
		#else
		dataSource.apply(snapshot, animatingDifferences: true)
		#endif
		
		// Update selection to remove any photos that no longer exist
		selectedPhotos = selectedPhotos.intersection(newPhotosSet)
		updateSelectionUI()
	}
	
	// MARK: - Scroll Monitoring for Priority Loading
	
	private func setupScrollMonitoring() {
		// Only set up for DirectoryPhotoProvider
		guard let enhancedProvider = photoProvider as? DirectoryPhotoProvider else { return }
		
		#if os(macOS)
		// Get the scroll view
		guard let scrollView = collectionView.enclosingScrollView else { return }
		
		// Monitor scroll events
		NotificationCenter.default.publisher(for: NSScrollView.didLiveScrollNotification, object: scrollView)
			.throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
			.sink { [weak self] _ in
				self?.updateVisibleRange(for: enhancedProvider)
			}
			.store(in: &cancellables)
		
		NotificationCenter.default.publisher(for: NSScrollView.didEndLiveScrollNotification, object: scrollView)
			.sink { [weak self] _ in
				self?.updateVisibleRange(for: enhancedProvider)
			}
			.store(in: &cancellables)
		#else
		// iOS uses scroll view delegate methods (implemented below)
		#endif
	}
	
	private func updateVisibleRange(for provider: DirectoryPhotoProvider) {
		#if os(macOS)
		provider.updateVisibleRange(for: collectionView)
		#else
		// Calculate visible indices for iOS
		let visibleCells = collectionView.visibleCells
		let visibleIndexPaths = visibleCells.compactMap { collectionView.indexPath(for: $0) }
		if let minIndex = visibleIndexPaths.map({ $0.item }).min(),
		   let maxIndex = visibleIndexPaths.map({ $0.item }).max() {
			provider.updateVisibleRange(minIndex..<(maxIndex + 1))
		}
		#endif
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
			
			// Log starred status from SwiftData catalog (single source of truth)
			Task {
				await logStarredStatus(for: photo)
			}
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
		let visiblePaths = collectionView.indexPathsForVisibleItems()
		for indexPath in visiblePaths {
			if let item = collectionView.item(at: indexPath) as? UnifiedPhotoCell {
				// Need to reconfigure the entire cell to update size constraints
				if let photo = dataSource.itemIdentifier(for: indexPath)?.base as? (any PhotoItem) {
					item.configure(with: photo, settings: settings)
				}
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
				
				// Log starred status from SwiftData catalog (single source of truth)
				if let photo = item.base as? (any PhotoItem) {
					Task {
						await logStarredStatus(for: photo)
					}
				}
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
	
	private func logStarredStatus(for photo: any PhotoItem) async {
		let catalogService = PhotolalaCatalogServiceV2.shared
		
		switch photo {
		case let photoFile as PhotoFile:
			// For local directory photos, check by MD5
			if let md5 = photoFile.md5Hash {
				if let entry = try? await catalogService.findByMD5(md5) {
					let shouldShowStar = entry.isStarred || entry.backupStatus == BackupStatus.uploaded
					print("[Selection] Photo '\(photoFile.filename)': isStarred=\(entry.isStarred), backupStatus=\(entry.backupStatus), SHOULD SHOW STAR=\(shouldShowStar)")
				} else {
					print("[Selection] Photo '\(photoFile.filename)' has NO CATALOG ENTRY")
				}
			} else {
				print("[Selection] Photo '\(photoFile.filename)' has no MD5 hash computed yet")
			}
			
		case let photoApple as PhotoApple:
			// For Apple Photos, check by Apple Photo ID
			if let entry = try? await catalogService.findByApplePhotoID(photoApple.id) {
				let shouldShowStar = entry.isStarred || entry.backupStatus == BackupStatus.uploaded
				print("[Selection] Apple Photo '\(photoApple.filename)': isStarred=\(entry.isStarred), backupStatus=\(entry.backupStatus), SHOULD SHOW STAR=\(shouldShowStar)")
			} else {
				print("[Selection] Apple Photo '\(photoApple.filename)' has NO CATALOG ENTRY")
			}
			
		case let photoS3 as PhotoS3:
			// For S3 photos, check by MD5
			if let entry = try? await catalogService.findByMD5(photoS3.md5) {
				let shouldShowStar = entry.isStarred || entry.backupStatus == BackupStatus.uploaded
				print("[Selection] S3 Photo '\(photoS3.filename)': isStarred=\(entry.isStarred), backupStatus=\(entry.backupStatus), SHOULD SHOW STAR=\(shouldShowStar)")
			} else {
				print("[Selection] S3 Photo '\(photoS3.filename)' has NO CATALOG ENTRY")
			}
			
		default:
			print("[Selection] Unknown photo type: \(type(of: photo))")
		}
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
	
	// Scroll monitoring for iOS
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		if let provider = photoProvider as? DirectoryPhotoProvider {
			updateVisibleRange(for: provider)
		}
	}
	
	func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		if let provider = photoProvider as? DirectoryPhotoProvider {
			updateVisibleRange(for: provider)
		}
	}
	
	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		if !decelerate, let provider = photoProvider as? DirectoryPhotoProvider {
			updateVisibleRange(for: provider)
		}
	}
}
#endif

// MARK: - Scroll to Selection

extension UnifiedPhotoCollectionViewController {
	/// Scrolls to ensure at least one selected item is visible
	func scrollToFirstSelectedItem(animated: Bool = true) {
		#if os(macOS)
		let selectedIndexPaths = collectionView.selectionIndexPaths
		guard let firstSelected = selectedIndexPaths.sorted().first else { return }
		
		// Get the frame of the selected item
		if let itemFrame = collectionView.layoutAttributesForItem(at: firstSelected)?.frame {
			// Calculate visible rect considering the current scroll position
			let visibleRect = collectionView.visibleRect
			
			// Check if the item is already fully visible
			if !visibleRect.contains(itemFrame) {
				// Calculate the target scroll position to center the item if possible
				var targetRect = itemFrame
				
				// Try to center the item vertically
				let centerY = itemFrame.midY - visibleRect.height / 2
				targetRect.origin.y = max(0, centerY)
				targetRect.size.height = visibleRect.height
				
				// Ensure we don't scroll past the content bounds
				let maxY = collectionView.collectionViewLayout?.collectionViewContentSize.height ?? 0
				if targetRect.maxY > maxY {
					targetRect.origin.y = max(0, maxY - targetRect.height)
				}
				
				collectionView.scrollToVisible(targetRect)
			}
		}
		#else
		guard let firstSelected = collectionView.indexPathsForSelectedItems?.sorted().first else { return }
		
		// Use scrollToItem which handles the calculations for us
		collectionView.scrollToItem(
			at: firstSelected,
			at: .centeredVertically,
			animated: animated
		)
		#endif
	}
}

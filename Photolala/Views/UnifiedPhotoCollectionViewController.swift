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
	
	// Grouping
	private var photoGroups: [(title: String, photos: [any PhotoItem])] = []
	
	// Notification observers
	private var backupStatusObserver: NSObjectProtocol?
	private var catalogUpdateObserver: NSObjectProtocol?
	
	// MARK: - Initialization
	
	init(photoProvider: any PhotoProvider) {
		self.photoProvider = photoProvider
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	deinit {
		if let observer = backupStatusObserver {
			NotificationCenter.default.removeObserver(observer)
		}
		if let observer = catalogUpdateObserver {
			NotificationCenter.default.removeObserver(observer)
		}
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
		
		// Set up notification observer for backup status changes
		setupBackupStatusObserver()
		
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
		// TODO: Implement grouping properly
		// if settings.groupingOption != .none {
		// 	layout.headerReferenceSize = NSSize(width: 0, height: 40)
		// } else {
		// 	layout.headerReferenceSize = NSSize.zero
		// }
		
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
		// TODO: Implement grouping properly
		// if settings.groupingOption != .none {
		// 	let headerSize = NSCollectionLayoutSize(
		// 		widthDimension: .fractionalWidth(1.0),
		// 		heightDimension: .absolute(40)
		// 	)
		// 	let header = NSCollectionLayoutBoundarySupplementaryItem(
		// 		layoutSize: headerSize,
		// 		elementKind: UICollectionView.elementKindSectionHeader,
		// 		alignment: .top
		// 	)
		// 	section.boundarySupplementaryItems = [header]
		// }
		
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
			// TODO: Implement grouping properly
			// if settings.groupingOption != .none {
			// 	layout.headerReferenceSize = NSSize(width: 0, height: 40)
			// } else {
			// 	layout.headerReferenceSize = NSSize.zero
			// }
			
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
		// TODO: Register header view when grouping is implemented
		// collectionView.register(
		// 	PhotoGroupHeaderItem.self,
		// 	forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
		// 	withIdentifier: NSUserInterfaceItemIdentifier("PhotoGroupHeader")
		// )
		
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
		
		// TODO: Configure supplementary view provider when grouping is implemented
		// dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
		// 	let header = collectionView.makeSupplementaryView(
		// 		ofKind: kind,
		// 		withIdentifier: NSUserInterfaceItemIdentifier("PhotoGroupHeader"),
		// 		for: indexPath
		// 	) as! PhotoGroupHeaderItem
		// 	
		// 	// Get section title
		// 	if let sectionTitle = self?.getSectionTitle(for: indexPath.section) {
		// 		header.headerView?.configure(with: sectionTitle)
		// 	}
		// 	
		// 	return header
		// }
		#else
		collectionView.register(UnifiedPhotoCell.self, forCellWithReuseIdentifier: UnifiedPhotoCell.identifier)
		// TODO: Register header view when grouping is implemented
		// collectionView.register(
		// 	PhotoGroupHeaderView.self,
		// 	forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
		// 	withReuseIdentifier: PhotoGroupHeaderView.reuseIdentifier
		// )
		
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
		
		// TODO: Configure supplementary view provider when grouping is implemented
		// dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
		// 	guard kind == UICollectionView.elementKindSectionHeader else { return nil }
		// 	
		// 	let header = collectionView.dequeueReusableSupplementaryView(
		// 		ofKind: kind,
		// 		withReuseIdentifier: PhotoGroupHeaderView.reuseIdentifier,
		// 		for: indexPath
		// 	) as! PhotoGroupHeaderView
		// 	
		// 	// Get section title
		// 	if let sectionTitle = self?.getSectionTitle(for: indexPath.section) {
		// 		header.configure(with: sectionTitle)
		// 	}
		// 	
		// 	return header
		// }
		#endif
	}
	
	private func getSectionTitle(for section: Int) -> String? {
		guard settings.groupingOption != .none,
		      section < photoGroups.count else { return nil }
		return photoGroups[section].title
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
		// Create new snapshot
		var snapshot = NSDiffableDataSourceSnapshot<Int, AnyHashable>()
		
		// For now, always use single section mode to prevent crashes
		// TODO: Implement proper grouping support
		photoGroups = [("", photos)]
		snapshot.appendSections([0])
		let hashablePhotos = photos.map { AnyHashable($0) }
		snapshot.appendItems(hashablePhotos, toSection: 0)
		
		#if os(macOS)
		dataSource.apply(snapshot, animatingDifferences: true)
		#else
		dataSource.apply(snapshot, animatingDifferences: true)
		#endif
		
		// Update selection to remove any photos that no longer exist
		let allPhotosSet = Set(photos.map { AnyHashable($0) })
		selectedPhotos = selectedPhotos.intersection(allPhotosSet)
		updateSelectionUI()
	}
	
	private func groupPhotos(_ photos: [any PhotoItem], by option: PhotoGroupingOption) -> [(title: String, photos: [any PhotoItem])] {
		guard option != .none else {
			return [("", photos)]
		}
		
		let formatter = DateFormatter()
		formatter.dateFormat = option.dateFormat
		
		// Sort photos by date
		let sortedPhotos = photos.sorted { photo1, photo2 in
			let date1 = photo1.creationDate ?? Date.distantPast
			let date2 = photo2.creationDate ?? Date.distantPast
			return date1 > date2
		}
		
		// Group by date component
		var groups: [(title: String, photos: [any PhotoItem])] = []
		var currentGroupTitle = ""
		var currentGroupPhotos: [any PhotoItem] = []
		
		for photo in sortedPhotos {
			let photoDate = photo.creationDate ?? Date.distantPast
			let groupTitle = formatter.string(from: photoDate)
			
			if groupTitle != currentGroupTitle {
				// Save previous group if not empty
				if !currentGroupPhotos.isEmpty {
					groups.append((title: currentGroupTitle, photos: currentGroupPhotos))
				}
				// Start new group
				currentGroupTitle = groupTitle
				currentGroupPhotos = [photo]
			} else {
				currentGroupPhotos.append(photo)
			}
		}
		
		// Don't forget the last group
		if !currentGroupPhotos.isEmpty {
			groups.append((title: currentGroupTitle, photos: currentGroupPhotos))
		}
		
		return groups
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
	
	// MARK: - Backup Status Monitoring
	
	private func setupBackupStatusObserver() {
		// Listen for general backup queue changes
		backupStatusObserver = NotificationCenter.default.addObserver(
			forName: NSNotification.Name("BackupQueueChanged"),
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.refreshVisibleCells()
		}
		
		// Listen for specific catalog entry updates (for immediate star updates)
		catalogUpdateObserver = NotificationCenter.default.addObserver(
			forName: NSNotification.Name("CatalogEntryUpdated"),
			object: nil,
			queue: .main
		) { [weak self] notification in
			// If we have an Apple Photo ID, refresh just that cell
			if let applePhotoID = notification.userInfo?["applePhotoID"] as? String {
				self?.refreshCellForApplePhoto(applePhotoID)
			} else {
				// Otherwise refresh all visible cells
				self?.refreshVisibleCells()
			}
		}
	}
	
	private func refreshVisibleCells() {
		#if os(macOS)
		// Get visible items
		let visibleIndexPaths = collectionView.indexPathsForVisibleItems()
		
		// Update each visible cell directly
		for indexPath in visibleIndexPaths {
			if let item = collectionView.item(at: indexPath) as? UnifiedPhotoCell,
			   let photo = dataSource.itemIdentifier(for: indexPath)?.base as? (any PhotoItem) {
				// Re-configure the cell with the same photo to update star status
				item.configure(with: photo, settings: settings)
			}
		}
		#else
		// For iOS, update visible cells
		let visibleIndexPaths = collectionView.indexPathsForVisibleItems
		
		for indexPath in visibleIndexPaths {
			if let cell = collectionView.cellForItem(at: indexPath) as? UnifiedPhotoCell,
			   let photo = dataSource.itemIdentifier(for: indexPath)?.base as? (any PhotoItem) {
				// Re-configure the cell with the same photo to update star status
				cell.configure(with: photo, settings: settings)
			}
		}
		#endif
	}
	
	private func refreshCellForApplePhoto(_ applePhotoID: String) {
		// Find the item with this Apple Photo ID
		let snapshot = dataSource.snapshot()
		let allItems = snapshot.itemIdentifiers
		
		for (index, item) in allItems.enumerated() {
			if let photo = item.base as? PhotoApple, photo.id == applePhotoID {
				// Found the item, update the cell directly
				let indexPath = IndexPath(item: index, section: 0)
				
				#if os(macOS)
				if let cell = collectionView.item(at: indexPath) as? UnifiedPhotoCell {
					cell.configure(with: photo, settings: settings)
				}
				#else
				if let cell = collectionView.cellForItem(at: indexPath) as? UnifiedPhotoCell {
					cell.configure(with: photo, settings: settings)
				}
				#endif
				break
			}
		}
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
			// Task {
			// 	await logStarredStatus(for: photo)
			// }
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
		
		// Notify delegate of selection change
		let selectedPhotoItems = selectedPhotos.compactMap { $0.base as? (any PhotoItem) }
		delegate?.photoCollection(self, didUpdateSelection: selectedPhotoItems)
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
		// For iOS with multi-selection enabled, update our selection tracking
		if let item = dataSource.itemIdentifier(for: indexPath) {
			selectedPhotos.insert(item)
			updateSelectionUI()
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		// Handle deselection
		if let item = dataSource.itemIdentifier(for: indexPath) {
			selectedPhotos.remove(item)
			updateSelectionUI()
		}
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
	
	// MARK: - Keyboard Shortcuts
	
	#if os(macOS)
	override func keyDown(with event: NSEvent) {
		// Check for number keys 1-7 for color flags
		if let characters = event.charactersIgnoringModifiers,
		   characters.count == 1,
		   let char = characters.first,
		   char >= "1" && char <= "7" {
			let flagIndex = Int(String(char))! - 1
			if flagIndex < ColorFlag.allCases.count {
				let flag = ColorFlag.allCases[flagIndex]
				toggleFlagForSelection(flag)
				return
			}
		}
		
		// Check for 0 to clear all flags
		if event.charactersIgnoringModifiers == "0" {
			clearAllFlagsForSelection()
			return
		}
		
		// Check for S to toggle star
		if event.charactersIgnoringModifiers?.lowercased() == "s" {
			toggleStarForSelection()
			return
		}
		
		super.keyDown(with: event)
	}
	
	private func toggleFlagForSelection(_ flag: ColorFlag) {
		let selectedIndexPaths = collectionView.selectionIndexPaths
		guard !selectedIndexPaths.isEmpty else { return }
		
		Task {
			for indexPath in selectedIndexPaths {
				if let photo = photoAtIndexPath(indexPath) {
					await TagManager.shared.toggleFlag(flag, for: photo)
				}
			}
			
			// Update visible cells
			updateVisibleCells()
		}
	}
	
	private func clearAllFlagsForSelection() {
		let selectedIndexPaths = collectionView.selectionIndexPaths
		guard !selectedIndexPaths.isEmpty else { return }
		
		Task {
			for indexPath in selectedIndexPaths {
				if let photo = photoAtIndexPath(indexPath) {
					await TagManager.shared.clearFlags(for: photo)
				}
			}
			
			// Update visible cells
			updateVisibleCells()
		}
	}
	
	private func toggleStarForSelection() {
		let selectedIndexPaths = collectionView.selectionIndexPaths
		guard !selectedIndexPaths.isEmpty else { return }
		
		for indexPath in selectedIndexPaths {
			if let photo = photoAtIndexPath(indexPath) {
				Task { @MainActor in
					if let photoFile = photo as? PhotoFile {
						BackupQueueManager.shared.toggleStar(for: photoFile)
					} else if let photoApple = photo as? PhotoApple {
						// Handle Apple Photos star toggling
						// TODO: Implement Apple Photos star toggling when catalog service supports it
					}
				}
			}
		}
	}
	
	private func photoAtIndexPath(_ indexPath: IndexPath) -> (any PhotoItem)? {
		guard let itemIdentifier = dataSource.itemIdentifier(for: indexPath) else { return nil }
		return photoProvider.photos.first { ($0 as AnyObject) === (itemIdentifier as AnyObject) }
	}
	#endif
}

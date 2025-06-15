//
//  ThumbnailStripViewController.swift
//  Photolala
//
//  Native collection view controller for thumbnail strip
//

import SwiftUI

class ThumbnailStripViewController: XViewController {
	let photos: [PhotoReference]
	var currentIndex: Int
	let thumbnailSize: CGSize
	let onTimerExtend: (() -> Void)?
	
	weak var coordinator: ThumbnailStripView.Coordinator?
	
	#if os(macOS)
	var collectionView: NSCollectionView!
	var scrollView: NSScrollView!
	#else
	var collectionView: UICollectionView!
	#endif
	
	private let cellIdentifier = "ThumbnailCell"
	private let itemSpacing: CGFloat = 8
	private let sectionInset: CGFloat = 16
	private let containerPadding: CGFloat = 12
	
	init(photos: [PhotoReference], currentIndex: Int, thumbnailSize: CGSize, onTimerExtend: (() -> Void)?) {
		self.photos = photos
		self.currentIndex = currentIndex
		self.thumbnailSize = thumbnailSize
		self.onTimerExtend = onTimerExtend
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	#if os(macOS)
	override func loadView() {
		view = NSView()
		view.wantsLayer = true
		view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
		
		// Create collection view
		let flowLayout = NSCollectionViewFlowLayout()
		flowLayout.scrollDirection = .horizontal
		flowLayout.itemSize = NSSize(width: thumbnailSize.width, height: thumbnailSize.height)
		flowLayout.sectionInset = NSEdgeInsets(
			top: containerPadding,
			left: sectionInset,
			bottom: containerPadding,
			right: sectionInset
		)
		flowLayout.minimumInteritemSpacing = itemSpacing
		flowLayout.minimumLineSpacing = itemSpacing
		
		collectionView = NSCollectionView()
		collectionView.collectionViewLayout = flowLayout
		collectionView.delegate = self
		collectionView.dataSource = self
		collectionView.register(
			ThumbnailStripCell.self,
			forItemWithIdentifier: NSUserInterfaceItemIdentifier(cellIdentifier)
		)
		collectionView.backgroundColors = [.clear]
		collectionView.isSelectable = true
		collectionView.allowsMultipleSelection = false
		
		// Create scroll view
		scrollView = NSScrollView()
		scrollView.documentView = collectionView
		scrollView.hasVerticalScroller = false
		scrollView.hasHorizontalScroller = true
		scrollView.autohidesScrollers = true
		scrollView.borderType = .noBorder
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.backgroundColor = .clear
		scrollView.drawsBackground = false
		
		view.addSubview(scrollView)
		
		// Constraints
		NSLayoutConstraint.activate([
			scrollView.topAnchor.constraint(equalTo: view.topAnchor),
			scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			scrollView.heightAnchor.constraint(equalToConstant: thumbnailSize.height + containerPadding * 2)
		])
	}
	#else
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
		
		// Create flow layout
		let flowLayout = UICollectionViewFlowLayout()
		flowLayout.scrollDirection = .horizontal
		flowLayout.itemSize = CGSize(width: thumbnailSize.width, height: thumbnailSize.height)
		flowLayout.sectionInset = UIEdgeInsets(
			top: containerPadding,
			left: sectionInset,
			bottom: containerPadding,
			right: sectionInset
		)
		flowLayout.minimumInteritemSpacing = itemSpacing
		flowLayout.minimumLineSpacing = itemSpacing
		
		// Create collection view
		collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
		collectionView.delegate = self
		collectionView.dataSource = self
		collectionView.prefetchDataSource = self
		collectionView.register(ThumbnailStripCell.self, forCellWithReuseIdentifier: cellIdentifier)
		collectionView.backgroundColor = .clear
		collectionView.showsHorizontalScrollIndicator = false
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		
		view.addSubview(collectionView)
		
		// Constraints
		NSLayoutConstraint.activate([
			collectionView.topAnchor.constraint(equalTo: view.topAnchor),
			collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			collectionView.heightAnchor.constraint(equalToConstant: thumbnailSize.height + containerPadding * 2)
		])
	}
	#endif
	
	#if os(macOS)
	override func viewDidAppear() {
		super.viewDidAppear()
		// Reload data to ensure cells are displayed
		collectionView.reloadData()
		// Set initial selection
		let initialIndexPath = IndexPath(item: currentIndex, section: 0)
		collectionView.selectItems(at: Set([initialIndexPath]), scrollPosition: .centeredHorizontally)
		if let cell = collectionView.item(at: initialIndexPath) as? ThumbnailStripCell {
			cell.setSelected(true, animated: false)
		}
		// Scroll to current photo after view appears
		scrollToCurrentIndex(animated: false)
	}
	#else
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		// Reload data to ensure cells are displayed
		collectionView.reloadData()
		// Set initial selection
		let initialIndexPath = IndexPath(item: currentIndex, section: 0)
		collectionView.selectItem(at: initialIndexPath, animated: false, scrollPosition: .centeredHorizontally)
		if let cell = collectionView.cellForItem(at: initialIndexPath) as? ThumbnailStripCell {
			cell.setSelected(true, animated: false)
		}
		// Scroll to current photo after view appears
		scrollToCurrentIndex(animated: false)
	}
	#endif
	
	func updateCurrentIndex(_ newIndex: Int, animated: Bool) {
		guard newIndex != currentIndex, newIndex >= 0, newIndex < photos.count else { return }
		
		let oldIndex = currentIndex
		currentIndex = newIndex
		
		// Update selection
		let oldIndexPath = IndexPath(item: oldIndex, section: 0)
		let newIndexPath = IndexPath(item: newIndex, section: 0)
		
		#if os(macOS)
		collectionView.deselectItems(at: Set([oldIndexPath]))
		collectionView.selectItems(at: Set([newIndexPath]), scrollPosition: .centeredHorizontally)
		#else
		collectionView.deselectItem(at: oldIndexPath, animated: animated)
		collectionView.selectItem(at: newIndexPath, animated: animated, scrollPosition: .centeredHorizontally)
		#endif
		
		// Update cell appearance
		#if os(macOS)
		if let oldCell = collectionView.item(at: oldIndexPath) as? ThumbnailStripCell {
			oldCell.setSelected(false, animated: animated)
		}
		if let newCell = collectionView.item(at: newIndexPath) as? ThumbnailStripCell {
			newCell.setSelected(true, animated: animated)
		}
		#else
		if let oldCell = collectionView.cellForItem(at: oldIndexPath) as? ThumbnailStripCell {
			oldCell.setSelected(false, animated: animated)
		}
		if let newCell = collectionView.cellForItem(at: newIndexPath) as? ThumbnailStripCell {
			newCell.setSelected(true, animated: animated)
		}
		#endif
	}
	
	private func scrollToCurrentIndex(animated: Bool) {
		let indexPath = IndexPath(item: currentIndex, section: 0)
		#if os(macOS)
		collectionView.scrollToItems(at: Set([indexPath]), scrollPosition: .centeredHorizontally)
		#else
		collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
		#endif
	}
}

// MARK: - Collection View Data Source

extension ThumbnailStripViewController: XCollectionViewDataSource {
	#if os(macOS)
	func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
		return photos.count
	}
	
	func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
		let item = collectionView.makeItem(
			withIdentifier: NSUserInterfaceItemIdentifier(cellIdentifier),
			for: indexPath
		) as! ThumbnailStripCell
		
		let photo = photos[indexPath.item]
		item.configure(with: photo, isSelected: indexPath.item == currentIndex)
		
		return item
	}
	#else
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return photos.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(
			withReuseIdentifier: cellIdentifier,
			for: indexPath
		) as! ThumbnailStripCell
		
		let photo = photos[indexPath.item]
		cell.configure(with: photo, isSelected: indexPath.item == currentIndex)
		
		return cell
	}
	#endif
}

// MARK: - Collection View Delegate

extension ThumbnailStripViewController: XCollectionViewDelegate {
	#if os(macOS)
	func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
		guard let indexPath = indexPaths.first else { return }
		coordinator?.didSelectPhoto(at: indexPath.item)
	}
	#else
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		coordinator?.didSelectPhoto(at: indexPath.item)
	}
	#endif
}

// MARK: - Prefetching (iOS only)

#if os(iOS)
extension ThumbnailStripViewController: UICollectionViewDataSourcePrefetching {
	func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
		// Prefetch thumbnails for upcoming cells
		let photos = indexPaths.map { self.photos[$0.item] }
		Task {
			await PhotoManager.shared.prefetchThumbnails(for: photos)
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
		// Could implement cancellation if needed
	}
}
#endif
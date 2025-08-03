//
//  ThumbnailStripViewController.swift
//  Photolala
//
//  Native collection view controller for thumbnail strip
//

import SwiftUI
import XPlatform

class ThumbnailStripViewController: XViewController {
	let photos: [PhotoFile]
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

	init(photos: [PhotoFile], currentIndex: Int, thumbnailSize: CGSize, onTimerExtend: (() -> Void)?) {
		self.photos = photos
		self.currentIndex = currentIndex
		self.thumbnailSize = thumbnailSize
		self.onTimerExtend = onTimerExtend
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
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
			flowLayout.itemSize = NSSize(width: self.thumbnailSize.width, height: self.thumbnailSize.height)
			flowLayout.sectionInset = NSEdgeInsets(
				top: self.containerPadding,
				left: self.sectionInset,
				bottom: self.containerPadding,
				right: self.sectionInset
			)
			flowLayout.minimumInteritemSpacing = self.itemSpacing
			flowLayout.minimumLineSpacing = self.itemSpacing

			self.collectionView = NSCollectionView()
			self.collectionView.collectionViewLayout = flowLayout
			self.collectionView.delegate = self
			self.collectionView.dataSource = self
			self.collectionView.register(
				ThumbnailStripCell.self,
				forItemWithIdentifier: NSUserInterfaceItemIdentifier(self.cellIdentifier)
			)
			self.collectionView.backgroundColors = [.clear]
			self.collectionView.isSelectable = true
			self.collectionView.allowsMultipleSelection = false

			// Create scroll view
			self.scrollView = NSScrollView()
			self.scrollView.documentView = self.collectionView
			self.scrollView.hasVerticalScroller = false
			self.scrollView.hasHorizontalScroller = true
			self.scrollView.autohidesScrollers = true
			self.scrollView.borderType = .noBorder
			self.scrollView.translatesAutoresizingMaskIntoConstraints = false
			self.scrollView.backgroundColor = .clear
			self.scrollView.drawsBackground = false

			view.addSubview(self.scrollView)

			// Constraints
			NSLayoutConstraint.activate([
				self.scrollView.topAnchor.constraint(equalTo: view.topAnchor),
				self.scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
				self.scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
				self.scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
				self.scrollView.heightAnchor
					.constraint(equalToConstant: self.thumbnailSize.height + self.containerPadding * 2),
			])
		}
	#else
		override func viewDidLoad() {
			super.viewDidLoad()

			view.backgroundColor = UIColor.black.withAlphaComponent(0.8)

			// Create flow layout
			let flowLayout = UICollectionViewFlowLayout()
			flowLayout.scrollDirection = .horizontal
			flowLayout.itemSize = CGSize(width: self.thumbnailSize.width, height: self.thumbnailSize.height)
			flowLayout.sectionInset = UIEdgeInsets(
				top: self.containerPadding,
				left: self.sectionInset,
				bottom: self.containerPadding,
				right: self.sectionInset
			)
			flowLayout.minimumInteritemSpacing = self.itemSpacing
			flowLayout.minimumLineSpacing = self.itemSpacing

			// Create collection view
			self.collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
			self.collectionView.delegate = self
			self.collectionView.dataSource = self
			self.collectionView.prefetchDataSource = self
			self.collectionView.register(ThumbnailStripCell.self, forCellWithReuseIdentifier: self.cellIdentifier)
			self.collectionView.backgroundColor = .clear
			self.collectionView.showsHorizontalScrollIndicator = false
			self.collectionView.translatesAutoresizingMaskIntoConstraints = false

			view.addSubview(self.collectionView)

			// Constraints
			NSLayoutConstraint.activate([
				self.collectionView.topAnchor.constraint(equalTo: view.topAnchor),
				self.collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
				self.collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
				self.collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
				self.collectionView.heightAnchor
					.constraint(equalToConstant: self.thumbnailSize.height + self.containerPadding * 2),
			])
		}
	#endif

	#if os(macOS)
		override func viewDidAppear() {
			super.viewDidAppear()
			// Reload data to ensure cells are displayed
			self.collectionView.reloadData()
			// Set initial selection
			let initialIndexPath = IndexPath(item: currentIndex, section: 0)
			self.collectionView.selectItems(at: Set([initialIndexPath]), scrollPosition: .centeredHorizontally)
			if let cell = collectionView.item(at: initialIndexPath) as? ThumbnailStripCell {
				cell.setSelected(true, animated: false)
			}
			// Scroll to current photo after view appears
			self.scrollToCurrentIndex(animated: false)
		}
	#else
		override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)
			// Reload data to ensure cells are displayed
			self.collectionView.reloadData()
			// Set initial selection
			let initialIndexPath = IndexPath(item: currentIndex, section: 0)
			self.collectionView.selectItem(at: initialIndexPath, animated: false, scrollPosition: .centeredHorizontally)
			if let cell = collectionView.cellForItem(at: initialIndexPath) as? ThumbnailStripCell {
				cell.setSelected(true, animated: false)
			}
			// Scroll to current photo after view appears
			self.scrollToCurrentIndex(animated: false)
		}
	#endif

	func updateCurrentIndex(_ newIndex: Int, animated: Bool) {
		guard newIndex != self.currentIndex, newIndex >= 0, newIndex < self.photos.count else { return }

		let oldIndex = self.currentIndex
		self.currentIndex = newIndex

		// Update selection
		let oldIndexPath = IndexPath(item: oldIndex, section: 0)
		let newIndexPath = IndexPath(item: newIndex, section: 0)

		#if os(macOS)
			self.collectionView.deselectItems(at: Set([oldIndexPath]))
			self.collectionView.selectItems(at: Set([newIndexPath]), scrollPosition: .centeredHorizontally)
		#else
			self.collectionView.deselectItem(at: oldIndexPath, animated: animated)
			self.collectionView.selectItem(at: newIndexPath, animated: animated, scrollPosition: .centeredHorizontally)
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
			self.collectionView.scrollToItems(at: Set([indexPath]), scrollPosition: .centeredHorizontally)
		#else
			self.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
		#endif
	}
}

// MARK: - Collection View Data Source

extension ThumbnailStripViewController: XCollectionViewDataSource {
	#if os(macOS)
		func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
			self.photos.count
		}

		func collectionView(
			_ collectionView: NSCollectionView,
			itemForRepresentedObjectAt indexPath: IndexPath
		) -> NSCollectionViewItem {
			let item = collectionView.makeItem(
				withIdentifier: NSUserInterfaceItemIdentifier(self.cellIdentifier),
				for: indexPath
			) as! ThumbnailStripCell

			let photo = self.photos[indexPath.item]
			item.configure(with: photo, isSelected: indexPath.item == self.currentIndex)

			return item
		}
	#else
		func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
			self.photos.count
		}

		func collectionView(
			_ collectionView: UICollectionView,
			cellForItemAt indexPath: IndexPath
		) -> UICollectionViewCell {
			let cell = collectionView.dequeueReusableCell(
				withReuseIdentifier: self.cellIdentifier,
				for: indexPath
			) as! ThumbnailStripCell

			let photo = self.photos[indexPath.item]
			cell.configure(with: photo, isSelected: indexPath.item == self.currentIndex)

			return cell
		}
	#endif
}

// MARK: - Collection View Delegate

extension ThumbnailStripViewController: XCollectionViewDelegate {
	#if os(macOS)
		func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
			guard let indexPath = indexPaths.first else { return }
			self.coordinator?.didSelectPhoto(at: indexPath.item)
		}
	#else
		func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
			self.coordinator?.didSelectPhoto(at: indexPath.item)
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
				await PhotoManagerV2.shared.prefetchThumbnails(for: photos)
			}
		}

		func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
			// Could implement cancellation if needed
		}
	}
#endif

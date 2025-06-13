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

	@MainActor
	var photos: [PhotoRepresentation] = []
	var onSelectPhoto: ((PhotoRepresentation, [PhotoRepresentation]) -> Void)?
	var onSelectFolder: ((PhotoRepresentation) -> Void)?
	
	var collectionView: XCollectionView!
	
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
		
		collectionView.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
		
		view.addSubview(collectionView)
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
	
	// MARK: - Navigation
	
	private func handleSelection(at indexPath: IndexPath) {
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
		cell.photoRepresentation = photo
		cell.updateCornerRadius()
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
		
		if event.clickCount == 2 {
			// Handle double-click
			let point = collectionView.convert(event.locationInWindow, from: nil)
			if let indexPath = collectionView.indexPathForItem(at: point) {
				handleSelection(at: indexPath)
			}
		}
	}
	#endif

	internal func collectionView(_ collectionView: XCollectionView, didSelectItemAt indexPath: IndexPath) {
		handleSelection(at: indexPath)
	}
}

// MARK: - Collection View Items

#if os(macOS)
class PhotoCollectionViewItem: NSCollectionViewItem {
	weak var settings: ThumbnailDisplaySettings?
	var photoRepresentation: PhotoRepresentation? {
		didSet {
			loadThumbnail()
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

}
#else
class PhotoCollectionViewCell: UICollectionViewCell {
	weak var settings: ThumbnailDisplaySettings?
	var photoRepresentation: PhotoRepresentation? {
		didSet {
			loadThumbnail()
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
}
#endif

// MARK: - SwiftUI Hosting View

struct PhotoCollectionView: XViewControllerRepresentable {
	let directoryPath: NSString
	let settings: ThumbnailDisplaySettings
	var onSelectPhoto: ((PhotoRepresentation, [PhotoRepresentation]) -> Void)?
	var onSelectFolder: ((PhotoRepresentation) -> Void)?
	
	#if os(macOS)
	func makeNSViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(directoryPath: directoryPath)
		controller.settings = settings
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		return controller
	}
	
	func updateNSViewController(_ nsViewController: PhotoCollectionViewController, context: Context) {
		nsViewController.settings = settings
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
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		return controller
	}
	
	func updateUIViewController(_ uiViewController: PhotoCollectionViewController, context: Context) {
		uiViewController.settings = settings
		uiViewController.onSelectPhoto = onSelectPhoto
		uiViewController.onSelectFolder = onSelectFolder
		// Trigger layout update when settings change
		uiViewController.updateCollectionViewLayout()
	}
	#endif
	
}

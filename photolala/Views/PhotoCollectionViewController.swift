//
//  PhotoCollectionViewController.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - PhotoCollectionViewController

class PhotoCollectionViewController: XViewController {
	let directoryPath: NSString

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
	}
	
	private func createLayout() -> NSCollectionViewLayout {
		let flowLayout = NSCollectionViewFlowLayout()
		flowLayout.itemSize = NSSize(width: 150, height: 150)
		flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
		flowLayout.minimumInteritemSpacing = 8
		flowLayout.minimumLineSpacing = 8
		return flowLayout
	}
#else
	override func viewDidLoad() {
		super.viewDidLoad()
		setupCollectionView()
		loadPhotos()
	}
	
	private func setupCollectionView() {
		let layout = UICollectionViewFlowLayout()
		layout.itemSize = CGSize(width: 150, height: 150)
		layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
		layout.minimumInteritemSpacing = 8
		layout.minimumLineSpacing = 8
		
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
		item.photoRepresentation = photo
		return item
	}
	#endif

	#if os(iOS)
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCollectionViewCell
		let photo = photos[indexPath.item]
		cell.photoRepresentation = photo
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
		imageView.layer?.cornerRadius = 8
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
						self.update(thumbnail: thumbnail, for: photoRepresentation)
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
	func update(thumbnail: XImage?, for photoRep: PhotoRepresentation) {
		if photoRepresentation == photoRep {
			imageView?.image = thumbnail
		}
	}

}
#else
class PhotoCollectionViewCell: UICollectionViewCell {
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
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.layer.cornerRadius = 8
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
}
#endif

// MARK: - SwiftUI Hosting View

struct PhotoCollectionView: XViewControllerRepresentable {
	let directoryPath: NSString
	var onSelectPhoto: ((PhotoRepresentation, [PhotoRepresentation]) -> Void)?
	var onSelectFolder: ((PhotoRepresentation) -> Void)?
	
	#if os(macOS)
	func makeNSViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(directoryPath: directoryPath)
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		return controller
	}
	
	func updateNSViewController(_ nsViewController: PhotoCollectionViewController, context: Context) {
		nsViewController.onSelectPhoto = onSelectPhoto
		nsViewController.onSelectFolder = onSelectFolder
	}
	#endif

	#if os(iOS)
	func makeUIViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(directoryPath: directoryPath)
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		return controller
	}
	
	func updateUIViewController(_ uiViewController: PhotoCollectionViewController, context: Context) {
		uiViewController.onSelectPhoto = onSelectPhoto
		uiViewController.onSelectFolder = onSelectFolder
	}
	#endif
	
}

//
//  PhotoCollectionViewController.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI
#if os(macOS)
import AppKit

class PhotoCollectionViewController: NSViewController {
	let folderURL: URL
	var photos: [URL] = []
	var onSelectPhoto: ((URL, [URL]) -> Void)?
	var onSelectFolder: ((URL) -> Void)?
	
	@IBOutlet weak var collectionView: NSCollectionView!
	
	init(folderURL: URL) {
		self.folderURL = folderURL
		super.init(nibName: nil, bundle: nil)
		self.title = folderURL.lastPathComponent
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
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
		
		let collectionView = NSCollectionView()
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
	
	private func loadPhotos() {
		// For bundle resources
		if folderURL.scheme == "bundle-photos" {
			photos = BundlePhotosHelper.getAllBundlePhotos()
		} else {
			// For regular directories
			do {
				let contents = try FileManager.default.contentsOfDirectory(
					at: folderURL,
					includingPropertiesForKeys: [.isRegularFileKey],
					options: [.skipsHiddenFiles]
				)
				
				let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp"]
				photos = contents.filter { url in
					imageExtensions.contains(url.pathExtension.lowercased())
				}
			} catch {
				print("Error loading photos: \(error)")
			}
		}
		
		collectionView.reloadData()
	}
}

extension PhotoCollectionViewController: NSCollectionViewDataSource {
	func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
		return photos.count
	}
	
	func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
		let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("PhotoItem"), for: indexPath) as! PhotoCollectionViewItem
		item.photoURL = photos[indexPath.item]
		return item
	}
}

extension PhotoCollectionViewController: NSCollectionViewDelegate {
	func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
		// Handle selection
	}
	
	override func mouseDown(with event: NSEvent) {
		super.mouseDown(with: event)
		
		if event.clickCount == 2 {
			// Handle double-click
			let point = collectionView.convert(event.locationInWindow, from: nil)
			if let indexPath = collectionView.indexPathForItem(at: point) {
				let photoURL = photos[indexPath.item]
				
				// Check if it's a directory
				var isDirectory: ObjCBool = false
				if FileManager.default.fileExists(atPath: photoURL.path, isDirectory: &isDirectory) {
					if isDirectory.boolValue {
						onSelectFolder?(photoURL)
					} else {
						onSelectPhoto?(photoURL, photos)
					}
				}
			}
		}
	}
}

// Collection View Item
class PhotoCollectionViewItem: NSCollectionViewItem {
	var photoURL: URL? {
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
		imageView.layer?.borderColor = NSColor.separatorColor.cgColor
		
		self.imageView = imageView
		view.addSubview(imageView)
		
		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: view.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}
	
	private func loadThumbnail() {
		guard let url = photoURL else { return }
		
		// Simple thumbnail loading for now
		DispatchQueue.global(qos: .userInitiated).async {
			if let image = NSImage(contentsOf: url) {
				DispatchQueue.main.async {
					self.imageView?.image = image
				}
			}
		}
	}
}

// SwiftUI Hosting View
struct PhotoCollectionView: NSViewControllerRepresentable {
	let folderURL: URL
	var onSelectPhoto: ((URL, [URL]) -> Void)?
	var onSelectFolder: ((URL) -> Void)?
	
	func makeNSViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(folderURL: folderURL)
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		return controller
	}
	
	func updateNSViewController(_ nsViewController: PhotoCollectionViewController, context: Context) {
		nsViewController.onSelectPhoto = onSelectPhoto
		nsViewController.onSelectFolder = onSelectFolder
	}
}

#else
import UIKit

// iOS Implementation
class PhotoCollectionViewController: UIViewController {
	let folderURL: URL
	var photos: [URL] = []
	var collectionView: UICollectionView!
	var onSelectPhoto: ((URL, [URL]) -> Void)?
	var onSelectFolder: ((URL) -> Void)?
	
	init(folderURL: URL) {
		self.folderURL = folderURL
		super.init(nibName: nil, bundle: nil)
		self.title = folderURL.lastPathComponent
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
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
		
		collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
		collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		collectionView.backgroundColor = .systemBackground
		collectionView.dataSource = self
		collectionView.delegate = self
		
		collectionView.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
		
		view.addSubview(collectionView)
	}
	
	private func loadPhotos() {
		// Similar to macOS implementation
		if folderURL.scheme == "bundle-photos" {
			photos = BundlePhotosHelper.getAllBundlePhotos()
		} else {
			do {
				let contents = try FileManager.default.contentsOfDirectory(
					at: folderURL,
					includingPropertiesForKeys: [.isRegularFileKey],
					options: [.skipsHiddenFiles]
				)
				
				let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp"]
				photos = contents.filter { url in
					imageExtensions.contains(url.pathExtension.lowercased())
				}
			} catch {
				print("Error loading photos: \(error)")
			}
		}
		
		collectionView.reloadData()
	}
}

extension PhotoCollectionViewController: UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return photos.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCollectionViewCell
		cell.photoURL = photos[indexPath.item]
		return cell
	}
}

extension PhotoCollectionViewController: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let photoURL = photos[indexPath.item]
		
		// Check if it's a directory
		var isDirectory: ObjCBool = false
		if FileManager.default.fileExists(atPath: photoURL.path, isDirectory: &isDirectory) {
			if isDirectory.boolValue {
				onSelectFolder?(photoURL)
			} else {
				onSelectPhoto?(photoURL, photos)
			}
		}
	}
}

// Collection View Cell
class PhotoCollectionViewCell: UICollectionViewCell {
	var photoURL: URL? {
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
		imageView.layer.borderColor = UIColor.separator.cgColor
		
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
		guard let url = photoURL else { return }
		
		// Simple thumbnail loading for now
		DispatchQueue.global(qos: .userInitiated).async {
			if let data = try? Data(contentsOf: url),
			   let image = UIImage(data: data) {
				DispatchQueue.main.async {
					self.imageView.image = image
				}
			}
		}
	}
}

// SwiftUI Hosting View
struct PhotoCollectionView: UIViewControllerRepresentable {
	let folderURL: URL
	var onSelectPhoto: ((URL, [URL]) -> Void)?
	var onSelectFolder: ((URL) -> Void)?
	
	func makeUIViewController(context: Context) -> PhotoCollectionViewController {
		let controller = PhotoCollectionViewController(folderURL: folderURL)
		controller.onSelectPhoto = onSelectPhoto
		controller.onSelectFolder = onSelectFolder
		return controller
	}
	
	func updateUIViewController(_ uiViewController: PhotoCollectionViewController, context: Context) {
		uiViewController.onSelectPhoto = onSelectPhoto
		uiViewController.onSelectFolder = onSelectFolder
	}
}

#endif
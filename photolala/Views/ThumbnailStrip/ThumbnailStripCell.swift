//
//  ThumbnailStripCell.swift
//  Photolala
//
//  Reusable cell for thumbnail strip collection view
//

import SwiftUI

#if os(macOS)
class ThumbnailStripCell: NSCollectionViewItem {
	private var thumbnailImageView: NSImageView!
	private var loadingIndicator: NSProgressIndicator!
	private var selectionBorder: CALayer!
	
	private var currentPhoto: PhotoReference?
	private var loadTask: Task<Void, Never>?
	private var isSelectedState: Bool = false
	
	// Constants for border styling
	private let regularBorderWidth: CGFloat = 0
	private let selectedBorderWidth: CGFloat = 3
	private let regularBorderColor = NSColor.clear.cgColor
	private let selectedBorderColor = NSColor.systemBlue.cgColor
	
	override func loadView() {
		view = NSView()
		view.wantsLayer = true
		
		// Create image view
		thumbnailImageView = NSImageView()
		thumbnailImageView.imageScaling = .scaleAxesIndependently
		thumbnailImageView.wantsLayer = true
		thumbnailImageView.layer?.cornerRadius = 4
		thumbnailImageView.layer?.masksToBounds = true
		thumbnailImageView.layer?.contentsGravity = .resizeAspectFill
		thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
		
		// Create loading indicator
		loadingIndicator = NSProgressIndicator()
		loadingIndicator.style = .spinning
		loadingIndicator.controlSize = .small
		loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
		loadingIndicator.isHidden = true
		
		// Create selection border
		selectionBorder = CALayer()
		selectionBorder.borderColor = regularBorderColor
		selectionBorder.borderWidth = regularBorderWidth
		selectionBorder.cornerRadius = 4
		
		view.addSubview(thumbnailImageView)
		view.addSubview(loadingIndicator)
		
		// Add selection border on top
		view.wantsLayer = true
		view.layer?.addSublayer(selectionBorder)
		selectionBorder.zPosition = 100 // Ensure it's on top
		
		// Set background
		view.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.3).cgColor
		view.layer?.cornerRadius = 4
		
		NSLayoutConstraint.activate([
			thumbnailImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
			thumbnailImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
			thumbnailImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
			thumbnailImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),
			
			loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
		])
	}
	
	override func viewDidLayout() {
		super.viewDidLayout()
		selectionBorder.frame = view.bounds
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		thumbnailImageView.image = nil
		currentPhoto = nil
		loadTask?.cancel()
		loadTask = nil
		setSelected(false, animated: false)
		view.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.3).cgColor
	}
	
	func configure(with photo: PhotoReference, isSelected: Bool) {
		currentPhoto = photo
		setSelected(isSelected, animated: false)
		
		// Check if thumbnail is already cached in PhotoReference
		if let cached = photo.thumbnail {
			thumbnailImageView.image = cached
			view.layer?.backgroundColor = nil
			loadingIndicator.stopAnimation(nil)
			loadingIndicator.isHidden = true
		} else {
			// Show loading state and load thumbnail
			thumbnailImageView.image = nil
			view.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.3).cgColor
			loadingIndicator.isHidden = false
			loadingIndicator.startAnimation(nil)
			
			// Load thumbnail
			loadTask = Task { @MainActor in
				await loadThumbnail(for: photo)
			}
		}
	}
	
	func setSelected(_ selected: Bool, animated: Bool) {
		isSelectedState = selected
		
		let duration = animated ? 0.2 : 0
		
		NSAnimationContext.runAnimationGroup { context in
			context.duration = duration
			context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
			
			if selected {
				selectionBorder.borderWidth = selectedBorderWidth
				selectionBorder.borderColor = selectedBorderColor
				view.animator().layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
			} else {
				selectionBorder.borderWidth = regularBorderWidth
				selectionBorder.borderColor = regularBorderColor
				view.animator().layer?.transform = CATransform3DIdentity
			}
		}
	}
	
	private func loadThumbnail(for photo: PhotoReference) async {
		do {
			// Check for cancellation
			if Task.isCancelled { return }
			
			if let thumbnail = try await PhotoManager.shared.thumbnail(for: photo) {
				// Check if still showing same photo
				guard currentPhoto === photo else { return }
				
				thumbnailImageView.image = thumbnail
				view.layer?.backgroundColor = nil
				loadingIndicator.stopAnimation(nil)
				loadingIndicator.isHidden = true
			}
		} catch {
			// Show error state
			guard currentPhoto === photo else { return }
			view.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
			loadingIndicator.stopAnimation(nil)
			loadingIndicator.isHidden = true
		}
	}
}

#else

class ThumbnailStripCell: UICollectionViewCell {
	private var thumbnailImageView: UIImageView!
	private var loadingIndicator: UIActivityIndicatorView!
	private var selectionBorder: CALayer!
	
	private var currentPhoto: PhotoReference?
	private var loadTask: Task<Void, Never>?
	private var isSelectedState: Bool = false
	
	// Constants for border styling
	private let normalBorderWidth: CGFloat = 1
	private let selectedBorderWidth: CGFloat = 3
	private let normalBorderColor = UIColor.white.cgColor
	private let selectedBorderColor = UIColor.systemBlue.cgColor
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func setupViews() {
		contentView.layer.cornerRadius = 4
		contentView.clipsToBounds = true
		contentView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
		
		// Create image view
		thumbnailImageView = UIImageView()
		thumbnailImageView.contentMode = .scaleAspectFill
		thumbnailImageView.clipsToBounds = true
		thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
		
		// Create loading indicator
		loadingIndicator = UIActivityIndicatorView(style: .medium)
		loadingIndicator.color = .white
		loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
		loadingIndicator.hidesWhenStopped = true
		
		// Create selection border
		selectionBorder = CALayer()
		selectionBorder.borderColor = normalBorderColor
		selectionBorder.borderWidth = normalBorderWidth
		selectionBorder.cornerRadius = 4
		selectionBorder.frame = contentView.bounds
		
		contentView.addSubview(thumbnailImageView)
		contentView.addSubview(loadingIndicator)
		contentView.layer.addSublayer(selectionBorder)
		selectionBorder.zPosition = 100 // Ensure it's on top
		
		NSLayoutConstraint.activate([
			thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
			thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
			thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
			thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
			
			loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
			loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
		])
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		selectionBorder.frame = contentView.bounds
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		thumbnailImageView.image = nil
		currentPhoto = nil
		loadTask?.cancel()
		loadTask = nil
		setSelected(false, animated: false)
		contentView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
	}
	
	func configure(with photo: PhotoReference, isSelected: Bool) {
		currentPhoto = photo
		setSelected(isSelected, animated: false)
		
		// Check if thumbnail is already cached in PhotoReference
		if let cached = photo.thumbnail {
			thumbnailImageView.image = cached
			contentView.backgroundColor = nil
			loadingIndicator.stopAnimating()
		} else {
			// Show loading state and load thumbnail
			thumbnailImageView.image = nil
			contentView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
			loadingIndicator.startAnimating()
			
			// Load thumbnail
			loadTask = Task { @MainActor in
				await loadThumbnail(for: photo)
			}
		}
	}
	
	func setSelected(_ selected: Bool, animated: Bool) {
		isSelectedState = selected
		
		let duration = animated ? 0.2 : 0
		
		UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
			if selected {
				self.selectionBorder.borderWidth = self.selectedBorderWidth
				self.selectionBorder.borderColor = self.selectedBorderColor
				self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
			} else {
				self.selectionBorder.borderWidth = self.normalBorderWidth
				self.selectionBorder.borderColor = self.normalBorderColor
				self.transform = .identity
			}
		}
	}
	
	private func loadThumbnail(for photo: PhotoReference) async {
		do {
			// Check for cancellation
			if Task.isCancelled { return }
			
			if let thumbnail = try await PhotoManager.shared.thumbnail(for: photo) {
				// Check if still showing same photo
				guard currentPhoto === photo else { return }
				
				thumbnailImageView.image = thumbnail
				contentView.backgroundColor = nil
				loadingIndicator.stopAnimating()
			}
		} catch {
			// Show error state
			guard currentPhoto === photo else { return }
			contentView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
			loadingIndicator.stopAnimating()
		}
	}
}
#endif

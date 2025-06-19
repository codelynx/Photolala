//
//  UnifiedPhotoCell.swift
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

#if os(macOS)
/// NSCollectionViewItem for displaying any PhotoItem
class UnifiedPhotoCell: NSCollectionViewItem {
	static let identifier = NSUserInterfaceItemIdentifier("UnifiedPhotoCell")
	
	// UI Elements
	private var photoImageView: ScalableImageView!
	private var titleLabel: NSTextField!
	private var badgeView: NSView?
	private var loadingIndicator: NSProgressIndicator!
	
	// Constraints
	private var imageViewWidthConstraint: NSLayoutConstraint!
	private var imageViewHeightConstraint: NSLayoutConstraint!
	
	// Current photo
	private var currentPhoto: (any PhotoItem)?
	private var thumbnailTask: Task<Void, Never>?
	
	override func loadView() {
		self.view = NSView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
		
		// Image view
		photoImageView = ScalableImageView()
		photoImageView.translatesAutoresizingMaskIntoConstraints = false
		photoImageView.scaleMode = .scaleToFit // Default to fit
		photoImageView.wantsLayer = true
		photoImageView.layer?.backgroundColor = NSColor.secondarySystemFill.cgColor
		photoImageView.layer?.cornerRadius = 8
		photoImageView.layer?.masksToBounds = true
		photoImageView.layer?.borderWidth = 1.0
		photoImageView.layer?.borderColor = XColor.black.withAlphaComponent(0.2).cgColor
		
		view.addSubview(photoImageView)
		
		// Title label
		titleLabel = NSTextField(labelWithString: "")
		titleLabel.font = .systemFont(ofSize: 11)
		titleLabel.textColor = .labelColor
		titleLabel.alignment = .center
		titleLabel.lineBreakMode = .byTruncatingTail
		titleLabel.maximumNumberOfLines = 2
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(titleLabel)
		
		// Loading indicator
		loadingIndicator = NSProgressIndicator()
		loadingIndicator.style = .spinning
		loadingIndicator.controlSize = .small
		loadingIndicator.isDisplayedWhenStopped = false
		loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(loadingIndicator)
		
		// Create constraints
		imageViewWidthConstraint = photoImageView.widthAnchor.constraint(equalToConstant: 150)
		imageViewHeightConstraint = photoImageView.heightAnchor.constraint(equalToConstant: 150)
		
		// Constraints
		NSLayoutConstraint.activate([
			// Image view - centered and constrained size
			photoImageView.topAnchor.constraint(equalTo: view.topAnchor),
			photoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			photoImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			imageViewWidthConstraint,
			imageViewHeightConstraint,
			
			// Title label
			titleLabel.topAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: 4),
			titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
			titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
			titleLabel.heightAnchor.constraint(equalToConstant: 20),
			
			// Loading indicator
			loadingIndicator.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			loadingIndicator.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor)
		])
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		thumbnailTask?.cancel()
		thumbnailTask = nil
		photoImageView.image = nil
		titleLabel.stringValue = ""
		badgeView?.removeFromSuperview()
		badgeView = nil
		loadingIndicator.stopAnimation(nil)
	}
	
	func configure(with photo: any PhotoItem, settings: ThumbnailDisplaySettings) {
		currentPhoto = photo
		titleLabel.stringValue = photo.displayName
		
		// Update image view constraints based on thumbnail option
		imageViewWidthConstraint.constant = settings.thumbnailOption.size
		imageViewHeightConstraint.constant = settings.thumbnailOption.size
		photoImageView.layer?.cornerRadius = settings.thumbnailOption.cornerRadius
		
		// Update title visibility based on showItemInfo
		titleLabel.isHidden = !settings.showItemInfo
		
		// Update display mode
		updateDisplayMode(settings.displayMode)
		
		// Update selection appearance
		updateSelectionAppearance()
		
		// Add badge if archived
		if photo.isArchived {
			addArchiveBadge()
		}
		
		// Load thumbnail
		loadThumbnail(for: photo)
		
		// Force initial layout
		view.needsLayout = true
		view.needsDisplay = true
	}
	
	private func loadThumbnail(for photo: any PhotoItem) {
		loadingIndicator.startAnimation(nil)
		
		thumbnailTask?.cancel()
		thumbnailTask = Task { @MainActor in
			do {
				if let thumbnail = try await photo.loadThumbnail() {
					guard !Task.isCancelled else { return }
					self.photoImageView.image = thumbnail
					self.photoImageView.needsLayout = true
					self.view.needsDisplay = true
				} else {
					// Show placeholder
					self.photoImageView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
					self.photoImageView.needsLayout = true
					self.view.needsDisplay = true
				}
			} catch {
				guard !Task.isCancelled else { return }
				// Show error placeholder
				self.photoImageView.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
				self.photoImageView.needsLayout = true
				self.view.needsDisplay = true
			}
			self.loadingIndicator.stopAnimation(nil)
		}
	}
	
	private func updateDisplayMode(_ mode: ThumbnailDisplayMode) {
		// Update image scaling based on display mode
		switch mode {
		case .scaleToFit:
			photoImageView.scaleMode = .scaleToFit
		case .scaleToFill:
			photoImageView.scaleMode = .scaleToFill
		}
	}
	
	private func addArchiveBadge() {
		let badge = NSView()
		badge.wantsLayer = true
		badge.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.9).cgColor
		badge.layer?.cornerRadius = 4
		badge.translatesAutoresizingMaskIntoConstraints = false
		
		let iconView = NSImageView()
		iconView.image = NSImage(systemSymbolName: "archivebox", accessibilityDescription: nil)
		iconView.contentTintColor = .white
		iconView.translatesAutoresizingMaskIntoConstraints = false
		
		badge.addSubview(iconView)
		view.addSubview(badge)
		
		NSLayoutConstraint.activate([
			badge.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
			badge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
			badge.widthAnchor.constraint(equalToConstant: 24),
			badge.heightAnchor.constraint(equalToConstant: 24),
			
			iconView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
			iconView.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
			iconView.widthAnchor.constraint(equalToConstant: 14),
			iconView.heightAnchor.constraint(equalToConstant: 14)
		])
		
		badgeView = badge
	}
	
	private func updateSelectionAppearance() {
		if isSelected {
			view.layer?.borderWidth = 3
			view.layer?.borderColor = NSColor.controlAccentColor.cgColor
			view.layer?.cornerRadius = 8
		} else {
			view.layer?.borderWidth = 0
		}
	}
	
	override var isSelected: Bool {
		didSet {
			updateSelectionAppearance()
		}
	}
}

#else

/// UICollectionViewCell for displaying any PhotoItem
class UnifiedPhotoCell: UICollectionViewCell {
	static let identifier = "UnifiedPhotoCell"
	
	// UI Elements
	private var photoImageView: UIImageView!
	private var titleLabel: UILabel!
	private var badgeView: UIView?
	private var loadingIndicator: UIActivityIndicatorView!
	
	// Current photo
	private var currentPhoto: (any PhotoItem)?
	private var thumbnailTask: Task<Void, Never>?
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupViews()
	}
	
	private func setupViews() {
		// Image view
		photoImageView = UIImageView()
		photoImageView.contentMode = .scaleAspectFit // Default to fit, will be updated based on settings
		photoImageView.clipsToBounds = true
		photoImageView.backgroundColor = .secondarySystemFill
		photoImageView.layer.cornerRadius = 8
		photoImageView.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(photoImageView)
		
		// Title label
		titleLabel = UILabel()
		titleLabel.font = .systemFont(ofSize: 11)
		titleLabel.textColor = .label
		titleLabel.textAlignment = .center
		titleLabel.numberOfLines = 2
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(titleLabel)
		
		// Loading indicator
		loadingIndicator = UIActivityIndicatorView(style: .medium)
		loadingIndicator.hidesWhenStopped = true
		loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(loadingIndicator)
		
		// Constraints
		NSLayoutConstraint.activate([
			photoImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
			photoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			photoImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			photoImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -4),
			
			titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
			titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
			titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
			titleLabel.heightAnchor.constraint(equalToConstant: 30),
			
			loadingIndicator.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			loadingIndicator.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor)
		])
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		thumbnailTask?.cancel()
		thumbnailTask = nil
		photoImageView.image = nil
		titleLabel.text = ""
		badgeView?.removeFromSuperview()
		badgeView = nil
		loadingIndicator.stopAnimating()
		contentView.layer.borderWidth = 0
	}
	
	func configure(with photo: any PhotoItem, settings: ThumbnailDisplaySettings) {
		currentPhoto = photo
		titleLabel.text = photo.displayName
		
		// Update display mode
		updateDisplayMode(settings.displayMode)
		
		// Add badge if archived
		if photo.isArchived {
			addArchiveBadge()
		}
		
		// Load thumbnail
		loadThumbnail(for: photo)
		
		// Force initial layout
		setNeedsLayout()
		layoutIfNeeded()
	}
	
	private func loadThumbnail(for photo: any PhotoItem) {
		loadingIndicator.startAnimating()
		
		thumbnailTask?.cancel()
		thumbnailTask = Task { @MainActor in
			do {
				if let thumbnail = try await photo.loadThumbnail() {
					guard !Task.isCancelled else { return }
					self.photoImageView.image = thumbnail
					self.setNeedsLayout()
					self.layoutIfNeeded()
				} else {
					// Show placeholder
					self.photoImageView.image = UIImage(systemName: "photo")
					self.setNeedsLayout()
					self.layoutIfNeeded()
				}
			} catch {
				guard !Task.isCancelled else { return }
				// Show error placeholder
				self.photoImageView.image = UIImage(systemName: "exclamationmark.triangle")
				self.setNeedsLayout()
				self.layoutIfNeeded()
			}
			self.loadingIndicator.stopAnimating()
		}
	}
	
	private func updateDisplayMode(_ mode: ThumbnailDisplayMode) {
		// Update image content mode based on display mode
		switch mode {
		case .scaleToFit:
			photoImageView.contentMode = .scaleAspectFit
		case .scaleToFill:
			photoImageView.contentMode = .scaleAspectFill
		}
	}
	
	private func addArchiveBadge() {
		let badge = UIView()
		badge.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
		badge.layer.cornerRadius = 4
		badge.translatesAutoresizingMaskIntoConstraints = false
		
		let iconView = UIImageView()
		iconView.image = UIImage(systemName: "archivebox")
		iconView.tintColor = .white
		iconView.contentMode = .scaleAspectFit
		iconView.translatesAutoresizingMaskIntoConstraints = false
		
		badge.addSubview(iconView)
		contentView.addSubview(badge)
		
		NSLayoutConstraint.activate([
			badge.topAnchor.constraint(equalTo: photoImageView.topAnchor, constant: 8),
			badge.trailingAnchor.constraint(equalTo: photoImageView.trailingAnchor, constant: -8),
			badge.widthAnchor.constraint(equalToConstant: 24),
			badge.heightAnchor.constraint(equalToConstant: 24),
			
			iconView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
			iconView.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
			iconView.widthAnchor.constraint(equalToConstant: 14),
			iconView.heightAnchor.constraint(equalToConstant: 14)
		])
		
		badgeView = badge
	}
	
	override var isSelected: Bool {
		didSet {
			if isSelected {
				contentView.layer.borderWidth = 3
				contentView.layer.borderColor = UIColor.systemBlue.cgColor
				contentView.layer.cornerRadius = 8
			} else {
				contentView.layer.borderWidth = 0
			}
		}
	}
}
#endif

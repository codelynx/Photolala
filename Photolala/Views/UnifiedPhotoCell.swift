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
	private var placeholderImageView: NSImageView!
	private var titleLabel: NSTextField!
	private var starImageView: NSImageView!
	private var fileSizeLabel: NSTextField!
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
		
		// Title label (hidden but kept for compatibility)
		titleLabel = NSTextField(labelWithString: "")
		titleLabel.isHidden = true
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(titleLabel)
		
		// Star image view
		starImageView = NSImageView()
		starImageView.translatesAutoresizingMaskIntoConstraints = false
		starImageView.imageScaling = .scaleProportionallyDown
		starImageView.contentTintColor = .systemYellow
		view.addSubview(starImageView)
		
		// File size label
		fileSizeLabel = NSTextField(labelWithString: "")
		fileSizeLabel.font = .systemFont(ofSize: 11)
		fileSizeLabel.textColor = .secondaryLabelColor
		fileSizeLabel.alignment = .right
		fileSizeLabel.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(fileSizeLabel)
		
		// Placeholder image view
		placeholderImageView = NSImageView()
		placeholderImageView.translatesAutoresizingMaskIntoConstraints = false
		placeholderImageView.imageScaling = .scaleProportionallyUpOrDown
		if let placeholder = NSImage(systemSymbolName: "photo", accessibilityDescription: nil) {
			placeholderImageView.image = placeholder
			placeholderImageView.contentTintColor = .tertiaryLabelColor
		}
		view.addSubview(placeholderImageView)
		
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
			
			// Title label (hidden)
			titleLabel.topAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: 4),
			titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
			titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
			titleLabel.heightAnchor.constraint(equalToConstant: 20),
			
			// Star image view
			starImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
			starImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
			starImageView.widthAnchor.constraint(equalToConstant: 16),
			starImageView.heightAnchor.constraint(equalToConstant: 16),
			
			// File size label
			fileSizeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
			fileSizeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
			fileSizeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: starImageView.trailingAnchor, constant: 4),
			
			// Loading indicator
			loadingIndicator.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			loadingIndicator.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor),
			
			// Placeholder - centered in photo image view, 50% of size
			placeholderImageView.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			placeholderImageView.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor),
			placeholderImageView.widthAnchor.constraint(equalTo: photoImageView.widthAnchor, multiplier: 0.5),
			placeholderImageView.heightAnchor.constraint(equalTo: photoImageView.heightAnchor, multiplier: 0.5)
		])
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		thumbnailTask?.cancel()
		thumbnailTask = nil
		photoImageView.image = nil
		titleLabel.stringValue = ""
		starImageView.image = nil
		fileSizeLabel.stringValue = ""
		badgeView?.removeFromSuperview()
		badgeView = nil
		loadingIndicator.stopAnimation(nil)
		placeholderImageView.isHidden = false // Show placeholder again
	}
	
	func configure(with photo: any PhotoItem, settings: ThumbnailDisplaySettings) {
		currentPhoto = photo
		titleLabel.stringValue = photo.displayName
		
		// Update image view constraints based on thumbnail option
		imageViewWidthConstraint.constant = settings.thumbnailOption.size
		imageViewHeightConstraint.constant = settings.thumbnailOption.size
		photoImageView.layer?.cornerRadius = settings.thumbnailOption.cornerRadius
		
		// Update info bar visibility based on showItemInfo
		let showInfo = settings.showItemInfo
		starImageView.isHidden = !showInfo
		fileSizeLabel.isHidden = !showInfo
		
		// Configure star based on backup state
		if let photoFile = photo as? PhotoFile,
		   let md5 = photoFile.md5Hash,
		   BackupQueueManager.shared.backupStatus[md5] == .queued {
			starImageView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
		} else {
			starImageView.image = nil
		}
		
		// Configure file size
		if let fileSize = photo.fileSize {
			let formatter = ByteCountFormatter()
			formatter.countStyle = .file
			fileSizeLabel.stringValue = formatter.string(fromByteCount: fileSize)
		} else {
			fileSizeLabel.stringValue = ""
		}
		
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
		// Show loading indicator
		loadingIndicator.startAnimation(nil)
		
		print("[UnifiedPhotoCell] Starting thumbnail load for: \(photo.displayName)")
		
		thumbnailTask?.cancel()
		thumbnailTask = Task { @MainActor in
			do {
				if let thumbnail = try await photo.loadThumbnail() {
					guard !Task.isCancelled else { 
						print("[UnifiedPhotoCell] Task cancelled for: \(photo.displayName)")
						return 
					}
					print("[UnifiedPhotoCell] Thumbnail loaded successfully for: \(photo.displayName)")
					self.photoImageView.image = thumbnail
					self.placeholderImageView.isHidden = true // Hide placeholder when thumbnail loads
					self.photoImageView.needsLayout = true
					self.view.needsDisplay = true
				} else {
					print("[UnifiedPhotoCell] No thumbnail available for: \(photo.displayName)")
					// Keep placeholder visible, it's already configured
					self.placeholderImageView.isHidden = false
				}
			} catch {
				guard !Task.isCancelled else { return }
				print("[UnifiedPhotoCell] Error loading thumbnail for \(photo.displayName): \(error)")
				// Show error icon in placeholder
				if let errorIcon = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil) {
					self.placeholderImageView.image = errorIcon
					self.placeholderImageView.contentTintColor = .tertiaryLabelColor
					self.placeholderImageView.isHidden = false
				}
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
	private var placeholderImageView: UIImageView!
	private var titleLabel: UILabel!
	private var starImageView: UIImageView!
	private var fileSizeLabel: UILabel!
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
		
		// Title label (hidden but kept for compatibility)
		titleLabel = UILabel()
		titleLabel.isHidden = true
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(titleLabel)
		
		// Star image view
		starImageView = UIImageView()
		starImageView.translatesAutoresizingMaskIntoConstraints = false
		starImageView.contentMode = .scaleAspectFit
		starImageView.tintColor = .systemYellow
		contentView.addSubview(starImageView)
		
		// File size label
		fileSizeLabel = UILabel()
		fileSizeLabel.font = .systemFont(ofSize: 11)
		fileSizeLabel.textColor = .secondaryLabel
		fileSizeLabel.textAlignment = .right
		fileSizeLabel.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(fileSizeLabel)
		
		// Placeholder image view
		placeholderImageView = UIImageView()
		placeholderImageView.translatesAutoresizingMaskIntoConstraints = false
		placeholderImageView.contentMode = .scaleAspectFit
		if let placeholder = UIImage(systemName: "photo") {
			let config = UIImage.SymbolConfiguration(hierarchicalColor: .tertiaryLabel)
			placeholderImageView.image = placeholder.applyingSymbolConfiguration(config)
		}
		contentView.addSubview(placeholderImageView)
		
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
			
			// Star image view
			starImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
			starImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
			starImageView.widthAnchor.constraint(equalToConstant: 16),
			starImageView.heightAnchor.constraint(equalToConstant: 16),
			
			// File size label
			fileSizeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
			fileSizeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
			fileSizeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: starImageView.trailingAnchor, constant: 4),
			
			loadingIndicator.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			loadingIndicator.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor),
			
			// Placeholder - centered in photo image view, 50% of size
			placeholderImageView.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			placeholderImageView.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor),
			placeholderImageView.widthAnchor.constraint(equalTo: photoImageView.widthAnchor, multiplier: 0.5),
			placeholderImageView.heightAnchor.constraint(equalTo: photoImageView.heightAnchor, multiplier: 0.5)
		])
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		thumbnailTask?.cancel()
		thumbnailTask = nil
		photoImageView.image = nil
		titleLabel.text = ""
		starImageView.image = nil
		fileSizeLabel.text = ""
		badgeView?.removeFromSuperview()
		badgeView = nil
		loadingIndicator.stopAnimating()
		contentView.layer.borderWidth = 0
		placeholderImageView.isHidden = false // Show placeholder again
	}
	
	func configure(with photo: any PhotoItem, settings: ThumbnailDisplaySettings) {
		currentPhoto = photo
		titleLabel.text = photo.displayName
		
		// Update info bar visibility based on showItemInfo
		let showInfo = settings.showItemInfo
		starImageView.isHidden = !showInfo
		fileSizeLabel.isHidden = !showInfo
		
		// Configure star based on backup state
		if let photoFile = photo as? PhotoFile,
		   let md5 = photoFile.md5Hash,
		   BackupQueueManager.shared.backupStatus[md5] == .queued {
			starImageView.image = UIImage(systemName: "star.fill")
		} else {
			starImageView.image = nil
		}
		
		// Configure file size
		if let fileSize = photo.fileSize {
			let formatter = ByteCountFormatter()
			formatter.countStyle = .file
			fileSizeLabel.text = formatter.string(fromByteCount: fileSize)
		} else {
			fileSizeLabel.text = ""
		}
		
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
		// Show loading indicator
		loadingIndicator.startAnimating()
		
		print("[UnifiedPhotoCell] Starting thumbnail load for: \(photo.displayName)")
		
		thumbnailTask?.cancel()
		thumbnailTask = Task { @MainActor in
			do {
				if let thumbnail = try await photo.loadThumbnail() {
					guard !Task.isCancelled else { 
						print("[UnifiedPhotoCell] Task cancelled for: \(photo.displayName)")
						return 
					}
					print("[UnifiedPhotoCell] Thumbnail loaded successfully for: \(photo.displayName)")
					self.photoImageView.image = thumbnail
					self.placeholderImageView.isHidden = true // Hide placeholder when thumbnail loads
					self.setNeedsLayout()
					self.layoutIfNeeded()
				} else {
					print("[UnifiedPhotoCell] No thumbnail available for: \(photo.displayName)")
					// Keep placeholder visible, it's already configured
					self.placeholderImageView.isHidden = false
				}
			} catch {
				guard !Task.isCancelled else { return }
				print("[UnifiedPhotoCell] Error loading thumbnail for \(photo.displayName): \(error)")
				// Show error icon in placeholder
				if let errorIcon = UIImage(systemName: "exclamationmark.triangle") {
					let config = UIImage.SymbolConfiguration(hierarchicalColor: .tertiaryLabel)
					self.placeholderImageView.image = errorIcon.applyingSymbolConfiguration(config)
					self.placeholderImageView.isHidden = false
				}
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

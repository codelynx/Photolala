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
import XPlatform

#if os(macOS)
/// NSCollectionViewItem for displaying any PhotoItem
class UnifiedPhotoCell: NSCollectionViewItem {
	static let identifier = NSUserInterfaceItemIdentifier("UnifiedPhotoCell")
	
	// UI Elements
	private var photoImageView: ScalableImageView!
	private var placeholderImageView: NSImageView!
	private var starImageView: NSImageView! // Star indicates S3 backup status (yellow=backed up/queued, red=failed)
	private var flagContainerView: NSStackView! // Flags represent user-assigned tags (ColorFlag)
	private var fileSizeLabel: NSTextField!
	private var badgeView: NSView?
	private var tagBadgeView: NSView?
	private var tagLabel: NSTextField?
	private var loadingIndicator: NSProgressIndicator!
	
	// Constraints
	private var imageViewWidthConstraint: NSLayoutConstraint!
	private var imageViewHeightConstraint: NSLayoutConstraint!
	
	// Current photo
	private var currentPhoto: (any PhotoItem)?
	private var thumbnailTask: Task<Void, Never>?
	private var tagObserver: NSObjectProtocol?
	
	override func loadView() {
		self.view = NSView(frame: NSRect(x: 0, y: 0, width: 150, height: 150))
		self.view.wantsLayer = true
		self.view.layer?.masksToBounds = true
		
		// Image view
		photoImageView = ScalableImageView()
		photoImageView.translatesAutoresizingMaskIntoConstraints = false
		photoImageView.scaleMode = .scaleToFit // Default to fit
		photoImageView.wantsLayer = true
		photoImageView.layer?.backgroundColor = XColor.secondarySystemBackground.cgColor
		photoImageView.layer?.cornerRadius = 8
		photoImageView.layer?.masksToBounds = true
		photoImageView.layer?.borderWidth = 1.0
		photoImageView.layer?.borderColor = XColor.black.withAlphaComponent(0.2).cgColor
		
		view.addSubview(photoImageView)
		
		// Star image view
		starImageView = NSImageView()
		starImageView.translatesAutoresizingMaskIntoConstraints = false
		starImageView.imageScaling = .scaleProportionallyDown
		starImageView.contentTintColor = .systemYellow
		view.addSubview(starImageView)
		
		// Flag container view
		flagContainerView = NSStackView()
		flagContainerView.orientation = .horizontal
		flagContainerView.spacing = 2
		flagContainerView.alignment = .centerY
		flagContainerView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(flagContainerView)
		
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
			photoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			imageViewWidthConstraint,
			imageViewHeightConstraint,
			
			// Star image view - positioned at bottom of view (shows S3 backup status)
			starImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
			starImageView.topAnchor.constraint(equalTo: photoImageView.bottomAnchor, constant: 2),
			starImageView.widthAnchor.constraint(equalToConstant: 16),
			starImageView.heightAnchor.constraint(equalToConstant: 16),
			
			// Flag container - positioned after star image (shows user tags)
			flagContainerView.leadingAnchor.constraint(equalTo: starImageView.trailingAnchor, constant: 2),
			flagContainerView.centerYAnchor.constraint(equalTo: starImageView.centerYAnchor),
			flagContainerView.trailingAnchor.constraint(lessThanOrEqualTo: fileSizeLabel.leadingAnchor, constant: -4),
			
			// File size label - positioned at bottom of view
			fileSizeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
			fileSizeLabel.centerYAnchor.constraint(equalTo: starImageView.centerYAnchor),
			
			// Loading indicator
			loadingIndicator.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			loadingIndicator.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor),
			
			// Placeholder - centered in photo image view, 50% of size
			placeholderImageView.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			placeholderImageView.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor),
			placeholderImageView.widthAnchor.constraint(equalTo: photoImageView.widthAnchor, multiplier: 0.5),
			placeholderImageView.heightAnchor.constraint(equalTo: photoImageView.heightAnchor, multiplier: 0.5)
		])
		
		// Set up tag change observer
		tagObserver = NotificationCenter.default.addObserver(
			forName: TagManager.tagsChangedNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			// Reload tag when any tag changes
			if let photo = self?.currentPhoto {
				self?.loadTagForInfoBar(for: photo)
			}
		}
	}
	
	deinit {
		if let observer = tagObserver {
			NotificationCenter.default.removeObserver(observer)
		}
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		thumbnailTask?.cancel()
		thumbnailTask = nil
		photoImageView.image = nil
		starImageView.image = nil
		flagContainerView.arrangedSubviews.forEach { $0.removeFromSuperview() }
		fileSizeLabel.stringValue = ""
		badgeView?.removeFromSuperview()
		badgeView = nil
		tagBadgeView?.removeFromSuperview()
		tagBadgeView = nil
		tagLabel = nil
		loadingIndicator.stopAnimation(nil)
		placeholderImageView.isHidden = false // Show placeholder again
	}
	
	func configure(with photo: any PhotoItem, settings: ThumbnailDisplaySettings) {
		currentPhoto = photo
		
		// Update scale mode based on settings
		photoImageView.scaleMode = settings.displayMode == .scaleToFit ? .scaleToFit : .scaleToFill
		
		// Update image view constraints based on thumbnail option
		let imageSize = settings.thumbnailOption.size
		imageViewWidthConstraint.constant = imageSize
		// If showing info bar, image height is thumbnail size, otherwise fill the cell
		imageViewHeightConstraint.constant = settings.showItemInfo ? imageSize : imageSize
		photoImageView.layer?.cornerRadius = settings.thumbnailOption.cornerRadius
		
		// Update info bar visibility based on showItemInfo
		let showInfo = settings.showItemInfo
		starImageView.isHidden = !showInfo
		flagContainerView.isHidden = !showInfo
		fileSizeLabel.isHidden = !showInfo
		
		// Configure star based on backup state
		// Star = S3 backup status indicator (not a tag/bookmark)
		// Yellow star = queued for backup or already uploaded
		// Red exclamation = backup failed
		// Blue cloud = S3 photos (already in cloud)
		if let photoFile = photo as? PhotoFile {
			// Only show backup status for local PhotoFile items
			if let md5 = photoFile.md5Hash {
				let status = BackupQueueManager.shared.backupStatus[md5]
				switch status {
				case .queued, .uploaded:
					starImageView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
					starImageView.contentTintColor = .systemYellow
				case .failed:
					starImageView.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
					starImageView.contentTintColor = .systemRed
				default:
					starImageView.image = nil
					starImageView.contentTintColor = .systemYellow
				}
			} else {
				// MD5 not computed yet - check if we can find a match later
				starImageView.image = nil
				// Compute MD5 asynchronously
				Task {
					if let status = await BackupQueueManager.shared.getBackupStatus(for: photoFile) {
						await MainActor.run {
							switch status {
							case .queued, .uploaded:
								starImageView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
								starImageView.contentTintColor = .systemYellow
							case .failed:
								starImageView.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
								starImageView.contentTintColor = .systemRed
							default:
								starImageView.image = nil
							}
						}
					}
				}
			}
		} else if let photoApple = photo as? PhotoApple {
			// Check if Apple Photo has been backed up
			starImageView.image = nil
			Task {
				// Query SwiftData catalog for this Apple Photo
				let catalogService = PhotolalaCatalogServiceV2.shared
				if let entry = try? await catalogService.findByApplePhotoID(photoApple.id) {
					await MainActor.run {
						if entry.isStarred || entry.backupStatus == .uploaded {
							starImageView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
							starImageView.contentTintColor = .systemYellow
						} else if entry.backupStatus == .error {
							starImageView.image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
							starImageView.contentTintColor = .systemRed
						} else {
							starImageView.image = nil
						}
					}
				}
			}
		} else if let photoS3 = photo as? PhotoS3 {
			// For S3 photos, show a cloud icon to indicate they're already backed up
			starImageView.image = NSImage(systemSymbolName: "icloud.fill", accessibilityDescription: nil)
			starImageView.contentTintColor = .systemBlue
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
		
		// Load tag for info bar
		loadTagForInfoBar(for: photo)
		
		// Load thumbnail
		loadThumbnail(for: photo)
		
		// Force initial layout
		view.needsLayout = true
		view.needsDisplay = true
	}
	
	private func loadThumbnail(for photo: any PhotoItem) {
		// Skip if we already have this photo's thumbnail loaded
		if let current = currentPhoto,
		   current.id == photo.id,
		   photoImageView.image != nil {
			// Already have the thumbnail for this photo
			return
		}
		
		// Show loading indicator
		loadingIndicator.startAnimation(nil)
		
		
		thumbnailTask?.cancel()
		thumbnailTask = Task { @MainActor in
			do {
				if let thumbnail = try await photo.loadThumbnail() {
					guard !Task.isCancelled else { 
						return 
					}
					self.photoImageView.image = thumbnail
					self.placeholderImageView.isHidden = true // Hide placeholder when thumbnail loads
					self.photoImageView.needsLayout = true
					self.photoImageView.needsDisplay = true
					self.view.layoutSubtreeIfNeeded() // Force immediate layout to ensure proper clipping
				} else {
					// Keep placeholder visible, it's already configured
					self.placeholderImageView.isHidden = false
				}
			} catch {
				guard !Task.isCancelled else { return }
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
		// Force redraw
		photoImageView.needsDisplay = true
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
	
	private func loadTagForInfoBar(for photo: any PhotoItem) {
		// Load and display user-assigned tags (ColorFlags)
		// These are displayed as colored flag icons next to the star
		Task {
			let tag = await TagManager.shared.getTag(for: photo)
			await MainActor.run {
				// Clear existing flags
				flagContainerView.arrangedSubviews.forEach { $0.removeFromSuperview() }
				
				if let flags = tag?.sortedFlags, !flags.isEmpty {
					// Add flag views
					for flag in flags {
						let flagImageView = NSImageView()
						flagImageView.image = NSImage(systemSymbolName: "flag.fill", accessibilityDescription: nil)
						flagImageView.contentTintColor = NSColor(flag.color)
						flagImageView.imageScaling = .scaleProportionallyDown
						flagImageView.translatesAutoresizingMaskIntoConstraints = false
						
						// Set size constraints
						NSLayoutConstraint.activate([
							flagImageView.widthAnchor.constraint(equalToConstant: 12),
							flagImageView.heightAnchor.constraint(equalToConstant: 12)
						])
						
						flagContainerView.addArrangedSubview(flagImageView)
					}
				}
			}
		}
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
	
	// Public method to update only the display mode without reloading
	func updateDisplayModeOnly(_ mode: ThumbnailDisplayMode) {
		updateDisplayMode(mode)
	}
}

#else

/// UICollectionViewCell for displaying any PhotoItem
class UnifiedPhotoCell: UICollectionViewCell {
	static let identifier = "UnifiedPhotoCell"
	
	// UI Elements
	private var photoImageView: UIImageView!
	private var placeholderImageView: UIImageView!
	private var starImageView: UIImageView! // Star indicates S3 backup status (yellow=backed up/queued, red=failed)
	private var flagContainerView: UIStackView! // Flags represent user-assigned tags (ColorFlag)
	private var fileSizeLabel: UILabel!
	private var badgeView: UIView?
	private var loadingIndicator: UIActivityIndicatorView!
	
	// Constraints
	private var photoImageViewBottomConstraint: NSLayoutConstraint!
	
	// Current photo
	private var currentPhoto: (any PhotoItem)?
	private var thumbnailTask: Task<Void, Never>?
	private var tagObserver: NSObjectProtocol?
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
		setupTagObserver()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupViews()
		setupTagObserver()
	}
	
	deinit {
		if let observer = tagObserver {
			NotificationCenter.default.removeObserver(observer)
		}
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
		
		// Star image view
		starImageView = UIImageView()
		starImageView.translatesAutoresizingMaskIntoConstraints = false
		starImageView.contentMode = .scaleAspectFit
		starImageView.tintColor = .systemYellow
		contentView.addSubview(starImageView)
		
		// Flag container view
		flagContainerView = UIStackView()
		flagContainerView.axis = .horizontal
		flagContainerView.spacing = 2
		flagContainerView.alignment = .center
		flagContainerView.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(flagContainerView)
		
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
		
		// Create bottom constraint separately so we can update it
		photoImageViewBottomConstraint = photoImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
		
		// Constraints
		NSLayoutConstraint.activate([
			photoImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
			photoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			photoImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			photoImageViewBottomConstraint,
			
			// Star image view - positioned at bottom of contentView (shows S3 backup status)
			starImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
			starImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
			starImageView.widthAnchor.constraint(equalToConstant: 16),
			starImageView.heightAnchor.constraint(equalToConstant: 16),
			
			// Flag container - positioned after star image (shows user tags)
			flagContainerView.leadingAnchor.constraint(equalTo: starImageView.trailingAnchor, constant: 2),
			flagContainerView.centerYAnchor.constraint(equalTo: starImageView.centerYAnchor),
			flagContainerView.trailingAnchor.constraint(lessThanOrEqualTo: fileSizeLabel.leadingAnchor, constant: -4),
			
			// File size label - positioned at bottom of contentView
			fileSizeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
			fileSizeLabel.centerYAnchor.constraint(equalTo: starImageView.centerYAnchor),
			
			loadingIndicator.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			loadingIndicator.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor),
			
			// Placeholder - centered in photo image view, 50% of size
			placeholderImageView.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
			placeholderImageView.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor),
			placeholderImageView.widthAnchor.constraint(equalTo: photoImageView.widthAnchor, multiplier: 0.5),
			placeholderImageView.heightAnchor.constraint(equalTo: photoImageView.heightAnchor, multiplier: 0.5)
		])
	}
	
	private func setupTagObserver() {
		// Set up tag change observer
		tagObserver = NotificationCenter.default.addObserver(
			forName: TagManager.tagsChangedNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			// Reload tag when any tag changes
			if let photo = self?.currentPhoto {
				self?.loadTagForInfoBar(for: photo)
			}
		}
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		thumbnailTask?.cancel()
		thumbnailTask = nil
		photoImageView.image = nil
		starImageView.image = nil
		flagContainerView.arrangedSubviews.forEach { $0.removeFromSuperview() }
		fileSizeLabel.text = ""
		badgeView?.removeFromSuperview()
		badgeView = nil
		loadingIndicator.stopAnimating()
		contentView.layer.borderWidth = 0
		placeholderImageView.isHidden = false // Show placeholder again
	}
	
	func configure(with photo: any PhotoItem, settings: ThumbnailDisplaySettings) {
		currentPhoto = photo
		
		// Update content mode based on display mode setting
		photoImageView.contentMode = settings.displayMode == .scaleToFit ? .scaleAspectFit : .scaleAspectFill
		
		// Update info bar visibility based on showItemInfo
		let showInfo = settings.showItemInfo
		starImageView.isHidden = !showInfo
		flagContainerView.isHidden = !showInfo
		fileSizeLabel.isHidden = !showInfo
		
		// Adjust photo image view bottom constraint
		photoImageViewBottomConstraint.constant = showInfo ? -24 : 0
		
		// Configure star based on backup state
		// Star = S3 backup status indicator (not a tag/bookmark)
		// Yellow star = queued for backup or already uploaded
		// Red exclamation = backup failed
		// Blue cloud = S3 photos (already in cloud)
		if let photoFile = photo as? PhotoFile {
			// Only show backup status for local PhotoFile items
			if let md5 = photoFile.md5Hash {
				let status = BackupQueueManager.shared.backupStatus[md5]
				switch status {
				case .queued, .uploaded:
					starImageView.image = UIImage(systemName: "star.fill")
					starImageView.tintColor = .systemYellow
				case .failed:
					starImageView.image = UIImage(systemName: "exclamationmark.circle.fill")
					starImageView.tintColor = .systemRed
				default:
					starImageView.image = nil
				}
			} else {
				// MD5 not computed yet - check if we can find a match later
				starImageView.image = nil
				// Compute MD5 asynchronously
				Task {
					if let status = await BackupQueueManager.shared.getBackupStatus(for: photoFile) {
						await MainActor.run {
							switch status {
							case .queued, .uploaded:
								starImageView.image = UIImage(systemName: "star.fill")
								starImageView.tintColor = .systemYellow
							case .failed:
								starImageView.image = UIImage(systemName: "exclamationmark.circle.fill")
								starImageView.tintColor = .systemRed
							default:
								starImageView.image = nil
							}
						}
					}
				}
			}
		} else if let photoApple = photo as? PhotoApple {
			// Check if Apple Photo has been backed up
			starImageView.image = nil
			Task {
					// Query SwiftData catalog for this Apple Photo
					let catalogService = PhotolalaCatalogServiceV2.shared
					if let entry = try? await catalogService.findByApplePhotoID(photoApple.id) {
						await MainActor.run {
							if entry.isStarred || entry.backupStatus == .uploaded {
								starImageView.image = UIImage(systemName: "star.fill")
								starImageView.tintColor = .systemYellow
							} else if entry.backupStatus == .error {
								starImageView.image = UIImage(systemName: "exclamationmark.circle.fill")
								starImageView.tintColor = .systemRed
							} else {
								starImageView.image = nil
							}
						}
					}
				}
		} else if let photoS3 = photo as? PhotoS3 {
			// For S3 photos, show a cloud icon to indicate they're already backed up
			starImageView.image = UIImage(systemName: "icloud.fill")
			starImageView.tintColor = .systemBlue
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
		
		// Load tag for info bar
		loadTagForInfoBar(for: photo)
		
		// Load thumbnail
		loadThumbnail(for: photo)
		
		// Force initial layout
		setNeedsLayout()
		layoutIfNeeded()
	}
	
	private func loadThumbnail(for photo: any PhotoItem) {
		// Show loading indicator
		loadingIndicator.startAnimating()
		
		
		thumbnailTask?.cancel()
		thumbnailTask = Task { @MainActor in
			do {
				if let thumbnail = try await photo.loadThumbnail() {
					guard !Task.isCancelled else { 
						return 
					}
					self.photoImageView.image = thumbnail
					self.placeholderImageView.isHidden = true // Hide placeholder when thumbnail loads
					self.setNeedsLayout()
					self.layoutIfNeeded()
				} else {
					// Keep placeholder visible, it's already configured
					self.placeholderImageView.isHidden = false
				}
			} catch {
				guard !Task.isCancelled else { return }
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
	
	private func loadTagForInfoBar(for photo: any PhotoItem) {
		// Load and display user-assigned tags (ColorFlags)
		// These are displayed as colored flag icons next to the star
		Task {
			let tag = await TagManager.shared.getTag(for: photo)
			await MainActor.run {
				// Clear existing flags
				flagContainerView.arrangedSubviews.forEach { $0.removeFromSuperview() }
				
				if let flags = tag?.sortedFlags, !flags.isEmpty {
					// Add flag views
					for flag in flags {
						let flagImageView = UIImageView()
						flagImageView.image = UIImage(systemName: "flag.fill")
						flagImageView.tintColor = flag.uiColor
						flagImageView.contentMode = .scaleAspectFit
						flagImageView.translatesAutoresizingMaskIntoConstraints = false
						
						// Set size constraints
						NSLayoutConstraint.activate([
							flagImageView.widthAnchor.constraint(equalToConstant: 12),
							flagImageView.heightAnchor.constraint(equalToConstant: 12)
						])
						
						flagContainerView.addArrangedSubview(flagImageView)
					}
				}
			}
		}
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

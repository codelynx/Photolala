//
//  PhotoCellView.swift
//  Photolala
//
//  Shared photo cell view containing all UI components and logic
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class PhotoCellView: XView {
	// MARK: - Properties
	private var imageContainer: XView!
	private var imageView: ScalableImageView!
	private var loadingView: XActivityIndicator!
	private var infoBar: XView!
	private var infoStackView: XHStackView!
	private var starIconView: XImageView!  // Star icon in info bar
	private var photoDateLabel: XTextField!  // Photo date label
	private var fileSizeLabel: XTextField!  // File size label
	private var currentLoadTask: Task<Void, Never>?
	private var displayMode: ThumbnailDisplayMode = .fill
	private var showInfoBar: Bool = false
	private var currentItem: PhotoBrowserItem?
	private var currentSource: (any PhotoSourceProtocol)?
	private var currentSourceURL: URL? // For local sources - kept for basket context
	private var currentSourceIdentifier: String? // Source-specific ID - kept for basket context
	private var isSelected = false
	private var isStarred = false

	// MARK: - Initialization
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
		setupConstraints()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupViews()
		setupConstraints()
	}

	// MARK: - Setup
	private func setupViews() {
		// Configure container
		#if os(macOS)
		wantsLayer = true
		layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
		layer?.cornerRadius = 4
		#else
		backgroundColor = .secondarySystemBackground
		layer.cornerRadius = 4
		clipsToBounds = true
		#endif

		// Create image container (square)
		imageContainer = XView()
		imageContainer.translatesAutoresizingMaskIntoConstraints = false
		#if os(macOS)
		imageContainer.wantsLayer = true
		#endif
		addSubview(imageContainer)

		// Create scalable image view inside container
		#if os(macOS)
		imageView = ScalableImageView()
		#else
		imageView = ScalableImageView(frame: .zero)
		#endif
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.displayMode = displayMode
		#if os(macOS)
		imageView.wantsLayer = true
		imageView.layer?.cornerRadius = 4
		imageView.layer?.masksToBounds = true
		#else
		imageView.layer.cornerRadius = 4
		imageView.clipsToBounds = true
		#endif
		imageContainer.addSubview(imageView)

		// Create loading indicator
		#if os(macOS)
		loadingView = NSProgressIndicator()
		loadingView.style = .spinning
		loadingView.isDisplayedWhenStopped = false
		#else
		loadingView = UIActivityIndicatorView(style: .medium)
		loadingView.hidesWhenStopped = true
		#endif
		loadingView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(loadingView)

		// Create info bar
		infoBar = XView()
		infoBar.translatesAutoresizingMaskIntoConstraints = false
		#if os(macOS)
		infoBar.wantsLayer = true
		infoBar.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9).cgColor
		#else
		infoBar.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
		#endif
		infoBar.isHidden = !showInfoBar
		addSubview(infoBar)

		// Create horizontal stack view for info bar content
		infoStackView = XHStackView(spacing: 6)
		infoStackView.translatesAutoresizingMaskIntoConstraints = false
		infoBar.addSubview(infoStackView)

		// Create star icon for info bar
		#if os(macOS)
		starIconView = NSImageView()
		starIconView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Starred")
		starIconView.contentTintColor = .systemYellow
		starIconView.imageScaling = .scaleProportionallyDown
		#else
		starIconView = UIImageView()
		starIconView.image = UIImage(systemName: "star.fill")
		starIconView.tintColor = .systemYellow
		starIconView.contentMode = .scaleAspectFit
		#endif
		starIconView.translatesAutoresizingMaskIntoConstraints = false
		infoStackView.addArrangedSubview(starIconView)

		// Create photo date label
		#if os(macOS)
		photoDateLabel = NSTextField()
		photoDateLabel.isEditable = false
		photoDateLabel.isBordered = false
		photoDateLabel.drawsBackground = false
		photoDateLabel.font = NSFont.systemFont(ofSize: 10)
		photoDateLabel.textColor = NSColor.secondaryLabelColor
		photoDateLabel.lineBreakMode = .byTruncatingTail
		photoDateLabel.stringValue = "--"
		#else
		photoDateLabel = UILabel()
		photoDateLabel.font = UIFont.systemFont(ofSize: 10)
		photoDateLabel.textColor = UIColor.secondaryLabel
		photoDateLabel.lineBreakMode = .byTruncatingTail
		photoDateLabel.text = "--"
		#endif
		photoDateLabel.translatesAutoresizingMaskIntoConstraints = false
		infoStackView.addArrangedSubview(photoDateLabel)

		// Add spacer view for elastic spacing
		let spacer = XView()
		spacer.translatesAutoresizingMaskIntoConstraints = false
		#if os(macOS)
		spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
		#else
		spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
		#endif
		infoStackView.addArrangedSubview(spacer)

		// Create file size label
		#if os(macOS)
		fileSizeLabel = NSTextField()
		fileSizeLabel.isEditable = false
		fileSizeLabel.isBordered = false
		fileSizeLabel.drawsBackground = false
		fileSizeLabel.font = NSFont.systemFont(ofSize: 10)
		fileSizeLabel.textColor = NSColor.tertiaryLabelColor
		fileSizeLabel.lineBreakMode = .byTruncatingTail
		fileSizeLabel.stringValue = "--"
		#else
		fileSizeLabel = UILabel()
		fileSizeLabel.font = UIFont.systemFont(ofSize: 10)
		fileSizeLabel.textColor = UIColor.tertiaryLabel
		fileSizeLabel.lineBreakMode = .byTruncatingTail
		fileSizeLabel.text = "--"
		#endif
		fileSizeLabel.translatesAutoresizingMaskIntoConstraints = false
		infoStackView.addArrangedSubview(fileSizeLabel)
	}

	// Constraint references for dynamic updates
	private var infoBarHeightConstraint: NSLayoutConstraint!
	private var infoBarTopConstraint: NSLayoutConstraint!

	private func setupConstraints() {
		// Explicit constraints for both platforms (especially important for AppKit)
		var constraints: [NSLayoutConstraint] = []

		// Image container - square aspect ratio, fills width
		constraints.append(contentsOf: [
			imageContainer.topAnchor.constraint(equalTo: topAnchor),
			imageContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
			imageContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
			// Make it square
			imageContainer.heightAnchor.constraint(equalTo: imageContainer.widthAnchor)
		])

		// Image view fills the container
		constraints.append(contentsOf: [
			imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
			imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor)
		])

		// Loading indicator centered in image container
		constraints.append(contentsOf: [
			loadingView.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
			loadingView.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor)
		])

		// Star icon constraints in info bar
		constraints.append(contentsOf: [
			starIconView.widthAnchor.constraint(equalToConstant: 12),
			starIconView.heightAnchor.constraint(equalToConstant: 12)
		])

		// Info bar - positioned below image container
		infoBarTopConstraint = infoBar.topAnchor.constraint(equalTo: imageContainer.bottomAnchor)
		infoBarHeightConstraint = infoBar.heightAnchor.constraint(equalToConstant: 0)
		constraints.append(contentsOf: [
			infoBarTopConstraint,
			infoBar.leadingAnchor.constraint(equalTo: leadingAnchor),
			infoBar.trailingAnchor.constraint(equalTo: trailingAnchor),
			infoBarHeightConstraint
		])

		// Stack view inside info bar
		constraints.append(contentsOf: [
			infoStackView.leadingAnchor.constraint(equalTo: infoBar.leadingAnchor, constant: 4),
			infoStackView.trailingAnchor.constraint(equalTo: infoBar.trailingAnchor, constant: -4),
			infoStackView.centerYAnchor.constraint(equalTo: infoBar.centerYAnchor)
		])

		NSLayoutConstraint.activate(constraints)
	}

	// MARK: - Public API
	func configure(with item: PhotoBrowserItem, source: any PhotoSourceProtocol, displayMode: ThumbnailDisplayMode = .fill, showInfoBar: Bool = false) {
		// Store current item and source context (for future basket operations)
		currentItem = item
		currentSource = source
		// Note: sourceURL and sourceIdentifier will be resolved when needed for basket operations

		// Always show info bar if we want metadata display
		if showInfoBar {
			infoBar.isHidden = false
			infoBarHeightConstraint.constant = 20

			// Check starred status
			Task { @MainActor in
				var starred = false

				// Get photo identity from source
				let identity = await source.getPhotoIdentity(for: item.id)

				print("[PhotoCellView] Checking star status for \(item.displayName):")
				print("  - Full MD5: \(identity.fullMD5 ?? "nil")")
				print("  - Head MD5: \(identity.headMD5 ?? "nil")")
				print("  - File size: \(identity.fileSize ?? 0)")

				// Check starred status using available identifiers
				if let fullMD5 = identity.fullMD5 {
					// Have full MD5 - most accurate check
					starred = await BasketActionService.shared.isStarred(md5: fullMD5)
					print("  - Checked by full MD5: \(starred)")
				} else if let headMD5 = identity.headMD5, let fileSize = identity.fileSize {
					// Have Fast Photo Key - check by that
					starred = await BasketActionService.shared.isStarredByFastKey(
						headMD5: headMD5,
						fileSize: fileSize
					)
					print("  - Checked by Fast Key: \(starred)")
				} else if item.id.count == 32 && item.id.allSatisfy({ $0.isHexDigit }) {
					// Fallback: ID might be an MD5 itself
					starred = await BasketActionService.shared.isStarred(md5: item.id)
				}

				self.isStarred = starred
				// Show/hide star icon based on starred state
				self.starIconView.isHidden = !starred
				// Load metadata for all photos
				self.updatePhotoMetadata(item: item, source: source)
			}
		} else {
			// Info bar disabled
			infoBar.isHidden = true
			infoBarHeightConstraint.constant = 0
			isStarred = false
		}

		// Update display mode if changed
		if self.displayMode != displayMode {
			self.displayMode = displayMode
			imageView.displayMode = displayMode
			updateBorder()
		}

		// Store showInfoBar setting
		self.showInfoBar = showInfoBar

		// Cancel previous load
		currentLoadTask?.cancel()

		// Reset state
		imageView.image = nil
		startLoading()

		// Load thumbnail with async task
		currentLoadTask = Task {
			do {
				// Load thumbnail in background
				let thumbnail = try await source.loadThumbnail(for: item.id)

				// Check if task was cancelled
				if Task.isCancelled { return }

				// Update UI on main actor
				await MainActor.run {
					self.stopLoading()
					if let thumbnail = thumbnail {
						self.imageView.image = thumbnail
						self.updateBorder()  // Update border after image loads
					} else {
						// Show placeholder for missing thumbnail
						self.showPlaceholder()
					}
				}
			} catch {
				// Check if task was cancelled
				if Task.isCancelled { return }

				await MainActor.run {
					self.stopLoading()
					self.showError()
				}
			}
		}
	}

	func reset() {
		currentLoadTask?.cancel()
		currentLoadTask = nil
		currentItem = nil
		stopLoading() // Stop any ongoing animation
		imageView.image = nil
		isSelected = false
		updateSelectionBorder()
		infoBar.isHidden = true
		infoBarHeightConstraint.constant = 0
		starIconView.isHidden = true
		#if os(macOS)
		photoDateLabel.stringValue = "--"
		fileSizeLabel.stringValue = "--"
		#else
		photoDateLabel.text = "--"
		fileSizeLabel.text = "--"
		#endif
		// Reset background color to default
		#if os(macOS)
		layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
		#else
		backgroundColor = .secondarySystemBackground
		#endif
	}

	func setSelected(_ selected: Bool) {
		isSelected = selected
		updateSelectionBorder()
	}

	func updateStarredState() {
		// Update star indicator if item is loaded
		if let item = currentItem, let source = currentSource, showInfoBar {
			// Check if ID looks like MD5
			if item.id.count == 32 && item.id.allSatisfy({ $0.isHexDigit }) {
				// ID looks like an MD5 hash - check if it's starred
				Task { @MainActor in
					let starred = await BasketActionService.shared.isStarred(md5: item.id)
					self.isStarred = starred
					// Update star icon visibility
					self.starIconView.isHidden = !starred
					// Update metadata
					self.updatePhotoMetadata(item: item, source: source)
				}
			} else {
				isStarred = false
				starIconView.isHidden = true
				updatePhotoMetadata(item: item, source: source)
			}
		}
	}

	private func updatePhotoMetadata(item: PhotoBrowserItem, source: any PhotoSourceProtocol) {
		// TODO: Fetch actual metadata from source
		// For now, show what we can deduce:
		// - Local photos: likely have file size
		// - Apple Photos: might have cached size
		// - All should have dates

		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .short
		dateFormatter.timeStyle = .none

		// For now, use placeholder data
		// TODO: Get actual metadata from photo source
		let hasDate = true  // Most photos have dates
		let hasSize = true  // Local always has, Apple Photos might have if cached

		#if os(macOS)
		photoDateLabel.stringValue = hasDate ? dateFormatter.string(from: Date()) : ""
		photoDateLabel.isHidden = !hasDate
		fileSizeLabel.stringValue = hasSize ? "2.5 MB" : ""
		fileSizeLabel.isHidden = !hasSize
		#else
		photoDateLabel.text = hasDate ? dateFormatter.string(from: Date()) : ""
		photoDateLabel.isHidden = !hasDate
		fileSizeLabel.text = hasSize ? "2.5 MB" : ""
		fileSizeLabel.isHidden = !hasSize
		#endif

		// Hide info bar if no metadata to show
		let hasAnyMetadata = !starIconView.isHidden || hasDate || hasSize
		infoBar.isHidden = !hasAnyMetadata
		infoBarHeightConstraint.constant = hasAnyMetadata ? 20 : 0

		#if os(macOS)
		needsLayout = true
		#else
		setNeedsLayout()
		#endif
	}

	private func updateSelectionBorder() {
		if isSelected {
			// Add selection border to image view
			#if os(macOS)
			imageView.layer?.borderWidth = 3
			imageView.layer?.borderColor = NSColor.controlAccentColor.cgColor
			imageView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
			#else
			imageView.layer.borderWidth = 3
			imageView.layer.borderColor = UIColor.tintColor.cgColor
			imageView.backgroundColor = UIColor.tintColor.withAlphaComponent(0.2)
			#endif
		} else {
			// Remove selection border
			#if os(macOS)
			// Keep the border from updateBorder() for fit mode
			if displayMode == .fit {
				imageView.layer?.borderWidth = 1
				imageView.layer?.borderColor = NSColor.separatorColor.cgColor
			} else {
				imageView.layer?.borderWidth = 0
				imageView.layer?.borderColor = nil
			}
			imageView.layer?.backgroundColor = nil
			#else
			if displayMode == .fit {
				imageView.layer.borderWidth = 1
				imageView.layer.borderColor = UIColor.separator.cgColor
			} else {
				imageView.layer.borderWidth = 0
				imageView.layer.borderColor = nil
			}
			imageView.backgroundColor = nil
			#endif
		}
	}

	// MARK: - Private Helpers
	private func startLoading() {
		#if os(macOS)
		loadingView.startAnimation(nil)
		#else
		loadingView.startAnimating()
		#endif
	}

	private func stopLoading() {
		#if os(macOS)
		loadingView.stopAnimation(nil)
		#else
		loadingView.stopAnimating()
		#endif
	}

	private func showPlaceholder() {
		// Show a placeholder image or color
		#if os(macOS)
		layer?.backgroundColor = NSColor.controlColor.cgColor
		#else
		backgroundColor = .tertiarySystemBackground
		#endif
	}

	private func showError() {
		// Show error state
		#if os(macOS)
		layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
		#else
		backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
		#endif
	}

	private func updateInfoBarVisibility() {
		// Info bar visibility is now controlled by starred state
		// This method is kept for compatibility but doesn't do anything
	}

	private func updateInfoLabel(item: PhotoBrowserItem) {
		// Not used anymore - we only show star indicator
	}

	private func updateBorder() {
		// Don't update border if selected (selection border takes precedence)
		if isSelected {
			return
		}

		// Show border only in fit mode (not fill)
		let showBorder = displayMode == .fit
		#if os(macOS)
		if showBorder {
			imageView.layer?.borderWidth = 1
			imageView.layer?.borderColor = NSColor.separatorColor.cgColor
		} else {
			imageView.layer?.borderWidth = 0
			imageView.layer?.borderColor = nil
		}
		#else
		if showBorder {
			imageView.layer.borderWidth = 1
			imageView.layer.borderColor = UIColor.separator.cgColor
		} else {
			imageView.layer.borderWidth = 0
			imageView.layer.borderColor = nil
		}
		#endif
	}
}
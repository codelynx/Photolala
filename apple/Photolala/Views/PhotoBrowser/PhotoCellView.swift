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
	private var infoLabel: XTextField!
	private var starIndicator: XImageView!
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

		// Create info label
		#if os(macOS)
		infoLabel = NSTextField()
		infoLabel.isEditable = false
		infoLabel.isBordered = false
		infoLabel.drawsBackground = false
		infoLabel.font = NSFont.systemFont(ofSize: 10)
		infoLabel.textColor = NSColor.secondaryLabelColor
		infoLabel.lineBreakMode = .byTruncatingTail
		#else
		infoLabel = UILabel()
		infoLabel.font = UIFont.systemFont(ofSize: 10)
		infoLabel.textColor = UIColor.secondaryLabel
		infoLabel.lineBreakMode = .byTruncatingTail
		#endif
		infoLabel.translatesAutoresizingMaskIntoConstraints = false
		infoBar.addSubview(infoLabel)

		// Create star indicator
		#if os(macOS)
		starIndicator = NSImageView()
		starIndicator.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Starred")
		starIndicator.contentTintColor = .systemYellow
		starIndicator.imageScaling = .scaleProportionallyDown
		#else
		starIndicator = UIImageView()
		starIndicator.image = UIImage(systemName: "star.fill")
		starIndicator.tintColor = .systemYellow
		starIndicator.contentMode = .scaleAspectFit
		#endif
		starIndicator.translatesAutoresizingMaskIntoConstraints = false
		starIndicator.isHidden = true
		addSubview(starIndicator)
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

		// Star indicator in top-right corner
		constraints.append(contentsOf: [
			starIndicator.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: 8),
			starIndicator.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -8),
			starIndicator.widthAnchor.constraint(equalToConstant: 20),
			starIndicator.heightAnchor.constraint(equalToConstant: 20)
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

		// Info label inside info bar
		constraints.append(contentsOf: [
			infoLabel.leadingAnchor.constraint(equalTo: infoBar.leadingAnchor, constant: 4),
			infoLabel.trailingAnchor.constraint(equalTo: infoBar.trailingAnchor, constant: -4),
			infoLabel.centerYAnchor.constraint(equalTo: infoBar.centerYAnchor)
		])

		NSLayoutConstraint.activate(constraints)
	}

	// MARK: - Public API
	func configure(with item: PhotoBrowserItem, source: any PhotoSourceProtocol, displayMode: ThumbnailDisplayMode = .fill, showInfoBar: Bool = false) {
		// Store current item and source context (for future basket operations)
		currentItem = item
		currentSource = source
		// Note: sourceURL and sourceIdentifier will be resolved when needed for basket operations

		// Check if item is starred (if ID looks like MD5)
		// TODO: Properly compute MD5 from source when needed
		if item.id.count == 32 && item.id.allSatisfy({ $0.isHexDigit }) {
			// ID looks like an MD5 hash
			// For now, star indicator is hidden by default until we implement proper checking
			isStarred = false
			starIndicator.isHidden = true
		} else {
			isStarred = false
			starIndicator.isHidden = true
		}

		// Update display mode if changed
		if self.displayMode != displayMode {
			self.displayMode = displayMode
			imageView.displayMode = displayMode
			updateBorder()
		}

		// Update info bar visibility
		if self.showInfoBar != showInfoBar {
			self.showInfoBar = showInfoBar
			updateInfoBarVisibility()
		}

		// Update info label
		if showInfoBar {
			updateInfoLabel(item: item)
		}

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
		#if os(macOS)
		infoLabel.stringValue = ""
		#else
		infoLabel.text = ""
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
		if let item = currentItem {
			// Check if ID looks like MD5
			if item.id.count == 32 && item.id.allSatisfy({ $0.isHexDigit }) {
				// TODO: Check starred state through BasketActionService
				// For now, keep star hidden
				isStarred = false
				starIndicator.isHidden = true
			} else {
				isStarred = false
				starIndicator.isHidden = true
			}
		}
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
		infoBar.isHidden = !showInfoBar
		// Update height constraint based on visibility
		let targetHeight: CGFloat = showInfoBar ? 20 : 0
		if infoBarHeightConstraint.constant != targetHeight {
			infoBarHeightConstraint.constant = targetHeight
			#if os(macOS)
			needsLayout = true
			#else
			setNeedsLayout()
			#endif
		}
	}

	private func updateInfoLabel(item: PhotoBrowserItem) {
		// For now, just show the display name
		// TODO: Load metadata through photo source for date and size
		let infoText = item.displayName
		#if os(macOS)
		infoLabel.stringValue = infoText
		#else
		infoLabel.text = infoText
		#endif
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
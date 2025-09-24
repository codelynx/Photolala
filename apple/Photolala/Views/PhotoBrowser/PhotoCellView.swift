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
	private var selectionOverlay: XView!
	private var infoBar: XView!
	private var infoLabel: XTextField!
	private var currentLoadTask: Task<Void, Never>?
	private var displayMode: ThumbnailDisplayMode = .fill
	private var showInfoBar: Bool = false
	private var currentItem: PhotoBrowserItem?
	private var currentSource: (any PhotoSourceProtocol)?
	private var currentSourceURL: URL? // For local sources - kept for basket context
	private var currentSourceIdentifier: String? // Source-specific ID - kept for basket context

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

		// Create selection overlay
		selectionOverlay = XView()
		selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
		#if os(macOS)
		selectionOverlay.wantsLayer = true
		selectionOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
		selectionOverlay.layer?.cornerRadius = 4
		selectionOverlay.layer?.borderWidth = 3
		selectionOverlay.layer?.borderColor = NSColor.controlAccentColor.cgColor
		#else
		selectionOverlay.backgroundColor = UIColor.tintColor.withAlphaComponent(0.3)
		selectionOverlay.layer.borderWidth = 3
		selectionOverlay.layer.borderColor = UIColor.tintColor.cgColor
		selectionOverlay.layer.cornerRadius = 4
		#endif
		selectionOverlay.isHidden = true
		addSubview(selectionOverlay)

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

		// Selection overlay matches entire cell
		constraints.append(contentsOf: [
			selectionOverlay.topAnchor.constraint(equalTo: topAnchor),
			selectionOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
			selectionOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
			selectionOverlay.bottomAnchor.constraint(equalTo: bottomAnchor)
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
		selectionOverlay.isHidden = true
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
		selectionOverlay.isHidden = !selected
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
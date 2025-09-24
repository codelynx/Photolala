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
	private var photoImageView: XImageView!
	private var loadingView: XActivityIndicator!
	private var selectionOverlay: XView!
	private var currentLoadTask: Task<Void, Never>?

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

		// Create image view
		photoImageView = XImageView()
		photoImageView.translatesAutoresizingMaskIntoConstraints = false
		#if os(macOS)
		photoImageView.imageScaling = .scaleProportionallyUpOrDown
		photoImageView.wantsLayer = true
		photoImageView.layer?.cornerRadius = 4
		photoImageView.layer?.masksToBounds = true
		#else
		photoImageView.contentMode = .scaleAspectFill
		photoImageView.clipsToBounds = true
		#endif
		addSubview(photoImageView)

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
	}

	private func setupConstraints() {
		// Explicit constraints for both platforms (especially important for AppKit)
		NSLayoutConstraint.activate([
			// Image view fills the cell
			photoImageView.topAnchor.constraint(equalTo: topAnchor),
			photoImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
			photoImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
			photoImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

			// Loading indicator centered
			loadingView.centerXAnchor.constraint(equalTo: centerXAnchor),
			loadingView.centerYAnchor.constraint(equalTo: centerYAnchor),

			// Selection overlay matches bounds
			selectionOverlay.topAnchor.constraint(equalTo: topAnchor),
			selectionOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
			selectionOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
			selectionOverlay.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
	}

	// MARK: - Public API
	func configure(with item: PhotoBrowserItem, source: any PhotoSourceProtocol) {
		// Cancel previous load
		currentLoadTask?.cancel()

		// Reset state
		photoImageView.image = nil
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
						self.photoImageView.image = thumbnail
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
		stopLoading() // Stop any ongoing animation
		photoImageView.image = nil
		selectionOverlay.isHidden = true
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
}
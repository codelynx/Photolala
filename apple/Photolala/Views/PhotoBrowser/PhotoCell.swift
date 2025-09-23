//
//  PhotoCell.swift
//  Photolala
//
//  Collection view cell for displaying photo thumbnails
//

import SwiftUI

#if os(macOS)
import AppKit

class PhotoCell: NSCollectionViewItem {
	static let reuseIdentifier = "PhotoCell"

	private var photoImageView: NSImageView!
	private var loadingView: NSProgressIndicator!
	private var selectionOverlay: NSView!
	private var currentLoadTask: Task<Void, Never>?

	override func loadView() {
		view = NSView()
		view.wantsLayer = true
		view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
		view.layer?.cornerRadius = 4

		// Image view
		photoImageView = NSImageView()
		photoImageView.translatesAutoresizingMaskIntoConstraints = false
		photoImageView.imageScaling = .scaleProportionallyUpOrDown
		photoImageView.wantsLayer = true
		photoImageView.layer?.cornerRadius = 4
		photoImageView.layer?.masksToBounds = true
		view.addSubview(photoImageView)

		// Loading indicator
		loadingView = NSProgressIndicator()
		loadingView.translatesAutoresizingMaskIntoConstraints = false
		loadingView.style = .spinning
		loadingView.isDisplayedWhenStopped = false
		view.addSubview(loadingView)

		// Selection overlay
		selectionOverlay = NSView()
		selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
		selectionOverlay.wantsLayer = true
		selectionOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
		selectionOverlay.layer?.cornerRadius = 4
		selectionOverlay.layer?.borderWidth = 3
		selectionOverlay.layer?.borderColor = NSColor.controlAccentColor.cgColor
		selectionOverlay.isHidden = true
		view.addSubview(selectionOverlay)

		// Constraints
		NSLayoutConstraint.activate([
			photoImageView.topAnchor.constraint(equalTo: view.topAnchor),
			photoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			photoImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			photoImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

			loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

			selectionOverlay.topAnchor.constraint(equalTo: view.topAnchor),
			selectionOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			selectionOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			selectionOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}

	override var isSelected: Bool {
		didSet {
			selectionOverlay.isHidden = !isSelected
		}
	}

	func configure(with item: PhotoBrowserItem, source: any PhotoSourceProtocol) {
		// Cancel previous load
		currentLoadTask?.cancel()

		// Reset state
		photoImageView.image = nil
		loadingView.startAnimation(nil)

		// Load thumbnail off main actor
		currentLoadTask = Task {
			do {
				// Load thumbnail in background
				let thumbnail = try await source.loadThumbnail(for: item.id)

				// Check if task was cancelled
				if Task.isCancelled { return }

				// Update UI on main actor
				await MainActor.run {
					self.loadingView.stopAnimation(nil)
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
					self.loadingView.stopAnimation(nil)
					self.showError()
				}
			}
		}
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		currentLoadTask?.cancel()
		currentLoadTask = nil
		photoImageView.image = nil
		selectionOverlay.isHidden = true
	}

	private func showPlaceholder() {
		// Show a placeholder image or color
		view.layer?.backgroundColor = NSColor.controlColor.cgColor
	}

	private func showError() {
		// Show error state
		view.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
	}
}

#else
import UIKit

class PhotoCell: UICollectionViewCell {
	static let reuseIdentifier = "PhotoCell"

	private var imageView: UIImageView!
	private var loadingView: UIActivityIndicatorView!
	private var selectionOverlay: UIView!
	private var currentLoadTask: Task<Void, Never>?

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupViews()
	}

	private func setupViews() {
		contentView.backgroundColor = .secondarySystemBackground
		contentView.layer.cornerRadius = 4
		contentView.clipsToBounds = true

		// Image view
		imageView = UIImageView()
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		contentView.addSubview(imageView)

		// Loading indicator
		loadingView = UIActivityIndicatorView(style: .medium)
		loadingView.translatesAutoresizingMaskIntoConstraints = false
		loadingView.hidesWhenStopped = true
		contentView.addSubview(loadingView)

		// Selection overlay
		selectionOverlay = UIView()
		selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
		selectionOverlay.backgroundColor = UIColor.tintColor.withAlphaComponent(0.3)
		selectionOverlay.layer.borderWidth = 3
		selectionOverlay.layer.borderColor = UIColor.tintColor.cgColor
		selectionOverlay.layer.cornerRadius = 4
		selectionOverlay.isHidden = true
		contentView.addSubview(selectionOverlay)

		// Constraints
		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
			imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

			loadingView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
			loadingView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

			selectionOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
			selectionOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			selectionOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			selectionOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
		])
	}

	override var isSelected: Bool {
		didSet {
			selectionOverlay.isHidden = !isSelected
		}
	}

	func configure(with item: PhotoBrowserItem, source: any PhotoSourceProtocol) {
		// Cancel previous load
		currentLoadTask?.cancel()

		// Reset state
		imageView.image = nil
		loadingView.startAnimating()

		// Load thumbnail off main actor
		currentLoadTask = Task {
			do {
				// Load thumbnail in background
				let thumbnail = try await source.loadThumbnail(for: item.id)

				// Check if task was cancelled
				if Task.isCancelled { return }

				// Update UI on main actor
				await MainActor.run {
					self.loadingView.stopAnimating()
					if let thumbnail = thumbnail {
						self.imageView.image = thumbnail
					} else {
						// Show placeholder for missing thumbnail
						self.showPlaceholder()
					}
				}
			} catch {
				// Check if task was cancelled
				if Task.isCancelled { return }

				await MainActor.run {
					self.loadingView.stopAnimating()
					self.showError()
				}
			}
		}
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		currentLoadTask?.cancel()
		currentLoadTask = nil
		imageView.image = nil
		selectionOverlay.isHidden = true
	}

	private func showPlaceholder() {
		// Show a placeholder image or color
		contentView.backgroundColor = .tertiarySystemBackground
	}

	private func showError() {
		// Show error state
		contentView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
	}
}
#endif
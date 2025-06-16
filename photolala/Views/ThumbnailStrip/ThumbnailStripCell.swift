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
			self.thumbnailImageView = NSImageView()
			self.thumbnailImageView.imageScaling = .scaleAxesIndependently
			self.thumbnailImageView.wantsLayer = true
			self.thumbnailImageView.layer?.cornerRadius = 4
			self.thumbnailImageView.layer?.masksToBounds = true
			self.thumbnailImageView.layer?.contentsGravity = .resizeAspectFill
			self.thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false

			// Create loading indicator
			self.loadingIndicator = NSProgressIndicator()
			self.loadingIndicator.style = .spinning
			self.loadingIndicator.controlSize = .small
			self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
			self.loadingIndicator.isHidden = true

			// Create selection border
			self.selectionBorder = CALayer()
			self.selectionBorder.borderColor = self.regularBorderColor
			self.selectionBorder.borderWidth = self.regularBorderWidth
			self.selectionBorder.cornerRadius = 4

			view.addSubview(self.thumbnailImageView)
			view.addSubview(self.loadingIndicator)

			// Add selection border on top
			view.wantsLayer = true
			view.layer?.addSublayer(self.selectionBorder)
			self.selectionBorder.zPosition = 100 // Ensure it's on top

			// Set background
			view.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.3).cgColor
			view.layer?.cornerRadius = 4

			NSLayoutConstraint.activate([
				self.thumbnailImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
				self.thumbnailImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
				self.thumbnailImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
				self.thumbnailImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),

				self.loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
				self.loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
			])
		}

		override func viewDidLayout() {
			super.viewDidLayout()
			self.selectionBorder.frame = view.bounds
		}

		override func prepareForReuse() {
			super.prepareForReuse()
			self.thumbnailImageView.image = nil
			self.currentPhoto = nil
			self.loadTask?.cancel()
			self.loadTask = nil
			self.setSelected(false, animated: false)
			view.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.3).cgColor
		}

		func configure(with photo: PhotoReference, isSelected: Bool) {
			self.currentPhoto = photo
			self.setSelected(isSelected, animated: false)

			// Check if thumbnail is already cached in PhotoReference
			if let cached = photo.thumbnail {
				self.thumbnailImageView.image = cached
				view.layer?.backgroundColor = nil
				self.loadingIndicator.stopAnimation(nil)
				self.loadingIndicator.isHidden = true
			} else {
				// Show loading state and load thumbnail
				self.thumbnailImageView.image = nil
				view.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.3).cgColor
				self.loadingIndicator.isHidden = false
				self.loadingIndicator.startAnimation(nil)

				// Load thumbnail
				self.loadTask = Task { @MainActor in
					await self.loadThumbnail(for: photo)
				}
			}
		}

		func setSelected(_ selected: Bool, animated: Bool) {
			self.isSelectedState = selected

			let duration = animated ? 0.2 : 0

			NSAnimationContext.runAnimationGroup { context in
				context.duration = duration
				context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

				if selected {
					self.selectionBorder.borderWidth = self.selectedBorderWidth
					self.selectionBorder.borderColor = self.selectedBorderColor
					view.animator().layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
				} else {
					self.selectionBorder.borderWidth = self.regularBorderWidth
					self.selectionBorder.borderColor = self.regularBorderColor
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
					guard self.currentPhoto === photo else { return }

					self.thumbnailImageView.image = thumbnail
					view.layer?.backgroundColor = nil
					self.loadingIndicator.stopAnimation(nil)
					self.loadingIndicator.isHidden = true
				}
			} catch {
				// Show error state
				guard self.currentPhoto === photo else { return }
				view.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.1).cgColor
				self.loadingIndicator.stopAnimation(nil)
				self.loadingIndicator.isHidden = true
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
			self.setupViews()
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		private func setupViews() {
			contentView.layer.cornerRadius = 4
			contentView.clipsToBounds = true
			contentView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)

			// Create image view
			self.thumbnailImageView = UIImageView()
			self.thumbnailImageView.contentMode = .scaleAspectFill
			self.thumbnailImageView.clipsToBounds = true
			self.thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false

			// Create loading indicator
			self.loadingIndicator = UIActivityIndicatorView(style: .medium)
			self.loadingIndicator.color = .white
			self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
			self.loadingIndicator.hidesWhenStopped = true

			// Create selection border
			self.selectionBorder = CALayer()
			self.selectionBorder.borderColor = self.normalBorderColor
			self.selectionBorder.borderWidth = self.normalBorderWidth
			self.selectionBorder.cornerRadius = 4
			self.selectionBorder.frame = contentView.bounds

			contentView.addSubview(self.thumbnailImageView)
			contentView.addSubview(self.loadingIndicator)
			contentView.layer.addSublayer(self.selectionBorder)
			self.selectionBorder.zPosition = 100 // Ensure it's on top

			NSLayoutConstraint.activate([
				self.thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
				self.thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
				self.thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
				self.thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

				self.loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
				self.loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			])
		}

		override func layoutSubviews() {
			super.layoutSubviews()
			self.selectionBorder.frame = contentView.bounds
		}

		override func prepareForReuse() {
			super.prepareForReuse()
			self.thumbnailImageView.image = nil
			self.currentPhoto = nil
			self.loadTask?.cancel()
			self.loadTask = nil
			self.setSelected(false, animated: false)
			contentView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
		}

		func configure(with photo: PhotoReference, isSelected: Bool) {
			self.currentPhoto = photo
			self.setSelected(isSelected, animated: false)

			// Check if thumbnail is already cached in PhotoReference
			if let cached = photo.thumbnail {
				self.thumbnailImageView.image = cached
				contentView.backgroundColor = nil
				self.loadingIndicator.stopAnimating()
			} else {
				// Show loading state and load thumbnail
				self.thumbnailImageView.image = nil
				contentView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
				self.loadingIndicator.startAnimating()

				// Load thumbnail
				self.loadTask = Task { @MainActor in
					await self.loadThumbnail(for: photo)
				}
			}
		}

		func setSelected(_ selected: Bool, animated: Bool) {
			self.isSelectedState = selected

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
					guard self.currentPhoto === photo else { return }

					self.thumbnailImageView.image = thumbnail
					contentView.backgroundColor = nil
					self.loadingIndicator.stopAnimating()
				}
			} catch {
				// Show error state
				guard self.currentPhoto === photo else { return }
				contentView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
				self.loadingIndicator.stopAnimating()
			}
		}
	}
#endif

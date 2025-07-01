//
//  PhotoContextMenuHeaderView.swift
//  photolala
//
//  Created on 6/15/2025.
//

#if os(macOS)
	import AppKit

	/// Custom view for the context menu header showing photo preview and metadata
	class PhotoContextMenuHeaderView: NSView {
		private let imageView: ScalableImageView
		private let filenameLabel: NSTextField
		private let dimensionsLabel: NSTextField
		private let dateLabel: NSTextField
		private let cameraLabel: NSTextField
		private let loadingSpinner: NSProgressIndicator
		private let metadataStack: NSStackView

		private var photo: PhotoFile?
		private var loadingTask: Task<Void, Never>?

		override init(frame frameRect: NSRect) {
			// Initialize image view
			self.imageView = ScalableImageView(frame: .zero)
			self.imageView.scaleMode = .scaleToFit // This ensures aspect ratio is maintained
			self.imageView.wantsLayer = true
			self.imageView.layer?.backgroundColor = NSColor.clear.cgColor
			self.imageView.layer?.borderWidth = 1
			self.imageView.layer?.borderColor = NSColor.separatorColor.cgColor
			self.imageView.layer?.cornerRadius = 4
			self.imageView.layer?.masksToBounds = true
			self.imageView.translatesAutoresizingMaskIntoConstraints = false
			// Don't set imageScaling - let ScalableImageView handle it

			// Initialize labels
			self.filenameLabel = NSTextField(labelWithString: "")
			self.filenameLabel.font = .systemFont(ofSize: 13, weight: .medium)
			self.filenameLabel.textColor = .labelColor
			self.filenameLabel.lineBreakMode = .byTruncatingMiddle
			self.filenameLabel.maximumNumberOfLines = 1

			self.dimensionsLabel = NSTextField(labelWithString: "")
			self.dimensionsLabel.font = .systemFont(ofSize: 11)
			self.dimensionsLabel.textColor = .secondaryLabelColor

			self.dateLabel = NSTextField(labelWithString: "")
			self.dateLabel.font = .systemFont(ofSize: 11)
			self.dateLabel.textColor = .secondaryLabelColor

			self.cameraLabel = NSTextField(labelWithString: "")
			self.cameraLabel.font = .systemFont(ofSize: 11)
			self.cameraLabel.textColor = .secondaryLabelColor

			// Initialize spinner
			self.loadingSpinner = NSProgressIndicator()
			self.loadingSpinner.style = .spinning
			self.loadingSpinner.controlSize = .small
			self.loadingSpinner.isDisplayedWhenStopped = false

			// Create metadata stack
			self.metadataStack = NSStackView(views: [
				self.filenameLabel,
				self.dimensionsLabel,
				self.dateLabel,
				self.cameraLabel,
			])
			self.metadataStack.orientation = .vertical
			self.metadataStack.alignment = .leading
			self.metadataStack.spacing = 2
			self.metadataStack.setHuggingPriority(.defaultHigh, for: .horizontal)

			super.init(frame: frameRect)

			// Disable autoresizing mask translation
			self.translatesAutoresizingMaskIntoConstraints = false

			self.setupViews()
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		deinit {
			loadingTask?.cancel()
		}

		private func setupViews() {
			// Add image view
			addSubview(self.imageView)
			self.imageView.translatesAutoresizingMaskIntoConstraints = false

			// Add metadata stack
			addSubview(self.metadataStack)
			self.metadataStack.translatesAutoresizingMaskIntoConstraints = false

			// Add spinner
			addSubview(self.loadingSpinner)
			self.loadingSpinner.translatesAutoresizingMaskIntoConstraints = false

			// Layout constraints
			NSLayoutConstraint.activate([
				// Image view - 512x512 with padding
				self.imageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
				self.imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
				self.imageView.widthAnchor.constraint(equalToConstant: 512),
				self.imageView.heightAnchor.constraint(equalToConstant: 512),

				// Metadata stack below image
				self.metadataStack.topAnchor.constraint(equalTo: self.imageView.bottomAnchor, constant: 16),
				self.metadataStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
				self.metadataStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
				self.metadataStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

				// Spinner centered on image view
				self.loadingSpinner.centerXAnchor.constraint(equalTo: self.imageView.centerXAnchor),
				self.loadingSpinner.centerYAnchor.constraint(equalTo: self.imageView.centerYAnchor),
			])
		}

		func configure(with photo: PhotoFile, displayMode: ThumbnailDisplayMode) {
			self.photo = photo

			// Cancel any existing loading task
			self.loadingTask?.cancel()

			// Update scale mode - always use scaleToFit for context menu preview
			self.imageView.scaleMode = .scaleToFit // We want to see the whole image in the preview

			// Set filename
			self.filenameLabel.stringValue = photo.filename

			// Show immediate metadata if available
			self.updateMetadata()

			// Load thumbnail and metadata
			self.loadingTask = Task {
				await self.loadContent()
			}
		}

		private func updateMetadata() {
			guard let photo else { return }

			// File creation date (always available)
			if let date = photo.fileCreationDate {
				let formatter = DateFormatter()
				formatter.dateStyle = .medium
				formatter.timeStyle = .short
				self.dateLabel.stringValue = formatter.string(from: date)
			} else {
				self.dateLabel.stringValue = ""
			}

			// Metadata if already loaded
			if let metadata = photo.metadata {
				self.dimensionsLabel.stringValue = "\(metadata.dimensions ?? "Unknown") • \(metadata.formattedFileSize)"
				self.cameraLabel.stringValue = metadata.cameraInfo ?? ""
			} else {
				self.dimensionsLabel.stringValue = "Loading..."
				self.cameraLabel.stringValue = ""
			}

			// Invalidate intrinsic content size when metadata changes
			invalidateIntrinsicContentSize()
		}

		private func loadContent() async {
			guard let photo else { return }

			// Start spinner
			await MainActor.run {
				self.loadingSpinner.startAnimation(nil)
			}

			// Load thumbnail - PhotoManager will handle the sizing
			do {
				let thumbnail = try await PhotoManager.shared.thumbnail(for: photo)

				// Load metadata if not already loaded
				if photo.metadata == nil {
					_ = try? await photo.loadPhotoData()
				}

				// Update UI on main thread
				await MainActor.run {
					self.imageView.image = thumbnail
					self.loadingSpinner.stopAnimation(nil)
					self.updateMetadata()
				}
			} catch {
				// Show error state
				await MainActor.run {
					self.loadingSpinner.stopAnimation(nil)
					self.imageView.image = NSImage(
						systemSymbolName: "exclamationmark.triangle",
						accessibilityDescription: "Error loading image"
					)
				}
			}
		}

		override var intrinsicContentSize: NSSize {
			// Width is fixed: 512 (image) + 32 (padding)
			let width: CGFloat = 544

			// Calculate height based on content
			var height: CGFloat = 16 // top padding
			height += 512 // image height
			height += 16 // spacing between image and metadata

			// Calculate metadata stack height
			let metadataHeight = self.metadataStack.fittingSize.height
			height += metadataHeight

			height += 16 // bottom padding

			return NSSize(width: width, height: height)
		}

		override func layout() {
			super.layout()
			// Invalidate intrinsic content size when layout changes
			invalidateIntrinsicContentSize()
		}
	}

	/// Helper to create multiple selection header
	class PhotoContextMenuMultipleSelectionView: NSView {
		private let label: NSTextField

		override init(frame frameRect: NSRect) {
			self.label = NSTextField(labelWithString: "")
			self.label.font = .systemFont(ofSize: 13, weight: .medium)
			self.label.textColor = .labelColor
			self.label.alignment = .center

			super.init(frame: frameRect)

			self.translatesAutoresizingMaskIntoConstraints = false

			addSubview(self.label)
			self.label.translatesAutoresizingMaskIntoConstraints = false

			NSLayoutConstraint.activate([
				self.label.topAnchor.constraint(equalTo: topAnchor, constant: 20),
				self.label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
				self.label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
				self.label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),

				widthAnchor.constraint(equalToConstant: 200),
			])
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		func configure(with count: Int) {
			self.label.stringValue = "\(count) photos selected"
		}

		override var intrinsicContentSize: NSSize {
			NSSize(width: 200, height: 60)
		}
	}
#endif

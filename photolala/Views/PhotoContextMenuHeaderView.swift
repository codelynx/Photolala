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
	
	private var photo: PhotoReference?
	private var loadingTask: Task<Void, Never>?
	
	override init(frame frameRect: NSRect) {
		// Initialize image view
		imageView = ScalableImageView(frame: .zero)
		imageView.scaleMode = .scaleToFit
		imageView.wantsLayer = true
		imageView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
		imageView.layer?.cornerRadius = 4
		
		// Initialize labels
		filenameLabel = NSTextField(labelWithString: "")
		filenameLabel.font = .systemFont(ofSize: 13, weight: .medium)
		filenameLabel.textColor = .labelColor
		filenameLabel.lineBreakMode = .byTruncatingMiddle
		filenameLabel.maximumNumberOfLines = 1
		
		dimensionsLabel = NSTextField(labelWithString: "")
		dimensionsLabel.font = .systemFont(ofSize: 11)
		dimensionsLabel.textColor = .secondaryLabelColor
		
		dateLabel = NSTextField(labelWithString: "")
		dateLabel.font = .systemFont(ofSize: 11)
		dateLabel.textColor = .secondaryLabelColor
		
		cameraLabel = NSTextField(labelWithString: "")
		cameraLabel.font = .systemFont(ofSize: 11)
		cameraLabel.textColor = .secondaryLabelColor
		
		// Initialize spinner
		loadingSpinner = NSProgressIndicator()
		loadingSpinner.style = .spinning
		loadingSpinner.controlSize = .small
		loadingSpinner.isDisplayedWhenStopped = false
		
		// Create metadata stack
		metadataStack = NSStackView(views: [filenameLabel, dimensionsLabel, dateLabel, cameraLabel])
		metadataStack.orientation = .vertical
		metadataStack.alignment = .leading
		metadataStack.spacing = 2
		metadataStack.setHuggingPriority(.defaultHigh, for: .horizontal)
		
		super.init(frame: frameRect)
		
		setupViews()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	deinit {
		loadingTask?.cancel()
	}
	
	private func setupViews() {
		// Add image view
		addSubview(imageView)
		imageView.translatesAutoresizingMaskIntoConstraints = false
		
		// Add metadata stack
		addSubview(metadataStack)
		metadataStack.translatesAutoresizingMaskIntoConstraints = false
		
		// Add spinner
		addSubview(loadingSpinner)
		loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
		
		// Layout constraints
		NSLayoutConstraint.activate([
			// Image view - 512x512 with padding
			imageView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
			imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
			imageView.widthAnchor.constraint(equalToConstant: 512),
			imageView.heightAnchor.constraint(equalToConstant: 512),
			
			// Metadata stack below image
			metadataStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
			metadataStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			metadataStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
			metadataStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
			
			// Spinner centered on image view
			loadingSpinner.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
			loadingSpinner.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
			
			// Total width
			widthAnchor.constraint(equalToConstant: 544) // 512 + 32 padding
		])
	}
	
	func configure(with photo: PhotoReference, displayMode: ThumbnailDisplayMode) {
		self.photo = photo
		
		// Cancel any existing loading task
		loadingTask?.cancel()
		
		// Update scale mode
		imageView.scaleMode = displayMode == .scaleToFit ? .scaleToFit : .scaleToFill
		
		// Set filename
		filenameLabel.stringValue = photo.filename
		
		// Show immediate metadata if available
		updateMetadata()
		
		// Load thumbnail and metadata
		loadingTask = Task {
			await loadContent()
		}
	}
	
	private func updateMetadata() {
		guard let photo = photo else { return }
		
		// File modification date (always available)
		if let date = photo.fileModificationDate {
			let formatter = DateFormatter()
			formatter.dateStyle = .medium
			formatter.timeStyle = .short
			dateLabel.stringValue = formatter.string(from: date)
		} else {
			dateLabel.stringValue = ""
		}
		
		// Metadata if already loaded
		if let metadata = photo.metadata {
			dimensionsLabel.stringValue = "\(metadata.dimensions ?? "Unknown") • \(metadata.formattedFileSize)"
			cameraLabel.stringValue = metadata.cameraInfo ?? ""
		} else {
			dimensionsLabel.stringValue = "Loading..."
			cameraLabel.stringValue = ""
		}
	}
	
	private func loadContent() async {
		guard let photo = photo else { return }
		
		// Start spinner
		await MainActor.run {
			loadingSpinner.startAnimation(nil)
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
				self.imageView.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error loading image")
			}
		}
	}
	
	override var intrinsicContentSize: NSSize {
		return NSSize(width: 544, height: -1) // Width fixed, height flexible
	}
}

/// Helper to create multiple selection header
class PhotoContextMenuMultipleSelectionView: NSView {
	private let label: NSTextField
	
	override init(frame frameRect: NSRect) {
		label = NSTextField(labelWithString: "")
		label.font = .systemFont(ofSize: 13, weight: .medium)
		label.textColor = .labelColor
		label.alignment = .center
		
		super.init(frame: frameRect)
		
		addSubview(label)
		label.translatesAutoresizingMaskIntoConstraints = false
		
		NSLayoutConstraint.activate([
			label.topAnchor.constraint(equalTo: topAnchor, constant: 20),
			label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
			label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
			label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
			
			widthAnchor.constraint(equalToConstant: 200)
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func configure(with count: Int) {
		label.stringValue = "\(count) photos selected"
	}
}
#endif
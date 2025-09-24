//
//  ImageFrameView.swift
//  Photolala
//
//  Wrapper view for proper image clipping with fit/fill modes
//

import SwiftUI

#if os(macOS)
import AppKit

/// Wrapper view that properly clips NSImageView with fit/fill modes
class ImageFrameView: NSView {
	// The image view we're managing
	let imageView: NSImageView

	// Display mode
	var displayMode: ThumbnailDisplayMode = .fill {
		didSet {
			updateImageScaling()
			#if os(macOS)
			needsUpdateConstraints = true
			needsDisplay = true
			if displayMode == .fill && image != nil {
				adjustImageViewSizeForFill()
			}
			#else
			setNeedsLayout()
			#endif
		}
	}

	init() {
		self.imageView = NSImageView()
		super.init(frame: .zero)
		setupView()
	}

	required init?(coder: NSCoder) {
		self.imageView = NSImageView()
		super.init(coder: coder)
		setupView()
	}

	private func setupView() {
		// Configure frame view
		wantsLayer = true
		layer?.masksToBounds = true
		layer?.cornerRadius = 4

		// Configure image view
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.wantsLayer = true
		imageView.layer?.masksToBounds = true
		addSubview(imageView)

		// Initial scaling mode
		updateImageScaling()

		// Add constraints based on mode
		updateConstraints()
	}

	private var imageViewConstraints: [NSLayoutConstraint] = []

	override func updateConstraints() {
		// Deactivate old constraints
		NSLayoutConstraint.deactivate(imageViewConstraints)
		imageViewConstraints.removeAll()

		switch displayMode {
		case .fit:
			// Aspect fit - image view matches frame exactly
			imageViewConstraints = [
				imageView.topAnchor.constraint(equalTo: topAnchor),
				imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
				imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
				imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
			]
		case .fill:
			// Aspect fill - center image view, allow it to extend beyond bounds
			imageViewConstraints = [
				imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
				imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
			]
			// Size constraints will be set in adjustImageViewSizeForFill
		}

		NSLayoutConstraint.activate(imageViewConstraints)
		super.updateConstraints()
	}

	private func updateImageScaling() {
		switch displayMode {
		case .fit:
			// Scale proportionally down to fit
			imageView.imageScaling = .scaleProportionallyDown
		case .fill:
			// Scale proportionally up or down to fill
			imageView.imageScaling = .scaleProportionallyUpOrDown
		}
	}

	var image: NSImage? {
		get { imageView.image }
		set {
			imageView.image = newValue
			if displayMode == .fill && newValue != nil {
				// For fill mode, we need to resize the image view to match aspect ratio
				adjustImageViewSizeForFill()
			}
		}
	}

	private var fillSizeConstraints: [NSLayoutConstraint] = []

	private func adjustImageViewSizeForFill() {
		guard let image = imageView.image,
			  image.size.width > 0,
			  image.size.height > 0,
			  bounds.width > 0,
			  bounds.height > 0 else { return }

		let imageAspect = image.size.width / image.size.height
		let frameAspect = bounds.width / bounds.height

		// Deactivate old fill constraints
		NSLayoutConstraint.deactivate(fillSizeConstraints)
		fillSizeConstraints.removeAll()

		if imageAspect > frameAspect {
			// Image is wider - fit height, overflow width
			fillSizeConstraints = [
				imageView.heightAnchor.constraint(equalTo: heightAnchor),
				imageView.widthAnchor.constraint(equalTo: heightAnchor, multiplier: imageAspect)
			]
		} else {
			// Image is taller - fit width, overflow height
			fillSizeConstraints = [
				imageView.widthAnchor.constraint(equalTo: widthAnchor),
				imageView.heightAnchor.constraint(equalTo: widthAnchor, multiplier: 1/imageAspect)
			]
		}

		NSLayoutConstraint.activate(fillSizeConstraints)
	}

	override func layout() {
		super.layout()
		if displayMode == .fill && imageView.image != nil {
			adjustImageViewSizeForFill()
		}
	}
}

#else
import UIKit

/// Wrapper view that properly clips UIImageView with fit/fill modes
class ImageFrameView: UIView {
	// The image view we're managing
	let imageView: UIImageView

	// Display mode
	var displayMode: ThumbnailDisplayMode = .fill {
		didSet {
			updateImageScaling()
			#if os(macOS)
			needsUpdateConstraints = true
			needsDisplay = true
			if displayMode == .fill && image != nil {
				adjustImageViewSizeForFill()
			}
			#else
			setNeedsLayout()
			#endif
		}
	}

	override init(frame: CGRect) {
		self.imageView = UIImageView()
		super.init(frame: frame)
		setupView()
	}

	required init?(coder: NSCoder) {
		self.imageView = UIImageView()
		super.init(coder: coder)
		setupView()
	}

	private func setupView() {
		// Configure frame view
		clipsToBounds = true
		layer.cornerRadius = 4

		// Configure image view
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.clipsToBounds = true
		addSubview(imageView)

		// Initial scaling mode
		updateImageScaling()

		// Setup constraints
		setupConstraints()
	}

	private func setupConstraints() {
		NSLayoutConstraint.activate([
			imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
			imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
			imageView.widthAnchor.constraint(equalTo: widthAnchor),
			imageView.heightAnchor.constraint(equalTo: heightAnchor)
		])
	}

	private func updateImageScaling() {
		switch displayMode {
		case .fit:
			imageView.contentMode = .scaleAspectFit
		case .fill:
			imageView.contentMode = .scaleAspectFill
		}
	}

	var image: UIImage? {
		get { imageView.image }
		set { imageView.image = newValue }
	}
}
#endif
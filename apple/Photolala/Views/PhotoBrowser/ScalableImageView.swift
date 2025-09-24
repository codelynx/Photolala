//
//  ScalableImageView.swift
//  Photolala
//
//  Custom NSImageView that properly handles fit/fill scaling modes
//

import SwiftUI

#if os(macOS)
import AppKit

class ScalableImageView: NSImageView {
	var displayMode: ThumbnailDisplayMode = .fill {
		didSet {
			needsDisplay = true
		}
	}

	override func draw(_ dirtyRect: NSRect) {
		guard let image = image else {
			super.draw(dirtyRect)
			return
		}

		// Clear the background
		NSColor.clear.set()
		dirtyRect.fill()

		let imageSize = image.size
		let frameSize = bounds.size

		// Calculate aspect ratios
		let imageAspect = imageSize.width / imageSize.height
		let frameAspect = frameSize.width / frameSize.height

		var drawRect: NSRect

		switch displayMode {
		case .fit:
			// Scale to fit - entire image visible, may have letterboxing
			if imageAspect > frameAspect {
				// Image is wider - fit width
				let height = frameSize.width / imageAspect
				drawRect = NSRect(
					x: 0,
					y: (frameSize.height - height) / 2,
					width: frameSize.width,
					height: height
				)
			} else {
				// Image is taller - fit height
				let width = frameSize.height * imageAspect
				drawRect = NSRect(
					x: (frameSize.width - width) / 2,
					y: 0,
					width: width,
					height: frameSize.height
				)
			}

		case .fill:
			// Scale to fill - fills entire frame, may crop image
			if imageAspect > frameAspect {
				// Image is wider - fit height and crop sides
				let width = frameSize.height * imageAspect
				drawRect = NSRect(
					x: (frameSize.width - width) / 2,
					y: 0,
					width: width,
					height: frameSize.height
				)
			} else {
				// Image is taller - fit width and crop top/bottom
				let height = frameSize.width / imageAspect
				drawRect = NSRect(
					x: 0,
					y: (frameSize.height - height) / 2,
					width: frameSize.width,
					height: height
				)
			}
		}

		// Draw the image
		image.draw(in: drawRect,
				   from: NSRect(origin: .zero, size: imageSize),
				   operation: .sourceOver,
				   fraction: 1.0,
				   respectFlipped: true,
				   hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)])
	}
}

#else
import UIKit

class ScalableImageView: UIImageView {
	var displayMode: ThumbnailDisplayMode = .fill {
		didSet {
			updateContentMode()
		}
	}

	private func updateContentMode() {
		switch displayMode {
		case .fit:
			contentMode = .scaleAspectFit
		case .fill:
			contentMode = .scaleAspectFill
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		clipsToBounds = true
		updateContentMode()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		clipsToBounds = true
		updateContentMode()
	}
}
#endif
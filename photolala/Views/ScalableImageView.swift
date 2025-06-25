//
//  ScalableImageView.swift
//  photolala
//
//  Created by Claude on 2025/06/15.
//

#if os(macOS)
	import AppKit

	/// A custom NSImageView that provides proper scale-to-fit and scale-to-fill modes
	/// similar to UIImageView's content modes on iOS.
	class ScalableImageView: NSImageView {

		enum ScaleMode {
			case scaleToFit
			case scaleToFill
		}

		var scaleMode: ScaleMode = .scaleToFit {
			didSet {
				needsDisplay = true
			}
		}

		override init(frame frameRect: NSRect) {
			super.init(frame: frameRect)
			self.wantsLayer = true
			self.layer?.backgroundColor = .clear
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		override func layout() {
			super.layout()
		}

		override func draw(_ dirtyRect: NSRect) {
			NSColor.clear.set()
			self.bounds.fill()

			guard let image = self.image else {
				super.draw(dirtyRect)
				return
			}

			// Calculate the appropriate draw rect based on scale mode
			let drawRect: NSRect = switch self.scaleMode {
			case .scaleToFit:
				self.aspectFitRect(for: image.size, in: bounds)

			case .scaleToFill:
				self.aspectFillRect(for: image.size, in: bounds)
			}

			// Save graphics state for clipping
			NSGraphicsContext.saveGraphicsState()

			// Always clip to bounds to prevent overflow
			NSBezierPath(rect: bounds).setClip()

			// Draw the image
			image.draw(
				in: drawRect,
				from: NSRect(origin: .zero, size: image.size),
				operation: .sourceOver,
				fraction: 1.0,
				respectFlipped: true,
				hints: [.interpolation: NSImageInterpolation.high]
			)

			// Restore graphics state
			NSGraphicsContext.restoreGraphicsState()
		}

		private func aspectFitRect(for imageSize: NSSize, in bounds: NSRect) -> NSRect {
			// Avoid division by zero
			guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
				return bounds
			}

			let imageAspect = imageSize.width / imageSize.height
			let viewAspect = bounds.width / bounds.height

			var drawRect = bounds

			if imageAspect > viewAspect {
				// Image is wider - fit by width
				drawRect.size.height = bounds.width / imageAspect
				drawRect.origin.y = (bounds.height - drawRect.height) / 2
			} else {
				// Image is taller - fit by height
				drawRect.size.width = bounds.height * imageAspect
				drawRect.origin.x = (bounds.width - drawRect.width) / 2
			}

			return drawRect
		}

		private func aspectFillRect(for imageSize: NSSize, in bounds: NSRect) -> NSRect {
			// Avoid division by zero
			guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
				return bounds
			}

			let imageAspect = imageSize.width / imageSize.height
			let viewAspect = bounds.width / bounds.height

			var drawRect = bounds

			if imageAspect > viewAspect {
				// Image is wider - scale by height to fill vertically
				let scale = bounds.height / imageSize.height
				drawRect.size.width = imageSize.width * scale
				drawRect.origin.x = (bounds.width - drawRect.width) / 2
			} else {
				// Image is taller - scale by width to fill horizontally
				let scale = bounds.width / imageSize.width
				drawRect.size.height = imageSize.height * scale
				drawRect.origin.y = (bounds.height - drawRect.height) / 2
			}

			return drawRect
		}
	}
#endif

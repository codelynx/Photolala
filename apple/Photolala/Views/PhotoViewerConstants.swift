import Foundation
import CoreGraphics

/// Shared constants for photo viewer
enum PhotoViewerConstants {
	// Zoom limits
	static let minZoomScale: CGFloat = 1.0
	static let maxZoomScale: CGFloat = 5.0
	static let doubleTapZoomScale: CGFloat = 2.0
	
	// Animation
	static let springResponse: Double = 0.3
	static let springDamping: Double = 0.8
	
	// Control timers
	static let controlHideDelay: TimeInterval = 30.0
	
	// Gesture thresholds
	static let swipeThreshold: CGFloat = 50
	static let tapZoneWidth: CGFloat = 0.25 // 25% of screen width
	
	// UI dimensions
	static let controlStripHeight: CGFloat = 44
	static let thumbnailSize = CGSize(width: 60, height: 60)
}
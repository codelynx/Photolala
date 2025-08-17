import Foundation
import CoreGraphics

/// Preview modes for photo viewer
enum PreviewMode: String, Hashable {
	case all = "all"
	case selection = "selection"
}

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
	static let controlHideDelay: TimeInterval = 6.0  // Hide controls after 6 seconds of inactivity
	
	// Gesture thresholds
	static let swipeThreshold: CGFloat = 50
	static let tapZoneWidth: CGFloat = 0.25 // 25% of screen width
	
	// UI dimensions
	static let controlStripHeight: CGFloat = 44
	static let thumbnailSize = CGSize(width: 60, height: 60)
}
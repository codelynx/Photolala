package com.electricwoods.photolala.ui.components

/**
 * Shared constants for photo viewer across the app
 */
object PhotoViewerConstants {
	// Zoom limits
	const val MIN_ZOOM_SCALE = 1f
	const val MAX_ZOOM_SCALE = 5f
	const val DOUBLE_TAP_ZOOM_SCALE = 2f
	
	// UI dimensions
	const val NAVIGATION_BUTTON_SIZE = 48
	const val NAVIGATION_ICON_SIZE = 32
	const val NAVIGATION_BUTTON_ALPHA = 0.5f
	
	// Animation durations
	const val CONTROL_HIDE_DELAY_MS = 30_000L // 30 seconds
	
	// Gesture thresholds
	const val SWIPE_THRESHOLD = 50f
}
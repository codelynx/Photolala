package com.electricwoods.photolala.utils

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo

/**
 * Extension function to find the Activity from a Context.
 * This is necessary because Compose LocalContext might be a ContextWrapper.
 */
fun Context.findActivity(): Activity? = when (this) {
	is Activity -> this
	is ContextWrapper -> baseContext.findActivity()
	else -> null
}

/**
 * Manages screen orientation locking based on content fit requirements.
 * Locks to portrait when screen width would cause UI elements to be clipped in landscape.
 */
object OrientationManager {
	
	/**
	 * Threshold for minimum width where content fits well in landscape.
	 * Below this width, auth forms and UI elements may get clipped.
	 * 600dp is a common breakpoint where tablets start.
	 */
	private const val LANDSCAPE_WIDTH_THRESHOLD_DP = 600
	
	/**
	 * Locks the activity to portrait if the screen is too narrow for landscape content.
	 * This prevents UI clipping on smaller devices while allowing rotation on larger screens.
	 */
	fun lockToPortraitIfNeeded(activity: Activity) {
		if (shouldLockToPortrait(activity)) {
			// Force portrait orientation immediately
			activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
		} else {
			// Keep current orientation for larger screens
			activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
		}
	}
	
	/**
	 * Unlocks orientation, allowing the system to handle rotation normally.
	 */
	fun unlockOrientation(activity: Activity) {
		activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
	}
	
	/**
	 * Determines if the screen should be locked to portrait based on available width.
	 * Uses smallestScreenWidthDp which remains constant regardless of current orientation.
	 * 
	 * @return true if content would be clipped in landscape, false if it fits well
	 */
	private fun shouldLockToPortrait(context: Context): Boolean {
		val configuration = context.resources.configuration
		// smallestScreenWidthDp is the smaller of width/height regardless of orientation
		// This gives us a consistent measure of whether content will fit in landscape
		return configuration.smallestScreenWidthDp < LANDSCAPE_WIDTH_THRESHOLD_DP
	}
}
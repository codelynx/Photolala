package com.electricwoods.photolala.ui.components

import android.app.Activity
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext
import com.electricwoods.photolala.utils.OrientationManager
import com.electricwoods.photolala.utils.findActivity

/**
 * A Composable effect that locks the screen to portrait orientation on smaller devices
 * where content might be clipped in landscape mode.
 * 
 * This effect automatically:
 * - Locks to portrait when the composable enters composition (if needed)
 * - Unlocks orientation when the composable leaves composition
 * 
 * Usage:
 * ```
 * @Composable
 * fun MyScreen() {
 *     LockToPortraitEffect()
 *     // Rest of your screen content
 * }
 * ```
 */
@Composable
fun LockToPortraitEffect() {
	val context = LocalContext.current
	
	DisposableEffect(Unit) {
		// Use findActivity extension to properly get the Activity
		val activity = context.findActivity()
		
		if (activity != null) {
			// Lock orientation when entering this screen (if screen is too small)
			OrientationManager.lockToPortraitIfNeeded(activity)
		}
		
		// Don't unlock on dispose - let the next screen handle its own orientation
		onDispose {
			// Removed unlock to prevent race condition during navigation
		}
	}
}

/**
 * A Composable effect that unlocks screen orientation, allowing free rotation.
 * Use this on screens where users should be able to rotate the device freely.
 * 
 * Usage:
 * ```
 * @Composable
 * fun PhotoGridScreen() {
 *     UnlockOrientationEffect()
 *     // Rest of your screen content
 * }
 * ```
 */
@Composable
fun UnlockOrientationEffect() {
	val context = LocalContext.current
	
	DisposableEffect(Unit) {
		// Use findActivity extension to properly get the Activity
		val activity = context.findActivity()
		
		if (activity != null) {
			OrientationManager.unlockOrientation(activity)
		}
		
		onDispose {
			// No action needed on dispose
		}
	}
}
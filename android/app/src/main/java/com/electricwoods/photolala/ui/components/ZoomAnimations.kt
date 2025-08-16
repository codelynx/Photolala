package com.electricwoods.photolala.ui.components

import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.spring

/**
 * Consistent animation specifications for zoom/pan gestures
 */
object ZoomAnimations {
	val defaultSpring: AnimationSpec<Float> = spring(
		dampingRatio = 0.8f,
		stiffness = 300f
	)
	
	val quickSpring: AnimationSpec<Float> = spring(
		dampingRatio = 0.7f,
		stiffness = 400f
	)
	
	val smoothSpring: AnimationSpec<Float> = spring(
		dampingRatio = 0.9f,
		stiffness = 200f
	)
}
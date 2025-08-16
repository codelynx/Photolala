package com.electricwoods.photolala.ui.components

import androidx.compose.runtime.*
import androidx.compose.ui.geometry.Offset
import kotlin.math.max

/**
 * Manages zoom and pan state for a zoomable image.
 */
@Stable
class ZoomState(
	val minScale: Float = 1f,
	val maxScale: Float = 5f,
	val doubleTapScale: Float = 2f
) {
	var scale by mutableStateOf(minScale)
		private set
	
	var offsetX by mutableStateOf(0f)
		private set
	
	var offsetY by mutableStateOf(0f)
		private set
	
	val isZoomed: Boolean
		get() = scale > minScale
	
	fun updateScale(newScale: Float) {
		scale = newScale.coerceIn(minScale, maxScale)
		if (scale <= minScale) {
			reset()
		}
	}
	
	fun updateOffset(deltaX: Float, deltaY: Float) {
		offsetX += deltaX
		offsetY += deltaY
	}
	
	fun constrainOffset(containerWidth: Float, containerHeight: Float) {
		val maxX = max(0f, (containerWidth * (scale - 1)) / 2)
		val maxY = max(0f, (containerHeight * (scale - 1)) / 2)
		offsetX = offsetX.coerceIn(-maxX, maxX)
		offsetY = offsetY.coerceIn(-maxY, maxY)
	}
	
	fun toggleZoom() {
		if (isZoomed) {
			reset()
		} else {
			scale = doubleTapScale
			offsetX = 0f
			offsetY = 0f
		}
	}
	
	fun reset() {
		scale = minScale
		offsetX = 0f
		offsetY = 0f
	}
}

@Composable
fun rememberZoomState(
	minScale: Float = 1f,
	maxScale: Float = 5f,
	doubleTapScale: Float = 2f
): ZoomState {
	return remember {
		ZoomState(minScale, maxScale, doubleTapScale)
	}
}
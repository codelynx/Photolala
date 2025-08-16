package com.electricwoods.photolala.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import coil.compose.AsyncImage
import coil.request.ImageRequest
import kotlinx.coroutines.launch

/**
 * A zoomable image component with iOS-like zoom/pan behavior.
 * 
 * This refactored version uses:
 * - ZoomState for state management
 * - PhotoViewerConstants for configuration
 * - ZoomAnimations for consistent animations
 * 
 * Features:
 * - Configurable min/max zoom levels
 * - Double-tap to zoom
 * - Boundary constraints to prevent image disappearing
 * - Smooth animations
 * - Single-finger pan when zoomed
 * - Pinch to zoom
 */
@Composable
fun PhotoZoomableImage(
	imageUri: Any?,
	contentDescription: String?,
	modifier: Modifier = Modifier,
	minZoomScale: Float = PhotoViewerConstants.MIN_ZOOM_SCALE,
	maxZoomScale: Float = PhotoViewerConstants.MAX_ZOOM_SCALE,
	doubleTapZoomScale: Float = PhotoViewerConstants.DOUBLE_TAP_ZOOM_SCALE,
	contentScale: ContentScale = ContentScale.Fit,
	onZoomStateChanged: ((Boolean) -> Unit)? = null
) {
	// Use the extracted state management
	val zoomState = rememberZoomState(
		minScale = minZoomScale,
		maxScale = maxZoomScale,
		doubleTapScale = doubleTapZoomScale
	)
	
	val coroutineScope = rememberCoroutineScope()
	
	// Notify parent when zoom state changes
	LaunchedEffect(zoomState.isZoomed) {
		onZoomStateChanged?.invoke(zoomState.isZoomed)
	}
	
	// Animated values using shared animation specs
	val animatedScale by animateFloatAsState(
		targetValue = zoomState.scale,
		animationSpec = ZoomAnimations.defaultSpring,
		label = "scale"
	)
	
	val animatedOffsetX by animateFloatAsState(
		targetValue = zoomState.offsetX,
		animationSpec = ZoomAnimations.defaultSpring,
		label = "offsetX"
	)
	
	val animatedOffsetY by animateFloatAsState(
		targetValue = zoomState.offsetY,
		animationSpec = ZoomAnimations.defaultSpring,
		label = "offsetY"
	)
	
	BoxWithConstraints(
		modifier = modifier
			.fillMaxSize()
			.background(Color.Black),
		contentAlignment = Alignment.Center
	) {
		val containerWidth = constraints.maxWidth.toFloat()
		val containerHeight = constraints.maxHeight.toFloat()
		
		Box(
			modifier = Modifier
				.fillMaxSize()
				.pointerInput(Unit) {
					// Pinch to zoom and two-finger pan
					detectTransformGestures { _, pan, zoom, _ ->
						zoomState.updateScale(zoomState.scale * zoom)
						
						if (zoomState.isZoomed) {
							zoomState.updateOffset(pan.x, pan.y)
							zoomState.constrainOffset(containerWidth, containerHeight)
						}
					}
				}
				.pointerInput(zoomState.scale) {
					// Single finger drag when zoomed
					if (zoomState.isZoomed) {
						detectDragGestures { _, dragAmount ->
							zoomState.updateOffset(dragAmount.x, dragAmount.y)
							zoomState.constrainOffset(containerWidth, containerHeight)
						}
					}
				}
				.pointerInput(Unit) {
					// Double tap to toggle zoom
					detectTapGestures(
						onDoubleTap = {
							coroutineScope.launch {
								zoomState.toggleZoom()
							}
						}
					)
				},
			contentAlignment = Alignment.Center
		) {
			AsyncImage(
				model = ImageRequest.Builder(LocalContext.current)
					.data(imageUri)
					.crossfade(true)
					.build(),
				contentDescription = contentDescription,
				contentScale = contentScale,
				modifier = Modifier
					.fillMaxSize()
					.graphicsLayer {
						scaleX = animatedScale
						scaleY = animatedScale
						translationX = animatedOffsetX
						translationY = animatedOffsetY
					}
					.clip(RectangleShape)
			)
		}
	}
}
package com.electricwoods.photolala.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntSize
import coil.compose.AsyncImage
import coil.request.ImageRequest
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * A zoomable image component with iOS-like zoom/pan behavior.
 * Features:
 * - Configurable min/max zoom levels
 * - Double-tap to zoom
 * - Boundary constraints to prevent image disappearing
 * - Smooth animations
 * - Delta-based scaling to prevent jumps
 */
@Composable
fun PhotoZoomableImage(
	imageUri: Any?,
	contentDescription: String?,
	modifier: Modifier = Modifier,
	minZoomScale: Float = 1f,
	maxZoomScale: Float = 5f,
	doubleTapZoomScale: Float = 2f,
	contentScale: ContentScale = ContentScale.Fit
) {
	var scale by remember { mutableStateOf(1f) }
	var offsetX by remember { mutableStateOf(0f) }
	var offsetY by remember { mutableStateOf(0f) }
	
	// Track gesture state for delta calculations (like iOS steadyState)
	var lastScale by remember { mutableStateOf(1f) }
	var lastOffset by remember { mutableStateOf(Offset.Zero) }
	
	// Track image size for boundary calculations
	var imageSize by remember { mutableStateOf(IntSize.Zero) }
	var containerSize by remember { mutableStateOf(IntSize.Zero) }
	
	val coroutineScope = rememberCoroutineScope()
	
	// Animated values for smooth transitions
	val animatedScale by animateFloatAsState(
		targetValue = scale,
		animationSpec = spring(
			dampingRatio = 0.8f,
			stiffness = 300f
		),
		label = "scale"
	)
	
	val animatedOffsetX by animateFloatAsState(
		targetValue = offsetX,
		animationSpec = spring(
			dampingRatio = 0.8f,
			stiffness = 300f
		),
		label = "offsetX"
	)
	
	val animatedOffsetY by animateFloatAsState(
		targetValue = offsetY,
		animationSpec = spring(
			dampingRatio = 0.8f,
			stiffness = 300f
		),
		label = "offsetY"
	)
	
	// Calculate max offset based on zoom scale (same formula as iOS)
	fun calculateMaxOffset(): Pair<Float, Float> {
		if (containerSize.width == 0 || containerSize.height == 0) {
			return Pair(0f, 0f)
		}
		
		val maxX = max(0f, (containerSize.width * (scale - 1)) / 2)
		val maxY = max(0f, (containerSize.height * (scale - 1)) / 2)
		return Pair(maxX, maxY)
	}
	
	// Constrain offset to boundaries
	fun constrainOffset() {
		val (maxX, maxY) = calculateMaxOffset()
		offsetX = offsetX.coerceIn(-maxX, maxX)
		offsetY = offsetY.coerceIn(-maxY, maxY)
	}
	
	// Reset zoom and position
	fun reset() {
		scale = minZoomScale
		offsetX = 0f
		offsetY = 0f
		lastScale = 1f
		lastOffset = Offset.Zero
	}
	
	Box(
		modifier = modifier
			.fillMaxSize()
			.background(Color.Black)
			.pointerInput(Unit) {
				detectTransformGestures { _, pan, zoom, _ ->
					// Handle zoom with simple multiplication
					scale = (scale * zoom).coerceIn(minZoomScale, maxZoomScale)
					
					// Handle pan when zoomed
					if (scale > minZoomScale) {
						// Direct pan application
						offsetX += pan.x
						offsetY += pan.y
						
						// Constrain to boundaries
						constrainOffset()
					}
					
					// Reset when at minimum zoom
					if (scale <= minZoomScale) {
						scale = minZoomScale
						offsetX = 0f
						offsetY = 0f
					}
				}
			}
			.pointerInput(Unit) {
				detectTapGestures(
					onDoubleTap = {
						coroutineScope.launch {
							if (scale > minZoomScale) {
								// Reset to minimum zoom
								reset()
							} else {
								// Zoom to double-tap scale
								scale = doubleTapZoomScale
								// Reset offsets when zooming in
								offsetX = 0f
								offsetY = 0f
							}
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
				.clip(RectangleShape),
			onSuccess = { state ->
				// Store image size for boundary calculations
				state.result.drawable.intrinsicWidth.let { width ->
					state.result.drawable.intrinsicHeight.let { height ->
						imageSize = IntSize(width, height)
					}
				}
			}
		)
	}
}
package com.electricwoods.photolala.ui.components

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.ColorPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.electricwoods.photolala.models.PhotoFile
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.models.PhotoS3
import com.electricwoods.photolala.viewmodels.PhotoDigestViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Composable that displays a photo using the PhotoDigest caching system
 * Provides a drop-in replacement for AsyncImage with PhotoDigest support
 */
@Composable
fun PhotoDigestImage(
	photo: Any,
	contentDescription: String?,
	modifier: Modifier = Modifier,
	contentScale: ContentScale = ContentScale.Fit,
	placeholder: Color = Color.LightGray,
	error: Color = Color.Red.copy(alpha = 0.3f),
	photoDigestViewModel: PhotoDigestViewModel = viewModel()
) {
	var bitmap by remember(photo) { mutableStateOf<Bitmap?>(null) }
	var isLoading by remember(photo) { mutableStateOf(true) }
	var hasError by remember(photo) { mutableStateOf(false) }
	
	// Load thumbnail when photo changes
	LaunchedEffect(photo) {
		isLoading = true
		hasError = false
		bitmap = null
		
		try {
			withContext(Dispatchers.IO) {
				bitmap = photoDigestViewModel.getThumbnail(photo)
				if (bitmap == null) {
					hasError = true
				}
			}
		} catch (e: Exception) {
			hasError = true
		} finally {
			isLoading = false
		}
	}
	
	Box(
		modifier = modifier,
		contentAlignment = Alignment.Center
	) {
		when {
			isLoading -> {
				// Loading state
				Box(
					modifier = Modifier
						.fillMaxSize()
						.background(placeholder),
					contentAlignment = Alignment.Center
				) {
					CircularProgressIndicator()
				}
			}
			hasError || bitmap == null -> {
				// Error state
				Box(
					modifier = Modifier
						.fillMaxSize()
						.background(error)
				)
			}
			else -> {
				// Success state
				Image(
					painter = BitmapPainter(bitmap!!.asImageBitmap()),
					contentDescription = contentDescription,
					contentScale = contentScale,
					modifier = Modifier.fillMaxSize()
				)
			}
		}
	}
}

/**
 * Wrapper for PhotoMediaStore photos
 */
@Composable
fun PhotoDigestImageMediaStore(
	photo: PhotoMediaStore,
	contentDescription: String? = photo.filename,
	modifier: Modifier = Modifier,
	contentScale: ContentScale = ContentScale.Fit,
	placeholder: Color = Color.LightGray,
	error: Color = Color.Red.copy(alpha = 0.3f)
) {
	PhotoDigestImage(
		photo = photo,
		contentDescription = contentDescription,
		modifier = modifier,
		contentScale = contentScale,
		placeholder = placeholder,
		error = error
	)
}

/**
 * Wrapper for PhotoFile photos
 */
@Composable
fun PhotoDigestImageFile(
	photo: PhotoFile,
	contentDescription: String? = photo.filename,
	modifier: Modifier = Modifier,
	contentScale: ContentScale = ContentScale.Fit,
	placeholder: Color = Color.LightGray,
	error: Color = Color.Red.copy(alpha = 0.3f)
) {
	PhotoDigestImage(
		photo = photo,
		contentDescription = contentDescription,
		modifier = modifier,
		contentScale = contentScale,
		placeholder = placeholder,
		error = error
	)
}

/**
 * Wrapper for PhotoS3 photos
 */
@Composable
fun PhotoDigestImageS3(
	photo: PhotoS3,
	contentDescription: String? = photo.displayName,
	modifier: Modifier = Modifier,
	contentScale: ContentScale = ContentScale.Fit,
	placeholder: Color = Color.LightGray,
	error: Color = Color.Red.copy(alpha = 0.3f)
) {
	PhotoDigestImage(
		photo = photo,
		contentDescription = contentDescription,
		modifier = modifier,
		contentScale = contentScale,
		placeholder = placeholder,
		error = error
	)
}
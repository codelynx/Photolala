package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.ui.components.UnlockOrientationEffect
import com.electricwoods.photolala.ui.components.ViewOptionsMenu
import com.electricwoods.photolala.ui.viewmodels.PhotoViewerViewModel
import net.engawapg.lib.zoomable.rememberZoomState
import net.engawapg.lib.zoomable.zoomable

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun PhotoViewerScreen(
	initialIndex: Int,
	onBackClick: () -> Unit,
	viewModel: PhotoViewerViewModel = hiltViewModel()
) {
	// Allow free rotation for photo viewing - users should be able to view photos in landscape
	UnlockOrientationEffect()
	
	val photos by viewModel.photos.collectAsState()
	val currentPhoto by viewModel.currentPhoto.collectAsState()
	val showInfo by viewModel.showInfo.collectAsState()
	val scaleMode by viewModel.scaleMode.collectAsState()
	
	val pagerState = rememberPagerState(
		initialPage = initialIndex,
		pageCount = { photos.size }
	)
	
	// Update current photo when page changes
	LaunchedEffect(pagerState.currentPage) {
		viewModel.setCurrentIndex(pagerState.currentPage)
	}
	
	Scaffold(
		modifier = Modifier.fillMaxSize(),
		topBar = {
			TopAppBar(
				title = { 
					Text(
						text = currentPhoto?.filename ?: "Photo",
						style = MaterialTheme.typography.titleMedium
					) 
				},
				navigationIcon = {
					IconButton(onClick = onBackClick) {
						Icon(
							imageVector = Icons.Default.ArrowBack,
							contentDescription = "Back"
						)
					}
				},
				actions = {
					IconButton(onClick = { viewModel.toggleInfo() }) {
						Icon(
							imageVector = Icons.Default.Info,
							contentDescription = "Photo Info"
						)
					}
					ViewOptionsMenu(
						currentScaleMode = scaleMode,
						onScaleModeChange = { viewModel.toggleScaleMode() }
					)
				},
				colors = TopAppBarDefaults.topAppBarColors(
					containerColor = Color.Black.copy(alpha = 0.7f),
					titleContentColor = Color.White,
					navigationIconContentColor = Color.White,
					actionIconContentColor = Color.White
				)
			)
		},
		containerColor = Color.Black
	) { paddingValues ->
		Box(
			modifier = Modifier
				.fillMaxSize()
				.padding(paddingValues)
		) {
			// Photo pager
			HorizontalPager(
				state = pagerState,
				modifier = Modifier.fillMaxSize()
			) { page ->
				PhotoPage(
					photo = photos.getOrNull(page),
					scaleMode = scaleMode,
					modifier = Modifier.fillMaxSize()
				)
			}
			
			// Photo info overlay
			if (showInfo && currentPhoto != null) {
				PhotoInfoOverlay(
					photo = currentPhoto!!,
					modifier = Modifier
						.align(Alignment.BottomCenter)
						.fillMaxWidth()
				)
			}
			
			// Page indicator
			Row(
				modifier = Modifier
					.align(Alignment.BottomCenter)
					.padding(bottom = if (showInfo) 120.dp else 16.dp),
				horizontalArrangement = Arrangement.Center
			) {
				Text(
					text = "${pagerState.currentPage + 1} / ${photos.size}",
					color = Color.White,
					style = MaterialTheme.typography.bodyMedium,
					modifier = Modifier
						.background(
							Color.Black.copy(alpha = 0.5f),
							MaterialTheme.shapes.small
						)
						.padding(horizontal = 12.dp, vertical = 4.dp)
				)
			}
		}
	}
}

@Composable
private fun PhotoPage(
	photo: PhotoMediaStore?,
	scaleMode: String,
	modifier: Modifier = Modifier
) {
	if (photo == null) {
		Box(
			modifier = modifier.background(Color.Black),
			contentAlignment = Alignment.Center
		) {
			CircularProgressIndicator(color = Color.White)
		}
		return
	}
	
	val zoomState = rememberZoomState()
	
	AsyncImage(
		model = ImageRequest.Builder(LocalContext.current)
			.data(photo.uri)
			.crossfade(true)
			.build(),
		contentDescription = photo.filename,
		contentScale = if (scaleMode == "fill") ContentScale.Crop else ContentScale.Fit,
		modifier = modifier
			.fillMaxSize()
			.zoomable(zoomState)
	)
}

@Composable
private fun PhotoInfoOverlay(
	photo: PhotoMediaStore,
	modifier: Modifier = Modifier
) {
	Surface(
		modifier = modifier,
		color = Color.Black.copy(alpha = 0.8f)
	) {
		Column(
			modifier = Modifier
				.fillMaxWidth()
				.padding(16.dp)
		) {
			// Filename
			Text(
				text = photo.filename,
				style = MaterialTheme.typography.titleSmall,
				color = Color.White
			)
			
			Spacer(modifier = Modifier.height(8.dp))
			
			// Details in grid
			Row(
				modifier = Modifier.fillMaxWidth(),
				horizontalArrangement = Arrangement.SpaceBetween
			) {
				// Size
				Column {
					Text(
						text = "Size",
						style = MaterialTheme.typography.labelSmall,
						color = Color.Gray
					)
					Text(
						text = formatFileSize(photo.fileSize ?: 0),
						style = MaterialTheme.typography.bodySmall,
						color = Color.White
					)
				}
				
				// Dimensions
				if (photo.width != null && photo.height != null) {
					Column {
						Text(
							text = "Dimensions",
							style = MaterialTheme.typography.labelSmall,
							color = Color.Gray
						)
						Text(
							text = "${photo.width} × ${photo.height}",
							style = MaterialTheme.typography.bodySmall,
							color = Color.White
						)
					}
				}
				
				// Date
				Column {
					Text(
						text = "Modified",
						style = MaterialTheme.typography.labelSmall,
						color = Color.Gray
					)
					Text(
						text = photo.modificationDate?.let {
							java.text.SimpleDateFormat("MMM d, yyyy", java.util.Locale.getDefault()).format(it)
						} ?: "Unknown",
						style = MaterialTheme.typography.bodySmall,
						color = Color.White
					)
				}
			}
		}
	}
}

private fun formatFileSize(bytes: Long): String {
	return when {
		bytes < 1024 -> "$bytes B"
		bytes < 1024 * 1024 -> "${bytes / 1024} KB"
		else -> String.format("%.1f MB", bytes / (1024.0 * 1024.0))
	}
}
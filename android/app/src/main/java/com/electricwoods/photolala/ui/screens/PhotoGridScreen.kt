package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.electricwoods.photolala.R
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.ui.viewmodels.PhotoGridViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PhotoGridScreen(
	modifier: Modifier = Modifier,
	viewModel: PhotoGridViewModel = hiltViewModel(),
	onPhotoClick: (PhotoMediaStore, Int) -> Unit = { _, _ -> }
) {
	val photos by viewModel.photos.collectAsState()
	val isLoading by viewModel.isLoading.collectAsState()
	val error by viewModel.error.collectAsState()
	
	// Load photos on first composition
	LaunchedEffect(Unit) {
		viewModel.loadPhotos()
	}
	
	Scaffold(
		modifier = modifier.fillMaxSize(),
		topBar = {
			TopAppBar(
				title = { Text("Photos") },
				actions = {
					IconButton(
						onClick = { viewModel.refreshPhotos() },
						enabled = !isLoading
					) {
						Icon(
							imageVector = Icons.Default.Refresh,
							contentDescription = "Refresh"
						)
					}
				}
			)
		}
	) { paddingValues ->
		Box(
			modifier = Modifier
				.fillMaxSize()
				.padding(paddingValues)
		) {
			when {
				error != null -> {
					// Error state
					ErrorContent(
						error = error!!,
						onRetry = { viewModel.loadPhotos() }
					)
				}
				photos.isEmpty() && !isLoading -> {
					// Empty state
					EmptyContent()
				}
				else -> {
					// Photo grid
					PhotoGrid(
						photos = photos,
						onPhotoClick = onPhotoClick,
						onLoadMore = { viewModel.loadMorePhotos() }
					)
				}
			}
			
			// Loading indicator
			if (isLoading && photos.isEmpty()) {
				CircularProgressIndicator(
					modifier = Modifier.align(Alignment.Center)
				)
			}
		}
	}
}

@Composable
private fun PhotoGrid(
	photos: List<PhotoMediaStore>,
	onPhotoClick: (PhotoMediaStore, Int) -> Unit,
	onLoadMore: () -> Unit
) {
	val gridState = rememberLazyGridState()
	
	// Detect when we need to load more photos
	val shouldLoadMore = remember {
		derivedStateOf {
			val layoutInfo = gridState.layoutInfo
			val totalItems = layoutInfo.totalItemsCount
			val lastVisibleItem = layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
			lastVisibleItem >= (totalItems - 20) && totalItems > 0
		}
	}
	
	LaunchedEffect(shouldLoadMore.value) {
		if (shouldLoadMore.value) {
			onLoadMore()
		}
	}
	
	LazyVerticalGrid(
		columns = GridCells.Fixed(3),
		state = gridState,
		contentPadding = PaddingValues(2.dp),
		horizontalArrangement = Arrangement.spacedBy(2.dp),
		verticalArrangement = Arrangement.spacedBy(2.dp),
		modifier = Modifier.fillMaxSize()
	) {
		items(
			items = photos,
			key = { it.id }
		) { photo ->
			PhotoThumbnail(
				photo = photo,
				onClick = { onPhotoClick(photo, photos.indexOf(photo)) }
			)
		}
	}
}

@Composable
private fun PhotoThumbnail(
	photo: PhotoMediaStore,
	onClick: () -> Unit
) {
	Box(
		modifier = Modifier
			.aspectRatio(1f)
			.clickable { onClick() }
			.background(Color.LightGray)
	) {
		AsyncImage(
			model = ImageRequest.Builder(LocalContext.current)
				.data(photo.uri)
				.crossfade(true)
				.size(300) // Request 300px thumbnails
				.build(),
			contentDescription = photo.filename,
			contentScale = ContentScale.Crop,
			modifier = Modifier.fillMaxSize(),
			placeholder = painterResource(R.drawable.ic_launcher_foreground), // Placeholder while loading
			error = painterResource(R.drawable.ic_launcher_foreground) // Error image
		)
	}
}

@Composable
private fun EmptyContent() {
	val context = LocalContext.current
	Column(
		modifier = Modifier
			.fillMaxSize()
			.padding(16.dp),
		verticalArrangement = Arrangement.Center,
		horizontalAlignment = Alignment.CenterHorizontally
	) {
		SelectionContainer {
			Column(
				horizontalAlignment = Alignment.CenterHorizontally
			) {
				Text(
					text = "No photos found",
					style = MaterialTheme.typography.titleMedium,
					color = MaterialTheme.colorScheme.onSurfaceVariant
				)
				Spacer(modifier = Modifier.height(8.dp))
				Text(
					text = "Grant permission to access your photos",
					style = MaterialTheme.typography.bodyMedium,
					color = MaterialTheme.colorScheme.onSurfaceVariant
				)
			}
		}
		Spacer(modifier = Modifier.height(24.dp))
		Button(
			onClick = {
				// Open app settings to grant permission
				val intent = android.content.Intent(
					android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
					android.net.Uri.fromParts("package", context.packageName, null)
				)
				context.startActivity(intent)
			}
		) {
			Text("Grant Permission")
		}
	}
}

@Composable
private fun ErrorContent(
	error: String,
	onRetry: () -> Unit
) {
	Column(
		modifier = Modifier
			.fillMaxSize()
			.padding(16.dp),
		verticalArrangement = Arrangement.Center,
		horizontalAlignment = Alignment.CenterHorizontally
	) {
		SelectionContainer {
			Column(
				horizontalAlignment = Alignment.CenterHorizontally
			) {
				Text(
					text = "Error loading photos",
					style = MaterialTheme.typography.titleMedium,
					color = MaterialTheme.colorScheme.error
				)
				Spacer(modifier = Modifier.height(8.dp))
				Text(
					text = error,
					style = MaterialTheme.typography.bodyMedium,
					color = MaterialTheme.colorScheme.onSurfaceVariant
				)
			}
		}
		Spacer(modifier = Modifier.height(16.dp))
		Button(onClick = onRetry) {
			Text("Retry")
		}
	}
}

@Preview(showBackground = true)
@Composable
fun PhotoGridScreenPreview() {
	MaterialTheme {
		PhotoGridScreen()
	}
}
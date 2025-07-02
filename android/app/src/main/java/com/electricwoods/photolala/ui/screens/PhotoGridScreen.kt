package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckBoxOutlineBlank
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.SelectAll
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.ColorPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import android.content.Intent
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.electricwoods.photolala.R
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.ui.viewmodels.PhotoGridViewModel

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun PhotoGridScreen(
	modifier: Modifier = Modifier,
	viewModel: PhotoGridViewModel = hiltViewModel(),
	onPhotoClick: (PhotoMediaStore, Int) -> Unit = { _, _ -> }
) {
	val photos by viewModel.photos.collectAsState()
	val isLoading by viewModel.isLoading.collectAsState()
	val error by viewModel.error.collectAsState()
	val isSelectionMode by viewModel.isSelectionMode.collectAsState()
	val selectedPhotos by viewModel.selectedPhotos.collectAsState()
	val selectionCount by viewModel.selectionCount.collectAsState()
	val areAllPhotosSelected by viewModel.areAllPhotosSelected.collectAsState()
	val context = LocalContext.current
	
	// Load photos on first composition
	LaunchedEffect(Unit) {
		viewModel.loadPhotos()
	}
	
	Scaffold(
		modifier = modifier.fillMaxSize(),
		topBar = {
			if (isSelectionMode) {
				SelectionTopBar(
					selectionCount = selectionCount,
					areAllSelected = areAllPhotosSelected,
					onClose = { viewModel.exitSelectionMode() },
					onToggleSelectAll = { viewModel.toggleSelectAll() },
					onShare = {
						val selectedUris = viewModel.getSelectedPhotoUris()
						if (selectedUris.isNotEmpty()) {
							sharePhotos(context, selectedUris)
						}
					},
					onDelete = {
						// DEVELOPMENT ONLY
						viewModel.deleteSelectedPhotos()
					}
				)
			} else {
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
						isSelectionMode = isSelectionMode,
						selectedPhotos = selectedPhotos,
						onPhotoClick = { photo, index ->
							// Tap always toggles selection
							if (!isSelectionMode) {
								// Enter selection mode and select this photo
								viewModel.startSelectionMode(photo.id)
							} else {
								// Toggle selection
								viewModel.toggleSelection(photo.id)
							}
						},
						onPhotoLongClick = { photo ->
							// Long-press always previews the photo
							val photoIndex = photos.indexOf(photo)
							if (photoIndex >= 0) {
								onPhotoClick(photo, photoIndex)
							}
						},
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

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PhotoGrid(
	photos: List<PhotoMediaStore>,
	isSelectionMode: Boolean,
	selectedPhotos: Set<String>,
	onPhotoClick: (PhotoMediaStore, Int) -> Unit,
	onPhotoLongClick: (PhotoMediaStore) -> Unit,
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
				isSelected = selectedPhotos.contains(photo.id),
				isSelectionMode = isSelectionMode,
				onClick = { onPhotoClick(photo, photos.indexOf(photo)) },
				onLongClick = { onPhotoLongClick(photo) }
			)
		}
	}
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PhotoThumbnail(
	photo: PhotoMediaStore,
	isSelected: Boolean,
	isSelectionMode: Boolean,
	onClick: () -> Unit,
	onLongClick: () -> Unit
) {
	Box(
		modifier = Modifier
			.aspectRatio(1f)
			.combinedClickable(
				onClick = onClick,
				onLongClick = onLongClick
			)
			.background(
				if (isSelected && isSelectionMode) {
					MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
				} else {
					Color.LightGray
				},
				shape = RoundedCornerShape(8.dp)
			)
			.then(
				if (isSelected) {
					Modifier.border(
						width = 3.dp,
						color = MaterialTheme.colorScheme.primary,
						shape = RoundedCornerShape(8.dp)
					)
				} else {
					Modifier
				}
			)
	) {
		AsyncImage(
			model = ImageRequest.Builder(LocalContext.current)
				.data(photo.uri)
				.crossfade(true)
				.size(400) // Larger thumbnail size
				.listener(
					onStart = {
						// Log when loading starts
						android.util.Log.d("PhotoGrid", "Loading image: ${photo.uri}")
					},
					onError = { _, result ->
						// Log any errors
						android.util.Log.e("PhotoGrid", "Error loading ${photo.uri}: ${result.throwable}")
					}
				)
				.build(),
			contentDescription = photo.filename,
			contentScale = ContentScale.Crop,
			modifier = Modifier.fillMaxSize(),
			placeholder = ColorPainter(Color.LightGray),
			error = ColorPainter(Color.Red.copy(alpha = 0.3f))
		)
	}
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SelectionTopBar(
	selectionCount: Int,
	areAllSelected: Boolean,
	onClose: () -> Unit,
	onToggleSelectAll: () -> Unit,
	onShare: () -> Unit,
	onDelete: () -> Unit
) {
	TopAppBar(
		title = { Text("$selectionCount selected") },
		navigationIcon = {
			IconButton(onClick = onClose) {
				Icon(
					imageVector = Icons.Default.Close,
					contentDescription = "Exit selection mode"
				)
			}
		},
		actions = {
			IconButton(onClick = onToggleSelectAll) {
				Icon(
					imageVector = if (areAllSelected) {
						Icons.Default.CheckBoxOutlineBlank
					} else {
						Icons.Default.SelectAll
					},
					contentDescription = if (areAllSelected) {
						"Deselect all"
					} else {
						"Select all"
					}
				)
			}
			if (selectionCount > 0) {
				IconButton(onClick = onShare) {
					Icon(
						imageVector = Icons.Default.Share,
						contentDescription = "Share selected"
					)
				}
				// DEVELOPMENT ONLY - Delete button
				IconButton(onClick = onDelete) {
					Icon(
						imageVector = Icons.Default.Delete,
						contentDescription = "Delete selected",
						tint = MaterialTheme.colorScheme.error
					)
				}
			}
		}
	)
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

// Share helper function
private fun sharePhotos(context: android.content.Context, uris: List<android.net.Uri>) {
	val intent = if (uris.size == 1) {
		// Single photo share
		Intent(Intent.ACTION_SEND).apply {
			type = "image/*"
			putExtra(Intent.EXTRA_STREAM, uris.first())
			addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
		}
	} else {
		// Multiple photos share
		Intent(Intent.ACTION_SEND_MULTIPLE).apply {
			type = "image/*"
			putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
			addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
		}
	}
	
	// Create chooser
	val chooser = Intent.createChooser(intent, "Share ${uris.size} photo${if (uris.size > 1) "s" else ""}")
	
	// Start the share activity
	try {
		context.startActivity(chooser)
	} catch (e: Exception) {
		// Handle case where no apps can handle the share intent
		android.widget.Toast.makeText(
			context,
			"No apps available to share photos",
			android.widget.Toast.LENGTH_SHORT
		).show()
	}
}
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
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.key.*
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.ColorPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import android.content.Intent
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.electricwoods.photolala.R
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.models.ColorFlag
import com.electricwoods.photolala.ui.viewmodels.PhotoGridViewModel
import com.electricwoods.photolala.ui.components.TagSelectionDialog

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
	val photoTags by viewModel.photoTags.collectAsState()
	val context = LocalContext.current
	
	// Tag selection dialog state
	var showTagDialog by remember { mutableStateOf(false) }
	
	// Focus for keyboard shortcuts
	val focusRequester = remember { FocusRequester() }
	val focusManager = LocalFocusManager.current
	
	// Request focus on first composition
	LaunchedEffect(Unit) {
		focusRequester.requestFocus()
	}
	
	// Load photos on first composition
	LaunchedEffect(Unit) {
		viewModel.loadPhotos()
	}
	
	Scaffold(
		modifier = modifier
			.fillMaxSize()
			.focusRequester(focusRequester)
			.onKeyEvent { event ->
				// Handle keyboard shortcuts when in selection mode
				if (isSelectionMode && event.type == KeyEventType.KeyDown) {
					when (event.key) {
						// Number keys 1-7 for color flags
						Key.One -> {
							ColorFlag.fromValue(1)?.let { viewModel.toggleTagForSelected(it) }
							true
						}
						Key.Two -> {
							ColorFlag.fromValue(2)?.let { viewModel.toggleTagForSelected(it) }
							true
						}
						Key.Three -> {
							ColorFlag.fromValue(3)?.let { viewModel.toggleTagForSelected(it) }
							true
						}
						Key.Four -> {
							ColorFlag.fromValue(4)?.let { viewModel.toggleTagForSelected(it) }
							true
						}
						Key.Five -> {
							ColorFlag.fromValue(5)?.let { viewModel.toggleTagForSelected(it) }
							true
						}
						Key.Six -> {
							ColorFlag.fromValue(6)?.let { viewModel.toggleTagForSelected(it) }
							true
						}
						Key.Seven -> {
							ColorFlag.fromValue(7)?.let { viewModel.toggleTagForSelected(it) }
							true
						}
						// T key to open tag dialog
						Key.T -> {
							showTagDialog = true
							true
						}
						// Escape to exit selection mode
						Key.Escape -> {
							viewModel.exitSelectionMode()
							true
						}
						else -> false
					}
				} else {
					false
				}
			},
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
					},
					onTag = {
						showTagDialog = true
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
						photoTags = photoTags,
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
	
	// Tag selection dialog
	if (showTagDialog) {
		val selectedIds = selectedPhotos.toList()
		val currentTags = if (selectedIds.size == 1) {
			// Single photo - show its current tags
			photoTags[selectedIds.first()] ?: emptySet()
		} else {
			// Multiple photos - show tags common to all
			if (selectedIds.isEmpty()) {
				emptySet()
			} else {
				selectedIds.map { photoTags[it] ?: emptySet() }
					.reduce { acc, tags -> acc.intersect(tags) }
			}
		}
		
		TagSelectionDialog(
			currentTags = currentTags,
			onDismiss = { showTagDialog = false },
			onToggleTag = { colorFlag ->
				viewModel.toggleTagForSelected(colorFlag)
			},
			onClearAll = {
				viewModel.removeAllTagsForSelected()
			}
		)
	}
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PhotoGrid(
	photos: List<PhotoMediaStore>,
	isSelectionMode: Boolean,
	selectedPhotos: Set<String>,
	photoTags: Map<String, Set<com.electricwoods.photolala.models.ColorFlag>>,
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
				tags = photoTags[photo.id] ?: emptySet(),
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
	tags: Set<com.electricwoods.photolala.models.ColorFlag>,
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
		
		// Tag flags overlay
		if (tags.isNotEmpty()) {
			Row(
				modifier = Modifier
					.align(Alignment.BottomStart)
					.padding(4.dp),
				horizontalArrangement = Arrangement.spacedBy(2.dp)
			) {
				tags.sortedBy { it.value }.forEach { colorFlag ->
					Icon(
						imageVector = Icons.Default.Flag,
						contentDescription = "Tag ${colorFlag.value}",
						modifier = Modifier.size(16.dp),
						tint = when (colorFlag.value) {
							1 -> Color.Red
							2 -> Color(0xFFFFA500) // Orange
							3 -> Color.Yellow
							4 -> Color.Green
							5 -> Color.Blue
							6 -> Color(0xFF800080) // Purple
							7 -> Color.Gray
							else -> Color.Gray
						}
					)
				}
			}
		}
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
	onDelete: () -> Unit,
	onTag: () -> Unit
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
				IconButton(onClick = onTag) {
					Icon(
						imageVector = Icons.Default.Flag,
						contentDescription = "Tag selected",
						tint = MaterialTheme.colorScheme.tertiary
					)
				}
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
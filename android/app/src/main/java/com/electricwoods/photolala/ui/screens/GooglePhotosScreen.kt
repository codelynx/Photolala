package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.electricwoods.photolala.models.PhotoGooglePhotos
import com.electricwoods.photolala.ui.components.TagSelectionDialog
import com.electricwoods.photolala.ui.components.GridViewOptionsMenu
import com.electricwoods.photolala.ui.components.BackupStatusIndicator
import com.electricwoods.photolala.viewmodels.GooglePhotosProvider

/**
 * Google Photos browser screen
 * Similar to ApplePhotosBrowserView on iOS
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GooglePhotosScreen(
	modifier: Modifier = Modifier,
	viewModel: GooglePhotosProvider = hiltViewModel(),
	onPhotoClick: (PhotoGooglePhotos, Int) -> Unit = { _, _ -> },
	onBackClick: (() -> Unit)? = null
) {
	val photos by viewModel.photos.collectAsState()
	val isLoading by viewModel.isLoading.collectAsState()
	val error by viewModel.error.collectAsState()
	val isAuthorized by viewModel.isAuthorized.collectAsState()
	val albums by viewModel.albums.collectAsState()
	val currentAlbum by viewModel.currentAlbum.collectAsState()
	
	// Selection state
	val isSelectionMode by viewModel.isSelectionMode.collectAsState()
	val selectedPhotos by viewModel.selectedPhotos.collectAsState()
	val selectionCount by viewModel.selectionCount.collectAsState()
	val areAllPhotosSelected by viewModel.areAllPhotosSelected.collectAsState()
	
	// Tags and stars
	val photoTags by viewModel.photoTags.collectAsState()
	val starredPhotos by viewModel.starredPhotos.collectAsState()
	
	// Grid preferences
	val thumbnailSize by viewModel.thumbnailSize.collectAsState()
	val gridScaleMode by viewModel.gridScaleMode.collectAsState()
	val showInfoBar by viewModel.showInfoBar.collectAsState()
	
	// UI state
	var showAlbumPicker by remember { mutableStateOf(false) }
	var showTagDialog by remember { mutableStateOf(false) }
	
	// Initial load
	LaunchedEffect(Unit) {
		viewModel.checkAuthorization()
		if (viewModel.isAuthorized.value) {
			viewModel.loadAlbums()
			viewModel.loadPhotos()
		}
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
					onTag = { showTagDialog = true },
					onStar = { viewModel.toggleStarForSelected() }
				)
			} else {
				TopAppBar(
					title = { Text(viewModel.displayTitle) },
					navigationIcon = {
						if (onBackClick != null) {
							IconButton(onClick = onBackClick) {
								Icon(
									imageVector = Icons.AutoMirrored.Filled.ArrowBack,
									contentDescription = "Back"
								)
							}
						}
					},
					actions = {
						// Album picker
						IconButton(onClick = { showAlbumPicker = true }) {
							Icon(
								imageVector = Icons.Default.PhotoAlbum,
								contentDescription = "Albums"
							)
						}
						
						// Refresh
						IconButton(
							onClick = { viewModel.refresh() },
							enabled = !isLoading
						) {
							Icon(
								imageVector = Icons.Default.Refresh,
								contentDescription = "Refresh"
							)
						}
						
						// Grid options
						GridViewOptionsMenu(
							currentThumbnailSize = thumbnailSize,
							currentScaleMode = gridScaleMode,
							showInfoBar = showInfoBar,
							onThumbnailSizeChange = viewModel::updateThumbnailSize,
							onScaleModeChange = viewModel::updateGridScaleMode,
							onShowInfoBarChange = viewModel::updateShowInfoBar
						)
					}
				)
			}
		}
	) { paddingValues ->
		Column(
			modifier = Modifier
				.fillMaxSize()
				.padding(paddingValues)
		) {
			// Backup status indicator
			BackupStatusIndicator(
				backupQueueManager = viewModel.backupQueueManager
			)
			
			// Main content
			Box(modifier = Modifier.fillMaxSize()) {
				val currentError = error
				when {
					!isAuthorized -> {
						// Not authorized
						NotAuthorizedContent(error = currentError)
					}
					currentError != null && photos.isEmpty() -> {
						// Error state
						ErrorContent(
							error = currentError,
							onRetry = { viewModel.refresh() }
						)
					}
					photos.isEmpty() && !isLoading -> {
						// Empty state
						EmptyContent()
					}
					else -> {
						// Photo grid
						GooglePhotosGrid(
							photos = photos,
							isSelectionMode = isSelectionMode,
							selectedPhotos = selectedPhotos,
							photoTags = photoTags,
							starredPhotos = starredPhotos,
							thumbnailSize = thumbnailSize,
							scaleMode = gridScaleMode,
							showInfoBar = showInfoBar,
							onPhotoClick = { photo, index ->
								if (!isSelectionMode) {
									viewModel.startSelectionMode(photo.id)
								} else {
									viewModel.toggleSelection(photo.id)
								}
							},
							onPhotoLongClick = { photo ->
								val photoIndex = photos.indexOf(photo)
								if (photoIndex >= 0) {
									onPhotoClick(photo, photoIndex)
								}
							},
							onStarClick = { photo ->
								viewModel.toggleStar(photo.id)
							},
							onLoadMore = { viewModel.loadMorePhotos() },
							getPhotoUrl = { photo ->
								viewModel.getPhotoUrl(photo)
							}
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
	
	// Album picker dialog
	if (showAlbumPicker) {
		AlbumPickerDialog(
			albums = albums,
			currentAlbum = currentAlbum,
			onAlbumSelected = { album ->
				viewModel.selectAlbum(album)
				showAlbumPicker = false
			},
			onDismiss = { showAlbumPicker = false }
		)
	}
	
	// Tag selection dialog
	if (showTagDialog) {
		val selectedIds = selectedPhotos.toList()
		val currentTags = if (selectedIds.size == 1) {
			photoTags[selectedIds.first()] ?: emptySet()
		} else {
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

@Composable
private fun GooglePhotosGrid(
	photos: List<PhotoGooglePhotos>,
	isSelectionMode: Boolean,
	selectedPhotos: Set<String>,
	photoTags: Map<String, Set<com.electricwoods.photolala.models.ColorFlag>>,
	starredPhotos: Set<String>,
	thumbnailSize: Int,
	scaleMode: String,
	showInfoBar: Boolean,
	onPhotoClick: (PhotoGooglePhotos, Int) -> Unit,
	onPhotoLongClick: (PhotoGooglePhotos) -> Unit,
	onStarClick: (PhotoGooglePhotos) -> Unit,
	onLoadMore: () -> Unit,
	getPhotoUrl: suspend (PhotoGooglePhotos) -> String
) {
	// Reuse the existing photo grid implementation
	// This would be similar to PhotoGrid in PhotoGridScreen
	// For now, a simplified version:
	
	val context = LocalContext.current
	
	androidx.compose.foundation.lazy.grid.LazyVerticalGrid(
		columns = androidx.compose.foundation.lazy.grid.GridCells.Adaptive(minSize = thumbnailSize.dp),
		contentPadding = PaddingValues(2.dp),
		horizontalArrangement = Arrangement.spacedBy(2.dp),
		verticalArrangement = Arrangement.spacedBy(2.dp),
		modifier = Modifier.fillMaxSize()
	) {
		items(
			count = photos.size,
			key = { photos[it].id }
		) { index ->
			val photo = photos[index]
			
			// Load more when near end
			if (index >= photos.size - 20) {
				LaunchedEffect(index) {
					onLoadMore()
				}
			}
			
			GooglePhotoThumbnail(
				photo = photo,
				isSelected = selectedPhotos.contains(photo.id),
				isSelectionMode = isSelectionMode,
				isStarred = starredPhotos.contains(photo.id),
				tags = photoTags[photo.id] ?: emptySet(),
				thumbnailSize = thumbnailSize,
				scaleMode = scaleMode,
				showInfoBar = showInfoBar,
				onClick = { onPhotoClick(photo, index) },
				onLongClick = { onPhotoLongClick(photo) },
				onStarClick = { onStarClick(photo) },
				getPhotoUrl = getPhotoUrl
			)
		}
	}
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GooglePhotoThumbnail(
	photo: PhotoGooglePhotos,
	isSelected: Boolean,
	isSelectionMode: Boolean,
	isStarred: Boolean,
	tags: Set<com.electricwoods.photolala.models.ColorFlag>,
	thumbnailSize: Int,
	scaleMode: String,
	showInfoBar: Boolean,
	onClick: () -> Unit,
	onLongClick: () -> Unit,
	onStarClick: () -> Unit,
	getPhotoUrl: suspend (PhotoGooglePhotos) -> String
) {
	var photoUrl by remember { mutableStateOf(photo.baseUrl) }
	
	// Refresh URL if needed
	LaunchedEffect(photo) {
		photoUrl = getPhotoUrl(photo)
	}
	
	Card(
		modifier = Modifier
			.aspectRatio(if (showInfoBar) thumbnailSize.toFloat() / (thumbnailSize + 24f) else 1f)
			.clickable { onClick() },
		shape = RoundedCornerShape(8.dp),
		colors = CardDefaults.cardColors(
			containerColor = if (isSelected && isSelectionMode) {
				MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
			} else {
				MaterialTheme.colorScheme.surface
			}
		)
	) {
		Column {
			Box(
				modifier = Modifier
					.weight(1f)
					.fillMaxWidth()
			) {
				// Photo image with size parameter for thumbnail
				val imageUrl = "$photoUrl=w$thumbnailSize-h$thumbnailSize-c"
				
				AsyncImage(
					model = ImageRequest.Builder(LocalContext.current)
						.data(imageUrl)
						.crossfade(true)
						.build(),
					contentDescription = photo.filename,
					contentScale = if (scaleMode == "fit") ContentScale.Fit else ContentScale.Crop,
					modifier = Modifier
						.fillMaxSize()
						.clip(RoundedCornerShape(8.dp))
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
				)
				
				// Online indicator
				Icon(
					imageVector = Icons.Default.Cloud,
					contentDescription = "Online photo",
					modifier = Modifier
						.align(Alignment.TopEnd)
						.padding(4.dp)
						.size(16.dp),
					tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
				)
				
				// Star and tags overlay
				if (!showInfoBar && (isStarred || tags.isNotEmpty())) {
					Row(
						modifier = Modifier
							.align(Alignment.BottomStart)
							.padding(4.dp),
						horizontalArrangement = Arrangement.spacedBy(4.dp)
					) {
						if (isStarred) {
							Icon(
								imageVector = Icons.Filled.Star,
								contentDescription = "Starred",
								modifier = Modifier
									.size(16.dp)
									.clickable { onStarClick() },
								tint = Color(0xFFFFD700)
							)
						}
						
						tags.sortedBy { it.value }.forEach { colorFlag ->
							Icon(
								imageVector = Icons.Default.Flag,
								contentDescription = "Tag ${colorFlag.value}",
								modifier = Modifier.size(12.dp),
								tint = colorFlag.getColor()
							)
						}
					}
				}
			}
			
			// Info bar
			if (showInfoBar) {
				Row(
					modifier = Modifier
						.fillMaxWidth()
						.height(24.dp)
						.padding(horizontal = 4.dp),
					horizontalArrangement = Arrangement.SpaceBetween,
					verticalAlignment = Alignment.CenterVertically
				) {
					Text(
						text = photo.displayName,
						style = MaterialTheme.typography.labelSmall,
						maxLines = 1,
						overflow = TextOverflow.Ellipsis,
						modifier = Modifier.weight(1f)
					)
				}
			}
		}
	}
}

@Composable
private fun AlbumPickerDialog(
	albums: List<com.electricwoods.photolala.services.GooglePhotosService.GooglePhotosAlbum>,
	currentAlbum: com.electricwoods.photolala.services.GooglePhotosService.GooglePhotosAlbum?,
	onAlbumSelected: (com.electricwoods.photolala.services.GooglePhotosService.GooglePhotosAlbum?) -> Unit,
	onDismiss: () -> Unit
) {
	Dialog(onDismissRequest = onDismiss) {
		Card(
			modifier = Modifier
				.fillMaxWidth()
				.fillMaxHeight(0.8f),
			shape = RoundedCornerShape(16.dp)
		) {
			Column {
				// Header
				Row(
					modifier = Modifier
						.fillMaxWidth()
						.padding(16.dp),
					horizontalArrangement = Arrangement.SpaceBetween,
					verticalAlignment = Alignment.CenterVertically
				) {
					Text(
						text = "Albums",
						style = MaterialTheme.typography.headlineSmall
					)
					IconButton(onClick = onDismiss) {
						Icon(Icons.Default.Close, contentDescription = "Close")
					}
				}
				
				Divider()
				
				// Album list
				LazyColumn(
					modifier = Modifier.fillMaxSize()
				) {
					// All Photos option
					item {
						AlbumItem(
							title = "All Photos",
							subtitle = "Show all photos in your library",
							icon = Icons.Default.Photo,
							isSelected = currentAlbum == null,
							onClick = { onAlbumSelected(null) }
						)
					}
					
					if (albums.isNotEmpty()) {
						item { Divider(modifier = Modifier.padding(vertical = 8.dp)) }
					}
					
					// Albums
					items(albums) { album ->
						AlbumItem(
							title = album.title,
							subtitle = "${album.mediaItemsCount} photos",
							icon = Icons.Default.PhotoAlbum,
							isSelected = currentAlbum?.id == album.id,
							onClick = { onAlbumSelected(album) }
						)
					}
				}
			}
		}
	}
}

@Composable
private fun AlbumItem(
	title: String,
	subtitle: String,
	icon: androidx.compose.ui.graphics.vector.ImageVector,
	isSelected: Boolean,
	onClick: () -> Unit
) {
	Surface(
		onClick = onClick,
		modifier = Modifier.fillMaxWidth()
	) {
		Row(
			modifier = Modifier
				.fillMaxWidth()
				.padding(horizontal = 16.dp, vertical = 12.dp),
			verticalAlignment = Alignment.CenterVertically
		) {
			Icon(
				imageVector = icon,
				contentDescription = null,
				modifier = Modifier.size(40.dp),
				tint = MaterialTheme.colorScheme.primary
			)
			
			Spacer(modifier = Modifier.width(16.dp))
			
			Column(modifier = Modifier.weight(1f)) {
				Text(
					text = title,
					style = MaterialTheme.typography.bodyLarge
				)
				Text(
					text = subtitle,
					style = MaterialTheme.typography.bodySmall,
					color = MaterialTheme.colorScheme.onSurfaceVariant
				)
			}
			
			if (isSelected) {
				Icon(
					imageVector = Icons.Default.Check,
					contentDescription = "Selected",
					tint = MaterialTheme.colorScheme.primary
				)
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
	onTag: () -> Unit,
	onStar: () -> Unit
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
				IconButton(onClick = onStar) {
					Icon(
						imageVector = Icons.Default.Star,
						contentDescription = "Star selected",
						tint = Color(0xFFFFD700)
					)
				}
			}
		}
	)
}

@Composable
private fun NotAuthorizedContent(error: String?) {
	Column(
		modifier = Modifier
			.fillMaxSize()
			.padding(16.dp),
		verticalArrangement = Arrangement.Center,
		horizontalAlignment = Alignment.CenterHorizontally
	) {
		Icon(
			imageVector = Icons.Default.Lock,
			contentDescription = null,
			modifier = Modifier.size(64.dp),
			tint = MaterialTheme.colorScheme.error
		)
		
		Spacer(modifier = Modifier.height(16.dp))
		
		Text(
			text = "Google Photos Access Required",
			style = MaterialTheme.typography.titleMedium
		)
		
		Spacer(modifier = Modifier.height(8.dp))
		
		Text(
			text = error ?: "Please sign in again with Google Photos permission",
			style = MaterialTheme.typography.bodyMedium,
			color = MaterialTheme.colorScheme.onSurfaceVariant
		)
	}
}

@Composable
private fun EmptyContent() {
	Column(
		modifier = Modifier
			.fillMaxSize()
			.padding(16.dp),
		verticalArrangement = Arrangement.Center,
		horizontalAlignment = Alignment.CenterHorizontally
	) {
		Icon(
			imageVector = Icons.Default.PhotoLibrary,
			contentDescription = null,
			modifier = Modifier.size(64.dp),
			tint = MaterialTheme.colorScheme.onSurfaceVariant
		)
		
		Spacer(modifier = Modifier.height(16.dp))
		
		Text(
			text = "No photos found",
			style = MaterialTheme.typography.titleMedium,
			color = MaterialTheme.colorScheme.onSurfaceVariant
		)
		
		Text(
			text = "Your Google Photos library is empty",
			style = MaterialTheme.typography.bodyMedium,
			color = MaterialTheme.colorScheme.onSurfaceVariant
		)
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
		Icon(
			imageVector = Icons.Default.Error,
			contentDescription = null,
			modifier = Modifier.size(64.dp),
			tint = MaterialTheme.colorScheme.error
		)
		
		Spacer(modifier = Modifier.height(16.dp))
		
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
		
		Spacer(modifier = Modifier.height(16.dp))
		
		Button(onClick = onRetry) {
			Text("Retry")
		}
	}
}

// Extension function to get color for ColorFlag
private fun com.electricwoods.photolala.models.ColorFlag.getColor(): Color {
	return when (this.value) {
		1 -> Color.Red
		2 -> Color(0xFFFFA500) // Orange
		3 -> Color.Yellow
		4 -> Color.Green
		5 -> Color.Blue
		6 -> Color(0xFF800080) // Purple
		7 -> Color.Gray
		else -> Color.Gray
	}
}
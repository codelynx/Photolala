package com.electricwoods.photolala.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.electricwoods.photolala.models.PhotoS3
import com.electricwoods.photolala.ui.viewmodels.CloudBrowserViewModel
import kotlinx.coroutines.launch

/**
 * Cloud Browser screen for viewing S3 photos
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CloudBrowserScreen(
    onPhotoClick: (PhotoS3, Int) -> Unit,
    onBackClick: () -> Unit,
    viewModel: CloudBrowserViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val photos by viewModel.filteredPhotos.collectAsStateWithLifecycle()
    val selectedPhotos by viewModel.selectedPhotos.collectAsStateWithLifecycle()
    val searchQuery by viewModel.searchQuery.collectAsStateWithLifecycle()
    
    Scaffold(
        topBar = {
            CloudBrowserTopBar(
                photoCount = photos.size,
                selectedCount = selectedPhotos.size,
                searchQuery = searchQuery,
                isRefreshing = uiState.isRefreshing,
                onBackClick = onBackClick,
                onSearchQueryChange = viewModel::updateSearchQuery,
                onClearSelection = viewModel::clearSelection,
                onSelectAll = viewModel::selectAll,
                onDownloadSelected = viewModel::downloadSelectedPhotos,
                onRefresh = viewModel::refresh
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                uiState.isLoading && photos.isEmpty() -> {
                    // Initial loading state
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            CircularProgressIndicator()
                            Text(
                                text = "Loading cloud photos...",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                
                uiState.error != null -> {
                    // Error state
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.CloudOff,
                                contentDescription = null,
                                modifier = Modifier.size(64.dp),
                                tint = MaterialTheme.colorScheme.error
                            )
                            Text(
                                text = uiState.error ?: "An error occurred",
                                style = MaterialTheme.typography.bodyLarge,
                                color = MaterialTheme.colorScheme.error,
                                textAlign = TextAlign.Center
                            )
                            Button(
                                onClick = { viewModel.loadPhotos() }
                            ) {
                                Text("Retry")
                            }
                        }
                    }
                }
                
                photos.isEmpty() -> {
                    // Empty state
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Cloud,
                                contentDescription = null,
                                modifier = Modifier.size(64.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = if (searchQuery.isNotEmpty()) {
                                    "No photos match your search"
                                } else {
                                    "No photos in cloud"
                                },
                                style = MaterialTheme.typography.headlineSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            if (searchQuery.isEmpty()) {
                                Text(
                                    text = "Upload photos from your local library to see them here",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    textAlign = TextAlign.Center
                                )
                            }
                        }
                    }
                }
                
                else -> {
                    // Photo grid
                    CloudPhotoGrid(
                        photos = photos,
                        selectedPhotos = selectedPhotos,
                        onPhotoClick = { photo, index ->
                            if (selectedPhotos.isNotEmpty()) {
                                viewModel.togglePhotoSelection(photo)
                            } else {
                                onPhotoClick(photo, index)
                            }
                        },
                        onPhotoLongClick = viewModel::togglePhotoSelection,
                        viewModel = viewModel
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CloudBrowserTopBar(
    photoCount: Int,
    selectedCount: Int,
    searchQuery: String,
    isRefreshing: Boolean,
    onBackClick: () -> Unit,
    onSearchQueryChange: (String) -> Unit,
    onClearSelection: () -> Unit,
    onSelectAll: () -> Unit,
    onDownloadSelected: () -> Unit,
    onRefresh: () -> Unit
) {
    var showSearch by remember { mutableStateOf(false) }
    
    TopAppBar(
        title = {
            if (showSearch) {
                TextField(
                    value = searchQuery,
                    onValueChange = onSearchQueryChange,
                    placeholder = { Text("Search photos...") },
                    singleLine = true,
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
            } else {
                Column {
                    Text(
                        text = if (selectedCount > 0) {
                            "$selectedCount selected"
                        } else {
                            "Cloud Photos"
                        }
                    )
                    if (selectedCount == 0 && photoCount > 0) {
                        Text(
                            text = "$photoCount photos",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
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
            if (selectedCount > 0) {
                IconButton(onClick = onDownloadSelected) {
                    Icon(
                        imageVector = Icons.Default.Download,
                        contentDescription = "Download selected"
                    )
                }
                IconButton(onClick = onSelectAll) {
                    Icon(
                        imageVector = Icons.Default.SelectAll,
                        contentDescription = "Select all"
                    )
                }
                IconButton(onClick = onClearSelection) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Clear selection"
                    )
                }
            } else {
                IconButton(onClick = { showSearch = !showSearch }) {
                    Icon(
                        imageVector = if (showSearch) Icons.Default.Close else Icons.Default.Search,
                        contentDescription = if (showSearch) "Close search" else "Search"
                    )
                }
                // Refresh button
                if (!isRefreshing) {
                    IconButton(onClick = onRefresh) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh"
                        )
                    }
                } else {
                    Box(
                        modifier = Modifier.size(48.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(24.dp),
                            strokeWidth = 2.dp
                        )
                    }
                }
            }
        }
    )
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun CloudPhotoGrid(
    photos: List<PhotoS3>,
    selectedPhotos: Set<PhotoS3>,
    onPhotoClick: (PhotoS3, Int) -> Unit,
    onPhotoLongClick: (PhotoS3) -> Unit,
    viewModel: CloudBrowserViewModel
) {
    val gridState = rememberLazyGridState()
    val coroutineScope = rememberCoroutineScope()
    
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 120.dp),
        state = gridState,
        contentPadding = PaddingValues(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        items(
            items = photos,
            key = { it.id }
        ) { photo ->
            val index = photos.indexOf(photo)
            CloudPhotoItem(
                photo = photo,
                isSelected = selectedPhotos.contains(photo),
                onClick = { onPhotoClick(photo, index) },
                onLongClick = { onPhotoLongClick(photo) },
                viewModel = viewModel
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun CloudPhotoItem(
    photo: PhotoS3,
    isSelected: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    viewModel: CloudBrowserViewModel
) {
    val context = LocalContext.current
    var thumbnailData by remember { mutableStateOf<ByteArray?>(null) }
    
    LaunchedEffect(photo) {
        thumbnailData = viewModel.loadThumbnail(photo)
    }
    
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .clip(RoundedCornerShape(8.dp))
            .combinedClickable(
                onClick = onClick,
                onLongClick = onLongClick
            )
    ) {
        // Photo thumbnail
        AsyncImage(
            model = ImageRequest.Builder(context)
                .data(thumbnailData)
                .crossfade(true)
                .build(),
            contentDescription = photo.filename,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )
        
        // Selection overlay
        if (isSelected) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.3f))
            )
            Icon(
                imageVector = Icons.Default.CheckCircle,
                contentDescription = "Selected",
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp)
                    .size(24.dp),
                tint = MaterialTheme.colorScheme.primary
            )
        }
        
        // Archive indicator
        if (photo.isArchived) {
            Icon(
                imageVector = Icons.Default.Archive,
                contentDescription = "Archived",
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(8.dp)
                    .size(20.dp),
                tint = Color.White
            )
        }
        
        // Filename
        Surface(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth(),
            color = Color.Black.copy(alpha = 0.6f)
        ) {
            Text(
                text = photo.filename,
                style = MaterialTheme.typography.bodySmall,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(4.dp)
            )
        }
    }
}
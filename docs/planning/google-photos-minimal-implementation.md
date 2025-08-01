# Google Photos Browser - Minimal Implementation Plan

## Overview

This document outlines the implementation plan for completing Phase 2 of the Google Photos browser on Android. The implementation will follow the patterns established by the Apple Photos browser on iOS and the local photo browser on Android, but with a minimal feature set focused on core browsing functionality.

## Design Principles

1. **Follow Existing Patterns**: Reuse architecture from Apple Photos (provider pattern) and Android local browser (UI components)
2. **Minimal Features**: Only S/M/L size options, no info bar, no stars/tags display in grid
3. **Production Ready**: Replace stub implementation with actual Google Photos API calls
4. **Performance First**: Efficient thumbnail loading and pagination
5. **Dual ID Strategy**: Use mediaItemId for browsing, compute MD5 only when starred (like Apple Photos)

## Architecture Overview

```
GooglePhotosScreen (UI)
    ↓
GooglePhotosProvider (ViewModel)
    ↓
GooglePhotosService (Interface)
    ↓
GooglePhotosServiceImpl (API Implementation)
    ↓
Google Photos Library API
```

## Implementation Details

### 1. Update GooglePhotosServiceImpl (Primary Task)

Replace the stub implementation with actual API calls:

```kotlin
@Singleton
class GooglePhotosServiceImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    private val googleSignInLegacyService: GoogleSignInLegacyService,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher
) : GooglePhotosService {
    
    private var photosLibraryClient: PhotosLibraryClient? = null
    
    private suspend fun getOrCreateClient(): PhotosLibraryClient = withContext(ioDispatcher) {
        photosLibraryClient ?: run {
            val account = googleSignInLegacyService.getLastSignedInAccount()
                ?: throw GooglePhotosException.NotSignedIn
            
            // Get OAuth2 credentials from Google Sign-In
            val credential = GoogleAccountCredential.usingOAuth2(
                context,
                listOf("https://www.googleapis.com/auth/photoslibrary.readonly")
            ).apply {
                selectedAccount = account.account
            }
            
            // Build the Photos Library client
            val settings = PhotosLibrarySettings.newBuilder()
                .setCredentialsProvider(
                    FixedCredentialsProvider.create(
                        UserCredentials.newBuilder()
                            .setAccessToken(AccessToken(account.idToken, null))
                            .build()
                    )
                )
                .build()
            
            PhotosLibraryClient.initialize(settings).also {
                photosLibraryClient = it
            }
        }
    }
    
    override suspend fun listAlbums(): Result<List<GooglePhotosAlbum>> = withContext(ioDispatcher) {
        try {
            val client = getOrCreateClient()
            val albums = mutableListOf<GooglePhotosAlbum>()
            
            // Add "All Photos" as first option
            albums.add(GooglePhotosAlbum(
                id = "",
                title = "All Photos",
                coverPhotoUrl = null,
                mediaItemsCount = -1,
                isWriteable = false
            ))
            
            // Fetch albums from API
            val request = ListAlbumsRequest.newBuilder()
                .setPageSize(50)
                .build()
            
            client.listAlbums(request).iterateAll().forEach { album ->
                albums.add(GooglePhotosAlbum(
                    id = album.id,
                    title = album.title,
                    coverPhotoUrl = album.coverPhotoBaseUrl,
                    mediaItemsCount = album.mediaItemsCount?.toInt() ?: 0,
                    isWriteable = album.isWriteable
                ))
            }
            
            Result.success(albums)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to list albums", e)
            Result.failure(e)
        }
    }
    
    override suspend fun listPhotos(
        albumId: String?,
        pageToken: String?,
        pageSize: Int
    ): Result<PhotosPage> = withContext(ioDispatcher) {
        try {
            val client = getOrCreateClient()
            
            val response = if (albumId.isNullOrEmpty()) {
                // List all photos
                val request = ListMediaItemsRequest.newBuilder()
                    .setPageSize(pageSize)
                    .setPageToken(pageToken ?: "")
                    .build()
                client.listMediaItems(request)
            } else {
                // List photos in specific album
                val request = SearchMediaItemsRequest.newBuilder()
                    .setAlbumId(albumId)
                    .setPageSize(pageSize)
                    .setPageToken(pageToken ?: "")
                    .build()
                client.searchMediaItems(request)
            }
            
            val photos = response.mediaItemsList.map { mediaItem ->
                PhotoGooglePhotos(
                    mediaItemId = mediaItem.id,
                    filename = mediaItem.filename,
                    fileSize = null, // Not provided by API
                    width = mediaItem.mediaMetadata?.width?.toInt(),
                    height = mediaItem.mediaMetadata?.height?.toInt(),
                    creationDate = mediaItem.mediaMetadata?.creationTime?.let {
                        Date(it.seconds * 1000)
                    },
                    modificationDate = null,
                    baseUrl = mediaItem.baseUrl,
                    productUrl = mediaItem.productUrl,
                    mimeType = mediaItem.mimeType
                )
            }
            
            Result.success(PhotosPage(
                photos = photos,
                nextPageToken = response.nextPageToken.takeIf { it.isNotEmpty() }
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to list photos", e)
            Result.failure(e)
        }
    }
}
```

### 2. Handle OAuth2 Token Management

Since Google Sign-In SDK doesn't directly provide OAuth2 tokens for Google Photos API:

```kotlin
// Add to GoogleSignInLegacyService
suspend fun getAccessToken(): String? = withContext(Dispatchers.IO) {
    val account = getLastSignedInAccount() ?: return@withContext null
    
    try {
        // Request fresh token
        val scope = "oauth2:https://www.googleapis.com/auth/photoslibrary.readonly"
        GoogleAuthUtil.getToken(context, account.account, scope)
    } catch (e: Exception) {
        Log.e(TAG, "Failed to get access token", e)
        null
    }
}
```

### 3. Simplify UI - Remove Unnecessary Features

Update GooglePhotosScreen to remove info bar and tag/star displays:

```kotlin
@Composable
private fun GooglePhotosGrid(
    photos: List<PhotoGooglePhotos>,
    thumbnailSize: Int,
    scaleMode: String,
    onPhotoClick: (PhotoGooglePhotos, Int) -> Unit,
    onLoadMore: () -> Unit,
    modifier: Modifier = Modifier
) {
    val columns = remember(thumbnailSize) {
        when (thumbnailSize) {
            128 -> 3  // Small
            256 -> 2  // Medium
            512 -> 1  // Large
            else -> 2
        }
    }
    
    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        modifier = modifier,
        contentPadding = PaddingValues(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        itemsIndexed(
            items = photos,
            key = { _, photo -> photo.id }
        ) { index, photo ->
            GooglePhotoCell(
                photo = photo,
                size = thumbnailSize.dp,
                scaleMode = scaleMode,
                onClick = { onPhotoClick(photo, index) }
            )
            
            // Load more when near end
            if (index >= photos.size - 10) {
                LaunchedEffect(index) {
                    onLoadMore()
                }
            }
        }
    }
}

@Composable
private fun GooglePhotoCell(
    photo: PhotoGooglePhotos,
    size: Dp,
    scaleMode: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .size(size)
            .clickable { onClick() },
        shape = RoundedCornerShape(8.dp)
    ) {
        // Google Photos provides server-side thumbnails via URL parameters
        val thumbnailUrl = when (scaleMode) {
            "fit" -> "${photo.baseUrl}=w${size.value.toInt()}-h${size.value.toInt()}"
            else -> "${photo.baseUrl}=w${size.value.toInt()}-h${size.value.toInt()}-c"
        }
        
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(thumbnailUrl)
                .crossfade(true)
                .memoryCachePolicy(CachePolicy.ENABLED)
                .diskCachePolicy(CachePolicy.ENABLED)
                .build(),
            contentDescription = photo.filename,
            contentScale = if (scaleMode == "fit") ContentScale.Fit else ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )
    }
}
```

### 4. Simplify Toolbar - Only Size Options

```kotlin
@Composable
private fun GooglePhotosToolbar(
    onAlbumClick: () -> Unit,
    onRefresh: () -> Unit,
    thumbnailSize: Int,
    onThumbnailSizeChange: (Int) -> Unit,
    isLoading: Boolean
) {
    TopAppBar(
        title = { Text("Google Photos") },
        actions = {
            // Album picker
            IconButton(onClick = onAlbumClick) {
                Icon(Icons.Default.PhotoAlbum, "Albums")
            }
            
            // Size picker
            Box {
                var expanded by remember { mutableStateOf(false) }
                
                IconButton(onClick = { expanded = true }) {
                    Icon(Icons.Default.PhotoSizeSelectLarge, "Size")
                }
                
                DropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Small") },
                        onClick = {
                            onThumbnailSizeChange(128)
                            expanded = false
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Medium") },
                        onClick = {
                            onThumbnailSizeChange(256)
                            expanded = false
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Large") },
                        onClick = {
                            onThumbnailSizeChange(512)
                            expanded = false
                        }
                    )
                }
            }
            
            // Refresh
            IconButton(
                onClick = onRefresh,
                enabled = !isLoading
            ) {
                Icon(Icons.Default.Refresh, "Refresh")
            }
        }
    )
}
```

### 5. Handle URL Expiration

Google Photos URLs expire after ~60 minutes. Implement URL refresh in the provider:

```kotlin
// In GooglePhotosProvider
private val urlExpirationTime = 55 * 60 * 1000L // 55 minutes

fun getPhotoUrl(photo: PhotoGooglePhotos): String {
    val cached = urlCache[photo.id]
    val now = System.currentTimeMillis()
    
    // Check if URL is still valid
    if (cached != null && (now - cached.second) < urlExpirationTime) {
        return cached.first
    }
    
    // Return base URL with size parameters
    // The view will handle loading, and if it fails, trigger a refresh
    return "${photo.baseUrl}=w512-h512-c"
}
```

### 6. Implement MD5 Strategy for Starred Photos

Following the Apple Photos pattern, compute MD5 only when photos are starred:

```kotlin
// In GooglePhotosService
override suspend fun downloadPhotoData(photo: PhotoGooglePhotos): Result<ByteArray> = withContext(ioDispatcher) {
    try {
        // Use the baseUrl with =d parameter to get original file
        // This downloads the exact original file as uploaded by user
        val downloadUrl = "${photo.baseUrl}=d"
        
        // Download the original photo data
        val url = URL(downloadUrl)
        val connection = url.openConnection() as HttpURLConnection
        connection.connectTimeout = 30000
        connection.readTimeout = 30000
        
        val data = connection.inputStream.use { it.readBytes() }
        Log.d(TAG, "Downloaded original: ${data.size} bytes")
        Result.success(data)
    } catch (e: Exception) {
        Log.e(TAG, "Failed to download photo data", e)
        Result.failure(e)
    }
}

// In GooglePhotosProvider or BackupManager
suspend fun starGooglePhoto(photo: PhotoGooglePhotos) {
    // Download original data
    val result = googlePhotosService.downloadPhotoData(photo)
    
    result.onSuccess { data ->
        // Compute MD5
        val md5 = MessageDigest.getInstance("MD5")
            .digest(data)
            .joinToString("") { "%02x".format(it) }
        
        // Store mapping: mediaItemId → MD5
        photoRepository.saveMD5Mapping(photo.mediaItemId, md5)
        
        // Add to backup queue with MD5
        backupQueueManager.addPhoto(
            photoId = photo.id,
            md5 = md5,
            data = data
        )
    }
}
```

This approach ensures:
- Fast browsing using mediaItemId (no download needed)
- MD5 computed only when necessary (starring)
- Cross-source deduplication works for backed-up photos
- Consistent with Apple Photos implementation

### 7. Persistent MD5 Mapping Storage

Store the mediaItemId → MD5 mapping for future use:

```kotlin
// Database entity
@Entity(tableName = "google_photos_md5")
data class GooglePhotoMD5(
    @PrimaryKey
    val mediaItemId: String,
    val md5: String,
    val computedAt: Long = System.currentTimeMillis()
)

// Repository method
suspend fun getOrComputeMD5(photo: PhotoGooglePhotos): String? {
    // Check if we already have MD5
    val existing = googlePhotoMD5Dao.getMD5(photo.mediaItemId)
    if (existing != null) return existing.md5
    
    // Only compute if photo is being starred
    return null  // Let starring process compute it
}

// Future benefit: Show tags for previously starred photos
suspend fun getTagsForGooglePhoto(photo: PhotoGooglePhotos): List<Tag> {
    val md5 = googlePhotoMD5Dao.getMD5(photo.mediaItemId)?.md5
    return if (md5 != null) {
        tagRepository.getTagsByMD5(md5)
    } else {
        emptyList()  // No tags until starred
    }
}
```

Benefits:
- Incremental feature rollout (tags appear as photos are starred)
- No redundant MD5 computation
- Foundation for v2 cross-source features
- Maintains data even if photo is unstarred

### 8. Future Enhancement: Opportunistic MD5 Computation

When implementing features that require downloading originals:

```kotlin
// Example: Full-screen photo viewer
class PhotoViewerViewModel {
    suspend fun loadFullResolution(photo: PhotoGooglePhotos) {
        // Download original for display
        val result = googlePhotosService.downloadPhotoData(photo)
        
        result.onSuccess { data ->
            // Display the full resolution image
            _fullResImage.value = BitmapFactory.decodeByteArray(data, 0, data.size)
            
            // Opportunistically compute MD5 while we have the data
            computeAndStoreMD5InBackground(photo, data)
        }
    }
    
    private fun computeAndStoreMD5InBackground(photo: PhotoGooglePhotos, data: ByteArray) {
        viewModelScope.launch(Dispatchers.Default) {
            // Check if we already have MD5
            if (photoRepository.getGooglePhotoMD5(photo.mediaItemId) == null) {
                val md5 = MessageDigest.getInstance("MD5")
                    .digest(data)
                    .joinToString("") { "%02x".format(it) }
                
                // Store for future use
                photoRepository.saveGooglePhotoMD5(photo.mediaItemId, md5)
                
                // Now this photo can show tags!
                Log.d(TAG, "Opportunistically computed MD5 for ${photo.filename}")
            }
        }
    }
}

// Example: Slideshow feature
suspend fun runSlideshow(photos: List<PhotoGooglePhotos>) {
    photos.forEach { photo ->
        // Download for slideshow display
        val data = downloadPhotoData(photo)
        displaySlide(data)
        
        // Compute MD5 in parallel
        launch { computeAndStoreMD5(photo, data) }
        
        delay(3000) // Next slide
    }
}
```

This approach:
- Gradually builds MD5 mappings as users interact with photos
- No extra downloads (reuses data already fetched)
- Tags become visible over time
- Zero performance impact on browsing
- Natural progression of feature availability

## API Dependencies

The current Gradle setup already includes:
```kotlin
implementation("com.google.photos.library:google-photos-library-client:1.7.3")
implementation("com.google.auth:google-auth-library-oauth2-http:1.19.0")
```

## Testing Plan

1. **Authorization Flow**
   - Test initial authorization
   - Test scope already granted scenario
   - Test token refresh

2. **Album Browsing**
   - Load album list
   - Switch between albums
   - Handle empty albums

3. **Photo Loading**
   - Initial page load
   - Pagination
   - URL expiration and refresh

4. **UI Responsiveness**
   - Size changes
   - Orientation changes
   - Error states

## Implementation Timeline

1. **Day 1**: OAuth2 token management and client initialization
2. **Day 2**: Implement listAlbums and listPhotos with real API
3. **Day 3**: Simplify UI, remove unnecessary features
4. **Day 4**: Handle URL expiration and error cases
5. **Day 5**: Testing and polish

## Benefits of This Approach

1. **Reuses Existing Patterns**: Follows established architecture
2. **Minimal Complexity**: No unnecessary features
3. **Production Ready**: Real API implementation
4. **Performance Focused**: Efficient loading and caching
5. **User Friendly**: Simple, clean interface

## Next Steps

1. Start with OAuth2 token management
2. Implement API client initialization
3. Replace stub methods one by one
4. Test with real Google Photos account
5. Handle edge cases and errors
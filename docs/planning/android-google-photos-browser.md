# Android Google Photos Browser Feature

## Overview

This document outlines the implementation plan for adding Google Photos Library browsing capability to Photolala on Android, similar to the Apple Photos Library browser on iOS.

## Background

- iOS has Apple Photos Library browser accessible via Window → Apple Photos Library (⌘⌥L)
- Android users primarily use Google Photos for cloud photo storage
- This feature would provide parity between platforms

## Technical Feasibility

### Google Photos API Options

1. **Google Photos Library API**
   - Official REST API for accessing Google Photos
   - Requires OAuth 2.0 authentication
   - Provides access to photos, albums, and sharing features
   - Rate limits: 10,000 requests per day
   - Scopes needed: `https://www.googleapis.com/auth/photoslibrary.readonly`

2. **Limitations**
   - No direct file access (photos accessed via URLs)
   - Photos URLs are temporary (expire after ~60 minutes)
   - Cannot access original file metadata like EXIF directly
   - Requires internet connection

### Authentication

Since we already have Google Sign-In implemented:
- Can request additional scope for Photos access
- Use existing `GoogleSignInManager` infrastructure
- Store refresh token for background access

## Proposed Implementation

Based on the iOS Apple Photos implementation, here's the Android approach:

### 1. Add Google Photos Permission Scope

```kotlin
// In GoogleSignInManager.kt
private val GOOGLE_PHOTOS_SCOPE = Scope("https://www.googleapis.com/auth/photoslibrary.readonly")

fun signIn() {
    val signInOptions = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
        .requestIdToken(serverClientId)
        .requestEmail()
        .requestScopes(GOOGLE_PHOTOS_SCOPE) // Add this
        .build()
}
```

### 2. Create GooglePhotosProvider (Similar to ApplePhotosProvider)

```kotlin
@HiltViewModel
class GooglePhotosProvider @Inject constructor(
    private val googlePhotosService: GooglePhotosService,
    private val photoRepository: PhotoRepository,
    private val photoTagRepository: PhotoTagRepository,
    private val preferencesManager: PreferencesManager
) : ViewModel() {
    
    private val _photos = MutableStateFlow<List<PhotoGooglePhotos>>(emptyList())
    val photos: StateFlow<List<PhotoGooglePhotos>> = _photos.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _currentAlbum = MutableStateFlow<GooglePhotosAlbum?>(null)
    val currentAlbum: StateFlow<GooglePhotosAlbum?> = _currentAlbum.asStateFlow()
    
    private val _albums = MutableStateFlow<List<GooglePhotosAlbum>>(emptyList())
    val albums: StateFlow<List<GooglePhotosAlbum>> = _albums.asStateFlow()
    
    val displayTitle: String 
        get() = _currentAlbum.value?.title ?: "All Photos"
    
    val displaySubtitle: String
        get() = "${_photos.value.size} photos"
    
    suspend fun loadPhotos() {
        _isLoading.value = true
        try {
            val albumId = _currentAlbum.value?.id
            val photos = googlePhotosService.listPhotos(albumId)
                .map { PhotoGooglePhotos.fromMediaItem(it) }
            _photos.value = photos
        } finally {
            _isLoading.value = false
        }
    }
    
    suspend fun loadAlbums() {
        val albums = googlePhotosService.listAlbums()
        _albums.value = albums
    }
    
    fun selectAlbum(album: GooglePhotosAlbum?) {
        _currentAlbum.value = album
        viewModelScope.launch {
            loadPhotos()
        }
    }
}
```

### 3. Create Google Photos Service Implementation

```kotlin
@Singleton
class GooglePhotosServiceImpl @Inject constructor(
    private val context: Context,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher
) : GooglePhotosService {
    
    private var photosLibraryClient: PhotosLibraryClient? = null
    
    override suspend fun listAlbums(): List<GooglePhotosAlbum> = withContext(ioDispatcher) {
        val client = getOrCreateClient()
        val albums = mutableListOf<GooglePhotosAlbum>()
        
        // Add "All Photos" as default
        // Fetch actual albums from API
        val response = client.listAlbums()
        
        response.iterateAll().forEach { album ->
            albums.add(GooglePhotosAlbum(
                id = album.id,
                title = album.title,
                coverPhotoUrl = album.coverPhotoBaseUrl,
                mediaItemsCount = album.mediaItemsCount?.toInt() ?: 0
            ))
        }
        
        albums
    }
    
    override suspend fun listPhotos(
        albumId: String?, 
        pageToken: String?
    ): List<MediaItem> = withContext(ioDispatcher) {
        val client = getOrCreateClient()
        
        val request = if (albumId != null) {
            SearchMediaItemsRequest.newBuilder()
                .setAlbumId(albumId)
                .setPageSize(100)
                .setPageToken(pageToken ?: "")
                .build()
        } else {
            ListMediaItemsRequest.newBuilder()
                .setPageSize(100)
                .setPageToken(pageToken ?: "")
                .build()
        }
        
        val response = if (albumId != null) {
            client.searchMediaItems(request)
        } else {
            client.listMediaItems(request)
        }
        
        response.mediaItemsList
    }
}
```

### 4. Update PhotoGooglePhotos Model (Similar to PhotoApple)

```kotlin
// Similar to PhotoMediaStore and PhotoS3
data class PhotoGooglePhotos(
    override val id: String, // "ggp#" + mediaItemId
    val mediaItemId: String, // Stable Google Photos ID
    override val filename: String,
    override val fileSize: Long?, // Not available from API
    override val width: Int?,
    override val height: Int?,
    override val creationDate: Date?,
    override val modificationDate: Date?,
    val baseUrl: String, // Temporary URL (expires ~60 min)
    val productUrl: String, // Permanent link to Google Photos
    override val mimeType: String?,
    // Additional metadata for identification
    val pseudoHash: String? = null, // Generated from metadata combination
    val cameraMake: String? = null,
    val cameraModel: String? = null
) : Photo {
    override val displayName: String get() = filename
    
    // Generate stable identifier for cross-source matching
    fun generatePseudoHash(): String {
        return listOf(
            filename,
            creationDate?.time?.toString() ?: "",
            width?.toString() ?: "",
            height?.toString() ?: "",
            cameraMake ?: "",
            cameraModel ?: ""
        ).joinToString("|").toMD5()
    }
}
```

### 5. Create GooglePhotosScreen (Similar to ApplePhotosBrowserView)

```kotlin
@Composable
fun GooglePhotosScreen(
    modifier: Modifier = Modifier,
    viewModel: GooglePhotosProvider = hiltViewModel(),
    onPhotoClick: (PhotoGooglePhotos, Int) -> Unit = { _, _ -> },
    onBackClick: (() -> Unit)? = null
) {
    val photos by viewModel.photos.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val currentAlbum by viewModel.currentAlbum.collectAsState()
    val albums by viewModel.albums.collectAsState()
    
    var showAlbumPicker by remember { mutableStateOf(false) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(viewModel.displayTitle) },
                subtitle = { Text(viewModel.displaySubtitle) },
                navigationIcon = {
                    if (onBackClick != null) {
                        IconButton(onClick = onBackClick) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                        }
                    }
                },
                actions = {
                    IconButton(onClick = { showAlbumPicker = true }) {
                        Icon(Icons.Default.PhotoAlbum, "Albums")
                    }
                    IconButton(
                        onClick = { viewModel.refresh() },
                        enabled = !isLoading
                    ) {
                        Icon(Icons.Default.Refresh, "Refresh")
                    }
                }
            )
        }
    ) { paddingValues ->
        // Reuse existing PhotoGrid component
        GooglePhotosGrid(
            photos = photos,
            modifier = Modifier.padding(paddingValues),
            onPhotoClick = onPhotoClick
        )
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
    
    // Initial load
    LaunchedEffect(Unit) {
        viewModel.checkAuthorization()
        viewModel.loadAlbums()
        viewModel.loadPhotos()
    }
}
```

### 6. Navigation Integration

```kotlin
// Add to PhotolalaNavigation
composable(Screen.GooglePhotos.route) {
    GooglePhotosScreen(
        onBackClick = { navController.popBackStack() },
        onPhotoClick = { photo, index ->
            // Navigate to detail view
        }
    )
}

// Add menu item similar to iOS
when (currentScreen) {
    Screen.Welcome -> {
        // Add Google Photos option
        Button(
            onClick = { navController.navigate(Screen.GooglePhotos.route) }
        ) {
            Icon(Icons.Default.PhotoLibrary, contentDescription = null)
            Text("Google Photos Library")
        }
    }
}

## Challenges & Solutions

### 1. Temporary URLs
- **Challenge**: Photo URLs expire after ~60 minutes
- **Solution**: 
  - Cache URLs with timestamp
  - Refresh expired URLs on demand
  - Show loading state during refresh

### 2. No MD5 Hash
- **Challenge**: Cannot calculate MD5 for deduplication
- **Solution**:
  - Use Google Photos mediaItemId as unique identifier
  - Cannot participate in cross-source deduplication
  - Tags stored by mediaItemId

**Alternative Identifiers Available**:

1. **mediaItem.id** (Primary identifier)
   - Permanent, unique ID assigned by Google Photos
   - Stable across sessions and devices
   - Format: Long alphanumeric string (e.g., "AGj1epU9...")
   - ✅ Best option for persistent identification

2. **mediaItem.productUrl**
   - Permanent URL to view photo in Google Photos web
   - Format: `https://photos.google.com/lr/photo/{photoId}`
   - Stable and shareable
   - Can extract photoId portion as additional identifier

3. **Combination Approach for Pseudo-Hash**:
   ```kotlin
   // Create a stable identifier combining multiple fields
   fun generateStableId(item: MediaItem): String {
       val components = listOf(
           item.filename,
           item.mediaMetadata.creationTime,
           item.mediaMetadata.width.toString(),
           item.mediaMetadata.height.toString()
       )
       return components.joinToString("|").toMD5()
   }
   ```

4. **Metadata-based Matching**:
   - filename + creationTime + dimensions
   - Not guaranteed unique but highly probable
   - Can help with cross-source matching

5. **Google Photos Specific Metadata**:
   ```json
   {
     "id": "AGj1epU9...",  // Stable ID
     "productUrl": "https://photos.google.com/lr/photo/AGj1epU9",
     "filename": "IMG_1234.jpg",
     "mediaMetadata": {
       "creationTime": "2023-07-20T10:15:30Z",
       "width": "4032",
       "height": "3024",
       "photo": {
         "cameraMake": "Apple",
         "cameraModel": "iPhone 13",
         "focalLength": 5.1,
         "apertureFNumber": 1.6,
         "isoEquivalent": 50
       }
     }
   }
   ```

### 3. Performance
- **Challenge**: API calls required for each page of photos
- **Solution**:
  - Implement aggressive caching
  - Preload next page
  - Show cached data while refreshing

### 4. Offline Access
- **Challenge**: Requires internet connection
- **Solution**:
  - Show offline message
  - Option to download photos for offline viewing
  - Cache thumbnails locally

## Key Implementation Details (Based on iOS Pattern)

### 1. Architecture Alignment
- **Provider Pattern**: GooglePhotosProvider mirrors ApplePhotosProvider
- **ViewModel Integration**: Uses Hilt injection like other Android screens
- **Photo Model**: PhotoGooglePhotos implements Photo interface
- **Stable ID**: Use mediaItem.id as primary identifier (like PHAsset.localIdentifier)

### 2. Permission Handling
```kotlin
// Similar to iOS PHPhotoLibrary authorization
suspend fun checkAuthorization(): Boolean {
    val account = GoogleSignIn.getLastSignedInAccount(context)
    return account?.grantedScopes?.contains(GOOGLE_PHOTOS_SCOPE) ?: false
}

suspend fun requestAuthorization() {
    if (!checkAuthorization()) {
        // Trigger re-authentication with Photos scope
        googleSignInManager.signInWithAdditionalScope(GOOGLE_PHOTOS_SCOPE)
    }
}
```

### 3. Caching Strategy
- Cache mediaItem metadata locally
- Store URL with expiration timestamp
- Refresh URLs proactively before display
- Use Coil for image loading with custom fetcher

### 4. Tag Support
```kotlin
// Tags stored by mediaItem.id
suspend fun getTagsForGooglePhoto(mediaItemId: String): Set<ColorFlag> {
    return photoTagRepository.getTagsForPhoto("ggp#$mediaItemId")
}
```

## Implementation Phases

### Phase 1: Basic Integration (MVP)
- [x] Planning document
- [ ] Add Google Photos scope to sign-in
- [ ] Create GooglePhotosService interface
- [ ] Implement PhotoGooglePhotos model
- [ ] Create GooglePhotosProvider ViewModel
- [ ] Build GooglePhotosScreen UI
- [ ] Add navigation integration

### Phase 2: Core Features
- [ ] Album browsing with picker
- [ ] Pagination support
- [ ] URL refresh mechanism
- [ ] Error handling for expired tokens
- [ ] Loading states and placeholders

### Phase 3: Advanced Features
- [ ] Search functionality
- [ ] Download to local storage
- [ ] Tag synchronization
- [ ] Thumbnail caching
- [ ] Batch operations

## Benefits

1. **Feature Parity**: Matches iOS Apple Photos Library feature
2. **User Convenience**: Access photos without manual download
3. **Storage Saving**: View photos without using device storage
4. **Seamless Integration**: Uses existing Google Sign-In

## Considerations

1. **API Quotas**: Need to implement rate limiting
2. **Privacy**: Only read-only access requested
3. **Performance**: Network-dependent performance
4. **Cost**: API usage within free tier for most users

## Alternative Approaches

1. **Content Provider Access** (Not recommended)
   - Google Photos doesn't expose a content provider
   - Would require unofficial methods

2. **Screen Scraping** (Not recommended)
   - Violates terms of service
   - Unreliable and fragile

3. **Google Drive API** (Limited)
   - Only shows photos manually uploaded to Drive
   - Doesn't include Google Photos automatic uploads

## Conclusion

Implementing Google Photos browser is technically feasible using the official API. While there are limitations compared to local photo access, it would provide valuable functionality for Android users and maintain feature parity with iOS.

## Next Steps

1. Prototype API integration
2. Test performance with large libraries
3. Design UI mockups
4. Implement Phase 1 MVP
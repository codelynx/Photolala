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

### 2. MD5 Hash Strategy (Similar to Apple Photos)
- **Browsing Phase**: Use mediaItemId as unique identifier (like Apple Photo ID)
  - Fast browsing without downloading original data
  - Thumbnails cached by mediaItemId
  - Tags/selections tracked by mediaItemId
  
- **Star/Backup Phase**: Download original and compute MD5
  - When user stars a photo, download full data
  - Compute MD5 hash for cross-source deduplication
  - Upload to S3 with MD5-based naming
  - Maintain mediaItemId → MD5 mapping for future reference

- **Implementation Pattern**:
  ```kotlin
  // Browsing: Use mediaItemId
  PhotoGooglePhotos(
      id = "ggp#$mediaItemId",  // For UI/browsing
      mediaItemId = mediaItemId,
      baseUrl = baseUrl         // Temporary thumbnail URL
  )
  
  // Starring: Download and compute MD5
  suspend fun starGooglePhoto(photo: PhotoGooglePhotos) {
      val originalData = downloadPhotoData(photo)
      val md5 = computeMD5(originalData)
      
      // Save mediaItemId → MD5 mapping persistently
      photoRepository.saveGooglePhotoMD5(mediaItemId, md5)
      
      // Upload with MD5-based naming
      s3Service.uploadPhoto(md5, originalData)
  }
  ```

- **Future Benefits of Storing MD5 Mapping**:
  - Can show MD5-based tags for previously starred photos
  - Enables incremental tag sync (starred photos first)
  - Avoids recomputing MD5 if photo is unstarred/restarred
  - Foundation for v2 features (cross-source tag display)
  - Could pre-compute MD5s in background for frequently viewed photos
  
- **Opportunistic MD5 Computation** (Future):
  ```kotlin
  // During slideshow or full-screen viewing
  suspend fun displayFullPhoto(photo: PhotoGooglePhotos) {
      // Download original for display
      val originalData = downloadPhotoData(photo)
      
      // Display the photo
      showFullScreenImage(originalData)
      
      // Opportunistically compute and cache MD5
      if (!hasStoredMD5(photo.mediaItemId)) {
          val md5 = computeMD5(originalData)
          photoRepository.saveGooglePhotoMD5(photo.mediaItemId, md5)
          // Now tags can be displayed for this photo
      }
  }
  ```

**Other Available Identifiers** (summary):
- `mediaItem.productUrl` - Permanent web URL
- `filename + creationTime + dimensions` - Metadata combination
- Camera EXIF data - Additional matching hints

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

### 3. Thumbnail Strategy

Google Photos provides server-side thumbnail generation via URL parameters:

```kotlin
// Base URL from API: https://lh3.googleusercontent.com/...
val baseUrl = mediaItem.baseUrl

// Thumbnail sizes (server-generated, no download needed)
val thumbnail128 = "$baseUrl=w128-h128-c"   // 128x128 cropped
val thumbnail256 = "$baseUrl=w256-h256-c"   // 256x256 cropped
val thumbnail512 = "$baseUrl=w512-h512-c"   // 512x512 cropped

// Other options:
val fitImage = "$baseUrl=w512-h512"         // Fit within bounds
val widthOnly = "$baseUrl=w512"             // Constrain width only
val original = "$baseUrl=d"                 // Download original (full resolution)

// Smart crop with face detection
val smartCrop = "$baseUrl=w256-h256-c-pp"   // Portrait preference

// For MD5 computation - use the =d parameter
val downloadUrl = "$baseUrl=d"              // Gets original file exactly as uploaded
```

Benefits:
- No need to download full images for browsing
- Server-side processing (fast)
- Multiple sizes available instantly
- Face-aware cropping available
- Bandwidth efficient

Caching:
- Cache URLs with expiration timestamp
- Coil handles image caching automatically
- Refresh URLs when expired (55 minutes)

### 4. Tag Support (Progressive Enhancement)

Phase 1 (Current):
- Tags stored by MD5 (for cross-source consistency)
- Google Photos can only show tags after starring (MD5 computed)
- Acceptable limitation for v1

Phase 2 (Future):
- Background MD5 computation for viewed photos
- Gradual tag visibility improvement
- Optional user-triggered "sync tags" for albums

```kotlin
// Tags retrieved via MD5 (if available)
suspend fun getTagsForGooglePhoto(photo: PhotoGooglePhotos): Set<ColorFlag> {
    val md5 = photoRepository.getGooglePhotoMD5(photo.mediaItemId)
    return if (md5 != null) {
        photoTagRepository.getTagsForPhoto("md5#$md5")
    } else {
        emptySet()  // No tags until MD5 computed
    }
}
```

## Implementation Phases

### Phase 1: Basic Integration (MVP) ✅ COMPLETED
- [x] Planning document
- [x] Add Google Photos scope to sign-in
- [x] Create GooglePhotosService interface
- [x] Implement PhotoGooglePhotos model
- [x] Create GooglePhotosProvider ViewModel
- [x] Build GooglePhotosScreen UI
- [x] Add navigation integration

### Phase 2: Core Features 🚧 IN PROGRESS
- [ ] Actual Google Photos API implementation (currently stub)
- [ ] Album browsing with picker
- [ ] Pagination support
- [ ] URL refresh mechanism
- [ ] Error handling for expired tokens
- [ ] Loading states and placeholders

### Phase 3: Advanced Features ❌ NOT STARTED
- [ ] Search functionality
- [ ] Download to local storage
- [ ] Tag synchronization
- [ ] Thumbnail caching
- [ ] Batch operations

## Implementation Status (January 31, 2025)

### Completed Items:
1. **OAuth Configuration**:
   - Created new Google Cloud project: `photolala-android`
   - Set up OAuth 2.0 clients (Android + Web)
   - Configured debug/release build variants
   - Added Google Photos scope to sign-in flow

2. **Code Implementation**:
   - `GooglePhotosService.kt` - Service interface
   - `GooglePhotosServiceImpl.kt` - Stub implementation
   - `PhotoGooglePhotos.kt` - Photo model with stable IDs
   - `GooglePhotosProvider.kt` - ViewModel
   - `GooglePhotosScreen.kt` - UI implementation
   - Updated `GoogleSignInLegacyService.kt` with Photos scope

3. **Navigation Integration**:
   - Added to WelcomeScreen menu
   - Integrated with PhotolalaNavigation
   - Back navigation support

### Current State:
- ✅ OAuth authentication working
- ✅ Google Photos permission granted
- ✅ UI and navigation functional
- ⚠️ Stub implementation returns empty results
- ❌ Actual API calls not implemented

### Next Steps:
1. Implement actual Google Photos Library API calls
2. Handle OAuth2 credentials from Google Sign-In
3. Add pagination and URL refresh logic
4. Implement album browsing

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
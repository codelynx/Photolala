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

### 2. Create Google Photos Service

```kotlin
interface GooglePhotosService {
    suspend fun listAlbums(): Flow<List<GooglePhotosAlbum>>
    suspend fun listPhotos(albumId: String? = null, pageToken: String? = null): GooglePhotosPage
    suspend fun getPhoto(mediaItemId: String): GooglePhotosItem?
    suspend fun searchPhotos(filters: SearchFilters): Flow<List<GooglePhotosItem>>
}

data class GooglePhotosAlbum(
    val id: String,
    val title: String,
    val coverPhotoUrl: String?,
    val mediaItemsCount: Int
)

data class GooglePhotosItem(
    val id: String,
    val filename: String,
    val mimeType: String,
    val creationTime: Date,
    val width: Int,
    val height: Int,
    val baseUrl: String // Temporary URL
)
```

### 3. Create PhotoGooglePhotos Model

```kotlin
// Similar to PhotoMediaStore and PhotoS3
data class PhotoGooglePhotos(
    override val id: String, // "ggp#" + mediaItemId
    val mediaItemId: String,
    override val filename: String,
    override val fileSize: Long?, // Not available from API
    override val width: Int?,
    override val height: Int?,
    override val creationDate: Date?,
    override val modificationDate: Date?,
    val baseUrl: String, // Temporary URL
    val productUrl: String, // Permanent link to Google Photos
    override val mimeType: String?
) : Photo {
    override val displayName: String get() = filename
}
```

### 4. Navigation Integration

```kotlin
// Add to PhotolalaNavigation
NavigationDrawerItem(
    icon = { Icon(Icons.Default.PhotoLibrary, contentDescription = null) },
    label = { Text("Google Photos Library") },
    selected = currentScreen == Screen.GooglePhotos,
    onClick = {
        navController.navigate(Screen.GooglePhotos.route)
        closeDrawer()
    }
)
```

### 5. UI Implementation

Create `GooglePhotosScreen` similar to `PhotoGridScreen` but with:
- Album selection dropdown/tabs
- Online-only indicator
- Refresh button for expired URLs
- Download option to save locally

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

## Implementation Phases

### Phase 1: Basic Integration (MVP)
- Google Photos authentication scope
- List photos from main library
- Basic grid view with thumbnails
- Navigation integration

### Phase 2: Albums & Search
- Album browsing
- Date-based filtering
- Basic search functionality

### Phase 3: Advanced Features
- Download to local storage
- Batch operations
- Integration with backup queue
- Cached thumbnails

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
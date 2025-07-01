# Android Photo Browser Architecture Research

## Overview

This document researches best practices and architectural patterns for building photo browser applications on Android, examining popular apps and libraries to inform Photolala's Android implementation.

## Popular Android Photo Apps Architecture

### Google Photos
- **Architecture**: MVVM with Repository pattern
- **Image Loading**: Custom image loader with aggressive caching
- **Grid**: RecyclerView with custom LayoutManager
- **Key Features**: 
  - Infinite scrolling with pagination
  - Smart grouping by date/location
  - Seamless cloud/local integration
  - ML-powered search

### Gallery Apps (Samsung Gallery, OnePlus Gallery)
- **Architecture**: MVI (Model-View-Intent)
- **Image Loading**: Glide with custom modules
- **Grid**: RecyclerView with GridLayoutManager
- **Key Features**:
  - Fast local media scanning
  - Album organization
  - Built-in editor integration
  - Story/highlight generation

### Simple Gallery Pro
- **Architecture**: MVP pattern
- **Image Loading**: Glide
- **Grid**: RecyclerView
- **Key Features**:
  - No internet permissions
  - File manager integration
  - Hidden folder support
  - Customizable UI

## Key Architectural Components

### 1. Media Access Layer

```kotlin
// MediaStore API for local photos
interface PhotoRepository {
    fun getLocalPhotos(): Flow<List<Photo>>
    fun getAlbums(): Flow<List<Album>>
    fun getPhotoById(id: Long): Photo?
}

// Implementation using MediaStore
class MediaStorePhotoRepository(
    private val contentResolver: ContentResolver
) : PhotoRepository {
    // Efficient cursor-based implementation
}
```

### 2. Image Loading Strategy

**Option A: Coil (Recommended)**
- Kotlin-first, coroutines-based
- Smaller size (~2MB)
- Modern API design
- Built-in Compose support

**Option B: Glide**
- Battle-tested, mature
- Excellent performance
- Larger size (~4MB)
- More configuration options

### 3. Grid Implementation

**Compose LazyGrid (Recommended)**
```kotlin
@Composable
fun PhotoGrid(photos: List<Photo>) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 100.dp),
        contentPadding = PaddingValues(4.dp)
    ) {
        items(photos) { photo ->
            PhotoThumbnail(photo)
        }
    }
}
```

**RecyclerView (Alternative)**
- More control over performance
- Complex for advanced layouts
- Better for very large datasets

### 4. State Management

**Compose + ViewModel**
```kotlin
@HiltViewModel
class PhotoBrowserViewModel @Inject constructor(
    private val photoRepository: PhotoRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(PhotoBrowserUiState())
    val uiState = _uiState.asStateFlow()
    
    fun loadPhotos() {
        viewModelScope.launch {
            photoRepository.getLocalPhotos()
                .collect { photos ->
                    _uiState.update { it.copy(photos = photos) }
                }
        }
    }
}
```

## Performance Considerations

### 1. Thumbnail Generation
- **MediaStore Thumbnails**: Fast but limited sizes
- **Custom Generation**: More control but slower
- **Hybrid Approach**: Use MediaStore with fallback

### 2. Memory Management
- Limit concurrent image loads
- Implement proper lifecycle handling
- Use appropriate bitmap configs
- Clear caches on low memory

### 3. Scrolling Performance
- Preload images ahead of scroll
- Cancel loads for off-screen items
- Use stable IDs for RecyclerView
- Implement proper view recycling

## Architecture Recommendation for Photolala

### Clean Architecture Layers

```
Presentation Layer (Compose UI)
    ↓
Domain Layer (Use Cases)
    ↓
Data Layer (Repositories)
    ↓
Framework Layer (MediaStore, S3, etc.)
```

### Module Structure

```
android/
├── app/                    # App module
│   └── di/                # Dependency injection
│
├── core/
│   ├── data/              # Data layer
│   │   ├── repository/    # Repository implementations
│   │   ├── source/        # Data sources
│   │   └── model/         # Data models
│   │
│   ├── domain/            # Domain layer
│   │   ├── model/         # Domain models
│   │   ├── usecase/       # Use cases
│   │   └── repository/    # Repository interfaces
│   │
│   └── ui/                # Shared UI
│       ├── theme/         # Material theme
│       └── component/     # Reusable components
│
└── features/
    ├── browser/           # Photo browser feature
    │   ├── ui/           # Compose UI
    │   └── viewmodel/    # ViewModels
    │
    ├── viewer/           # Photo viewer feature
    └── cloud/            # Cloud integration
```

### Technology Stack Decision

**Recommended Stack:**
- **UI**: Jetpack Compose (modern, declarative)
- **Architecture**: MVVM + Clean Architecture
- **DI**: Hilt (official, Compose support)
- **Image Loading**: Coil (Kotlin-first)
- **Navigation**: Navigation Compose
- **Async**: Coroutines + Flow
- **Database**: Room (if needed)

## Implementation Priorities

### Phase 1: Core Browsing
1. MediaStore integration
2. Basic grid with Compose
3. Photo detail view
4. Simple navigation

### Phase 2: Performance
1. Thumbnail caching
2. Scroll optimization
3. Memory management
4. Background loading

### Phase 3: Features
1. Multi-selection
2. Sorting/filtering
3. Album support
4. Search

### Phase 4: Advanced
1. Cloud integration
2. Bookmarks
3. Sharing
4. Settings

## Key Decisions

### 1. Compose vs View System
**Choose Compose** - Modern, easier state management, better developer experience

### 2. Single Activity vs Multi-Activity
**Choose Single Activity** - Better navigation, shared ViewModels, modern approach

### 3. Local-First vs Cloud-First
**Choose Local-First** - Better performance, offline support, cloud as enhancement

## References

- [Android Photo Picker](https://developer.android.com/training/data-storage/shared/photopicker)
- [MediaStore Guide](https://developer.android.com/training/data-storage/shared/media)
- [Compose Performance](https://developer.android.com/jetpack/compose/performance)
- [Modern Android Architecture](https://developer.android.com/topic/architecture)
# Android Architecture Design

## Overview

This document defines the technical architecture for Photolala Android, implementing Clean Architecture principles with modern Android development practices. The design prioritizes maintainability, testability, and performance.

## Architecture Pattern

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────┐
│                Presentation Layer                │
│        (Compose UI + ViewModels + State)        │
├─────────────────────────────────────────────────┤
│                 Domain Layer                     │
│         (Use Cases + Domain Models)              │
├─────────────────────────────────────────────────┤
│                  Data Layer                      │
│    (Repositories + Data Sources + DTOs)          │
├─────────────────────────────────────────────────┤
│              Framework Layer                     │
│   (Android APIs + External Libraries)            │
└─────────────────────────────────────────────────┘
```

### Data Flow

```
UI Event → ViewModel → UseCase → Repository → DataSource
                ↓                      ↓            ↓
            UI State ← Domain Model ← DTO ← Framework API
```

## Module Structure

```
android/
├── app/                           # Application module
│   ├── src/main/java/
│   │   └── com.electricwoods.photolala/
│   │       ├── PhotolalaApplication.kt
│   │       ├── MainActivity.kt
│   │       ├── navigation/
│   │       │   ├── PhotolalaNavHost.kt
│   │       │   └── Screen.kt
│   │       └── di/
│   │           ├── AppModule.kt
│   │           └── RepositoryModule.kt
│   └── build.gradle.kts
│
├── core/                          # Core modules
│   ├── data/                      # Data layer module
│   │   ├── repository/
│   │   │   ├── PhotoRepository.kt
│   │   │   ├── BookmarkRepository.kt
│   │   │   └── S3Repository.kt
│   │   ├── source/
│   │   │   ├── local/
│   │   │   │   ├── MediaStoreDataSource.kt
│   │   │   │   ├── PhotoDatabase.kt
│   │   │   │   └── dao/
│   │   │   └── remote/
│   │   │       ├── S3DataSource.kt
│   │   │       └── api/
│   │   └── model/
│   │       ├── PhotoDto.kt
│   │       └── BookmarkDto.kt
│   │
│   ├── domain/                    # Domain layer module
│   │   ├── model/
│   │   │   ├── Photo.kt
│   │   │   ├── Album.kt
│   │   │   └── Bookmark.kt
│   │   ├── repository/            # Repository interfaces
│   │   │   ├── PhotoRepository.kt
│   │   │   └── BookmarkRepository.kt
│   │   └── usecase/
│   │       ├── GetPhotosUseCase.kt
│   │       ├── GetAlbumsUseCase.kt
│   │       └── ToggleBookmarkUseCase.kt
│   │
│   └── ui/                        # Shared UI module
│       ├── theme/
│       │   ├── Color.kt
│       │   ├── Type.kt
│       │   └── Theme.kt
│       └── component/
│           ├── PhotoGrid.kt
│           └── LoadingIndicator.kt
│
└── features/                      # Feature modules
    ├── browser/
    │   ├── ui/
    │   │   ├── BrowserScreen.kt
    │   │   ├── BrowserViewModel.kt
    │   │   └── components/
    │   └── navigation/
    │       └── BrowserNavigation.kt
    │
    ├── viewer/
    │   ├── ui/
    │   │   ├── ViewerScreen.kt
    │   │   ├── ViewerViewModel.kt
    │   │   └── components/
    │   └── navigation/
    │
    └── cloud/
        ├── ui/
        └── navigation/
```

## Key Components

### 1. Presentation Layer

#### ViewModels
```kotlin
@HiltViewModel
class BrowserViewModel @Inject constructor(
    private val getPhotosUseCase: GetPhotosUseCase,
    private val toggleBookmarkUseCase: ToggleBookmarkUseCase
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(BrowserUiState())
    val uiState = _uiState.asStateFlow()
    
    fun loadPhotos(albumId: String) {
        viewModelScope.launch {
            getPhotosUseCase(albumId)
                .flowOn(Dispatchers.IO)
                .collect { photos ->
                    _uiState.update { 
                        it.copy(photos = photos, isLoading = false)
                    }
                }
        }
    }
}
```

#### Compose UI
```kotlin
@Composable
fun BrowserScreen(
    viewModel: BrowserViewModel = hiltViewModel(),
    onPhotoClick: (Photo) -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    PhotoGrid(
        photos = uiState.photos,
        onPhotoClick = onPhotoClick,
        onBookmarkToggle = viewModel::toggleBookmark
    )
}
```

### 2. Domain Layer

#### Domain Models
```kotlin
data class Photo(
    val id: String,
    val uri: Uri,
    val name: String,
    val dateTaken: Instant,
    val size: Long,
    val width: Int,
    val height: Int,
    val mimeType: String,
    val albumId: String,
    val isBookmarked: Boolean = false,
    val bookmarkFlags: Set<ColorFlag> = emptySet()
)

enum class ColorFlag(val emoji: String) {
    HEART("❤️"),
    THUMBS_UP("👍"),
    THUMBS_DOWN("👎"),
    PENCIL("✏️"),
    TRASH("🗑️"),
    UPLOAD("📤"),
    PRINT("🖨️"),
    CHECK("✅"),
    RED_DOT("🔴"),
    PIN("📌"),
    LIGHTBULB("💡")
}
```

#### Use Cases
```kotlin
class GetPhotosUseCase @Inject constructor(
    private val photoRepository: PhotoRepository
) {
    operator fun invoke(albumId: String? = null): Flow<List<Photo>> {
        return photoRepository.getPhotos(albumId)
    }
}
```

### 3. Data Layer

#### Repository Implementation
```kotlin
class PhotoRepositoryImpl @Inject constructor(
    private val localDataSource: MediaStoreDataSource,
    private val remoteDataSource: S3DataSource,
    private val photoDao: PhotoDao
) : PhotoRepository {
    
    override fun getPhotos(albumId: String?): Flow<List<Photo>> {
        return combine(
            localDataSource.getPhotos(albumId),
            photoDao.getBookmarks()
        ) { photos, bookmarks ->
            photos.map { photo ->
                photo.toDomain().copy(
                    isBookmarked = bookmarks.any { it.photoId == photo.id }
                )
            }
        }
    }
}
```

#### MediaStore Integration
```kotlin
class MediaStoreDataSource @Inject constructor(
    private val contentResolver: ContentResolver
) {
    fun getPhotos(albumId: String?): Flow<List<PhotoDto>> = flow {
        val photos = mutableListOf<PhotoDto>()
        
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_TAKEN,
            MediaStore.Images.Media.SIZE,
            MediaStore.Images.Media.WIDTH,
            MediaStore.Images.Media.HEIGHT,
            MediaStore.Images.Media.MIME_TYPE,
            MediaStore.Images.Media.BUCKET_ID
        )
        
        val selection = albumId?.let { 
            "${MediaStore.Images.Media.BUCKET_ID} = ?" 
        }
        val selectionArgs = albumId?.let { arrayOf(it) }
        
        contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${MediaStore.Images.Media.DATE_TAKEN} DESC"
        )?.use { cursor ->
            // Parse cursor to PhotoDto
        }
        
        emit(photos)
    }.flowOn(Dispatchers.IO)
}
```

### 4. Database Layer

#### Room Database
```kotlin
@Database(
    entities = [BookmarkEntity::class, PhotoMetadataEntity::class],
    version = 1,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class PhotoDatabase : RoomDatabase() {
    abstract fun bookmarkDao(): BookmarkDao
    abstract fun metadataDao(): PhotoMetadataDao
}

@Entity(tableName = "bookmarks")
data class BookmarkEntity(
    @PrimaryKey val photoId: String,
    val photoMd5: String,
    val flags: Set<ColorFlag>,
    val createdAt: Instant,
    val updatedAt: Instant
)

@Dao
interface BookmarkDao {
    @Query("SELECT * FROM bookmarks")
    fun getAllBookmarks(): Flow<List<BookmarkEntity>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBookmark(bookmark: BookmarkEntity)
}
```

## Dependency Injection

### Hilt Modules
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DataModule {
    
    @Provides
    @Singleton
    fun providePhotoDatabase(@ApplicationContext context: Context): PhotoDatabase {
        return Room.databaseBuilder(
            context,
            PhotoDatabase::class.java,
            "photolala.db"
        ).build()
    }
    
    @Provides
    @Singleton
    fun provideContentResolver(@ApplicationContext context: Context): ContentResolver {
        return context.contentResolver
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    
    @Binds
    abstract fun bindPhotoRepository(
        photoRepositoryImpl: PhotoRepositoryImpl
    ): PhotoRepository
}
```

## Image Loading

### Coil Configuration
```kotlin
@Provides
@Singleton
fun provideImageLoader(@ApplicationContext context: Context): ImageLoader {
    return ImageLoader.Builder(context)
        .components {
            add(VideoFrameDecoder.Factory())
        }
        .memoryCache {
            MemoryCache.Builder(context)
                .maxSizePercent(0.25)
                .build()
        }
        .diskCache {
            DiskCache.Builder()
                .directory(context.cacheDir.resolve("image_cache"))
                .maxSizeBytes(100 * 1024 * 1024) // 100MB
                .build()
        }
        .respectCacheHeaders(false)
        .build()
}
```

## Navigation

### Navigation Graph
```kotlin
@Composable
fun PhotolalaNavHost(
    navController: NavHostController,
    modifier: Modifier = Modifier
) {
    NavHost(
        navController = navController,
        startDestination = Screen.Browser.route,
        modifier = modifier
    ) {
        composable(Screen.Browser.route) {
            BrowserScreen(
                onPhotoClick = { photo ->
                    navController.navigate(Screen.Viewer.createRoute(photo.id))
                }
            )
        }
        
        composable(
            route = Screen.Viewer.route,
            arguments = Screen.Viewer.arguments
        ) { backStackEntry ->
            ViewerScreen(
                photoId = backStackEntry.arguments?.getString("photoId") ?: "",
                onBack = { navController.popBackStack() }
            )
        }
    }
}
```

## State Management

### UI State
```kotlin
data class BrowserUiState(
    val photos: List<Photo> = emptyList(),
    val selectedPhotos: Set<String> = emptySet(),
    val isLoading: Boolean = true,
    val error: String? = null,
    val isSelectionMode: Boolean = false,
    val sortOption: SortOption = SortOption.DATE_NEWEST,
    val groupingOption: GroupingOption = GroupingOption.NONE
)

sealed interface BrowserEvent {
    data class PhotoClicked(val photo: Photo) : BrowserEvent
    data class PhotoLongPressed(val photo: Photo) : BrowserEvent
    data class BookmarkToggled(val photoId: String) : BrowserEvent
    data object SelectAllClicked : BrowserEvent
    data object ClearSelectionClicked : BrowserEvent
}
```

## Performance Considerations

### 1. Image Loading
- Thumbnail caching with Coil
- Progressive loading (thumbnail → full)
- Memory cache limits
- Disk cache management

### 2. List Performance
- LazyGrid with key parameter
- Item recycling
- Stable IDs
- DiffUtil for updates

### 3. Database
- Indexed queries
- Flow for reactive updates
- Suspend functions for writes
- Transaction batching

## Testing Strategy

### 1. Unit Tests
```kotlin
class GetPhotosUseCaseTest {
    @Mock private lateinit var repository: PhotoRepository
    private lateinit var useCase: GetPhotosUseCase
    
    @Test
    fun `invoke returns photos from repository`() = runTest {
        // Given
        val expected = listOf(testPhoto())
        whenever(repository.getPhotos(null)).thenReturn(flowOf(expected))
        
        // When
        val result = useCase().first()
        
        // Then
        assertEquals(expected, result)
    }
}
```

### 2. Integration Tests
- Room database tests
- MediaStore integration
- Navigation tests

### 3. UI Tests
- Compose testing
- Screenshot tests
- Interaction tests

## Security

### 1. Data Protection
- Android Keystore for credentials
- Encrypted SharedPreferences
- No sensitive data in logs

### 2. Network Security
- Certificate pinning for S3
- Network security config
- ProGuard rules

## Build Configuration

### Gradle Setup
```kotlin
// app/build.gradle.kts
android {
    compileSdk = 34
    
    defaultConfig {
        minSdk = 24
        targetSdk = 34
    }
    
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(libs.androidx.core)
    implementation(libs.androidx.lifecycle)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.hilt.android)
    implementation(libs.coil.compose)
    implementation(libs.room.runtime)
    implementation(libs.kotlinx.coroutines)
}
```

This architecture provides a solid foundation for building Photolala on Android with clean separation of concerns, testability, and modern Android development practices.
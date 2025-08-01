package com.electricwoods.photolala.viewmodels

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.data.PreferencesManager
import com.electricwoods.photolala.models.ColorFlag
import com.electricwoods.photolala.models.PhotoGooglePhotos
import com.electricwoods.photolala.repositories.PhotoRepository
import com.electricwoods.photolala.repositories.PhotoTagRepository
import com.electricwoods.photolala.services.BackupQueueManager
import com.electricwoods.photolala.services.GooglePhotosException
import com.electricwoods.photolala.services.GooglePhotosService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for Google Photos browser
 * Similar to ApplePhotosProvider on iOS
 */
@HiltViewModel
class GooglePhotosProvider @Inject constructor(
	private val googlePhotosService: GooglePhotosService,
	private val photoRepository: PhotoRepository,
	private val photoTagRepository: PhotoTagRepository,
	private val preferencesManager: PreferencesManager,
	val backupQueueManager: BackupQueueManager
) : ViewModel() {
	
	companion object {
		private const val TAG = "GooglePhotosProvider"
	}
	
	// Photos state
	private val _photos = MutableStateFlow<List<PhotoGooglePhotos>>(emptyList())
	val photos: StateFlow<List<PhotoGooglePhotos>> = _photos.asStateFlow()
	
	// Loading state
	private val _isLoading = MutableStateFlow(false)
	val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
	
	// Error state
	private val _error = MutableStateFlow<String?>(null)
	val error: StateFlow<String?> = _error.asStateFlow()
	
	// Authorization state
	private val _isAuthorized = MutableStateFlow(false)
	val isAuthorized: StateFlow<Boolean> = _isAuthorized.asStateFlow()
	
	// Albums
	private val _albums = MutableStateFlow<List<GooglePhotosService.GooglePhotosAlbum>>(emptyList())
	val albums: StateFlow<List<GooglePhotosService.GooglePhotosAlbum>> = _albums.asStateFlow()
	
	private val _currentAlbum = MutableStateFlow<GooglePhotosService.GooglePhotosAlbum?>(null)
	val currentAlbum: StateFlow<GooglePhotosService.GooglePhotosAlbum?> = _currentAlbum.asStateFlow()
	
	// Selection state (similar to PhotoGridViewModel)
	private val _selectedPhotos = MutableStateFlow<Set<String>>(emptySet())
	val selectedPhotos: StateFlow<Set<String>> = _selectedPhotos.asStateFlow()
	
	private val _isSelectionMode = MutableStateFlow(false)
	val isSelectionMode: StateFlow<Boolean> = _isSelectionMode.asStateFlow()
	
	// Tags state
	private val _photoTags = MutableStateFlow<Map<String, Set<ColorFlag>>>(emptyMap())
	val photoTags: StateFlow<Map<String, Set<ColorFlag>>> = _photoTags.asStateFlow()
	
	// Starred photos state
	private val _starredPhotos = MutableStateFlow<Set<String>>(emptySet())
	val starredPhotos: StateFlow<Set<String>> = _starredPhotos.asStateFlow()
	
	// Pagination
	private var nextPageToken: String? = null
	private var isLoadingMore = false
	
	// URL cache with timestamps
	private val thumbnailUrlCache = mutableMapOf<String, String>()
	private val urlExpirationTime = mutableMapOf<String, Long>()
	
	// Grid preferences (reuse from PhotoGridViewModel)
	val thumbnailSize: StateFlow<Int> = preferencesManager.gridThumbnailSize
		.stateIn(
			scope = viewModelScope,
			started = SharingStarted.WhileSubscribed(5_000),
			initialValue = PreferencesManager.DEFAULT_THUMBNAIL_SIZE
		)
	
	val gridScaleMode: StateFlow<String> = preferencesManager.gridScaleMode
		.stateIn(
			scope = viewModelScope,
			started = SharingStarted.WhileSubscribed(5_000),
			initialValue = PreferencesManager.DEFAULT_GRID_SCALE_MODE
		)
	
	val showInfoBar: StateFlow<Boolean> = preferencesManager.showInfoBar
		.stateIn(
			scope = viewModelScope,
			started = SharingStarted.WhileSubscribed(5_000),
			initialValue = PreferencesManager.DEFAULT_SHOW_INFO_BAR
		)
	
	// Display properties
	val displayTitle: String 
		get() = _currentAlbum.value?.title ?: "All Photos"
	
	val displaySubtitle: String
		get() = "${_photos.value.size} photos"
	
	val selectionCount: StateFlow<Int> = _selectedPhotos.map { it.size }
		.stateIn(viewModelScope, SharingStarted.Lazily, 0)
	
	val areAllPhotosSelected: StateFlow<Boolean> = combine(
		_photos,
		_selectedPhotos
	) { photos, selected ->
		photos.isNotEmpty() && photos.size == selected.size
	}.stateIn(viewModelScope, SharingStarted.Lazily, false)
	
	init {
		// Load starred photos from database
		viewModelScope.launch {
			photoRepository.getStarredPhotos().collect { starredPhotoEntities ->
				_starredPhotos.value = starredPhotoEntities.map { it.id }.toSet()
			}
		}
		
		// Load tags when photos change
		viewModelScope.launch {
			_photos.collect { photoList ->
				if (photoList.isNotEmpty()) {
					loadTagsForPhotos(photoList.map { it.id })
				}
			}
		}
	}
	
	/**
	 * Check and request authorization
	 */
	suspend fun checkAuthorization() {
		_isAuthorized.value = googlePhotosService.isAuthorized()
		
		if (!_isAuthorized.value) {
			Log.w(TAG, "Google Photos access not authorized")
			_error.value = "Google Photos access required. Please sign in again with Photos permission."
		}
	}
	
	/**
	 * Load albums
	 */
	suspend fun loadAlbums() {
		if (!_isAuthorized.value) return
		
		Log.d(TAG, "Loading albums")
		googlePhotosService.listAlbums()
			.onSuccess { albumList ->
				_albums.value = albumList
				Log.d(TAG, "Loaded ${albumList.size} albums")
			}
			.onFailure { e ->
				Log.e(TAG, "Failed to load albums", e)
				_error.value = "Failed to load albums: ${e.message}"
			}
	}
	
	/**
	 * Load photos
	 */
	suspend fun loadPhotos() {
		if (!_isAuthorized.value) return
		
		_isLoading.value = true
		_error.value = null
		nextPageToken = null
		
		try {
			Log.d(TAG, "Loading photos from ${displayTitle}")
			
			val result = googlePhotosService.listPhotos(
				albumId = _currentAlbum.value?.id,
				pageToken = null,
				pageSize = 50
			)
			
			result.onSuccess { page ->
				val photosWithUrls = page.photos.map { photo ->
					// Cache URLs with expiration time (60 minutes from now)
					thumbnailUrlCache[photo.id] = photo.baseUrl
					urlExpirationTime[photo.id] = System.currentTimeMillis() + (60 * 60 * 1000)
					photo
				}
				
				_photos.value = photosWithUrls
				nextPageToken = page.nextPageToken
				
				Log.d(TAG, "Loaded ${photosWithUrls.size} photos")
			}.onFailure { e ->
				Log.e(TAG, "Failed to load photos", e)
				_error.value = "Failed to load photos: ${e.message}"
			}
		} finally {
			_isLoading.value = false
		}
	}
	
	/**
	 * Load more photos (pagination)
	 */
	fun loadMorePhotos() {
		if (isLoadingMore || nextPageToken == null || !_isAuthorized.value) return
		
		viewModelScope.launch {
			isLoadingMore = true
			
			try {
				val result = googlePhotosService.listPhotos(
					albumId = _currentAlbum.value?.id,
					pageToken = nextPageToken,
					pageSize = 50
				)
				
				result.onSuccess { page ->
					val photosWithUrls = page.photos.map { photo ->
						// Cache URLs with expiration time (60 minutes from now)
						thumbnailUrlCache[photo.id] = photo.baseUrl
						urlExpirationTime[photo.id] = System.currentTimeMillis() + (60 * 60 * 1000)
						photo
					}
					
					_photos.value = _photos.value + photosWithUrls
					nextPageToken = page.nextPageToken
					
					Log.d(TAG, "Loaded ${photosWithUrls.size} more photos")
				}
			} catch (e: Exception) {
				Log.e(TAG, "Failed to load more photos", e)
			} finally {
				isLoadingMore = false
			}
		}
	}
	
	/**
	 * Refresh photos
	 */
	fun refresh() {
		viewModelScope.launch {
			loadPhotos()
		}
	}
	
	/**
	 * Select album
	 */
	fun selectAlbum(album: GooglePhotosService.GooglePhotosAlbum?) {
		_currentAlbum.value = album
		viewModelScope.launch {
			loadPhotos()
		}
	}
	
	/**
	 * Get thumbnail URL with size parameter
	 */
	fun getThumbnailUrl(photo: PhotoGooglePhotos, size: ThumbnailSize = ThumbnailSize.MEDIUM): String {
		val cached = thumbnailUrlCache[photo.id]
		val expiration = urlExpirationTime[photo.id] ?: 0
		
		// Check if URL is expired
		if (cached != null && System.currentTimeMillis() < expiration) {
			return "$cached=${size.urlParam}"
		}
		
		// Return original URL with size parameter as fallback
		// The UI should trigger a refresh if needed
		return "${photo.baseUrl}=${size.urlParam}"
	}
	
	/**
	 * Refresh expired URLs for visible photos
	 */
	suspend fun refreshExpiredUrls(photoIds: List<String>) {
		val expiredIds = photoIds.filter { id ->
			val expiration = urlExpirationTime[id] ?: 0
			System.currentTimeMillis() >= expiration
		}
		
		if (expiredIds.isEmpty()) return
		
		Log.d(TAG, "Refreshing ${expiredIds.size} expired URLs")
		
		val photos = _photos.value.filter { expiredIds.contains(it.id) }
		val mediaItemIds = photos.map { it.mediaItemId }
		
		val result = googlePhotosService.refreshPhotoUrls(mediaItemIds)
		result.onSuccess { urlMap ->
			photos.forEach { photo ->
				urlMap[photo.mediaItemId]?.let { newUrl ->
					thumbnailUrlCache[photo.id] = newUrl
					urlExpirationTime[photo.id] = System.currentTimeMillis() + (60 * 60 * 1000)
				}
			}
		}
	}
	
	/**
	 * Thumbnail size options
	 */
	enum class ThumbnailSize(val urlParam: String) {
		SMALL("w256-h256-c"),
		MEDIUM("w512-h512-c"),
		LARGE("w1024-h1024-c")
	}
	
	// Selection methods (similar to PhotoGridViewModel)
	fun toggleSelection(photoId: String) {
		_selectedPhotos.update { current ->
			if (current.contains(photoId)) {
				current - photoId
			} else {
				current + photoId
			}
		}
		
		if (_selectedPhotos.value.size == 1 && !_isSelectionMode.value) {
			_isSelectionMode.value = true
		}
		
		if (_selectedPhotos.value.isEmpty() && _isSelectionMode.value) {
			_isSelectionMode.value = false
		}
	}
	
	fun startSelectionMode(initialPhotoId: String? = null) {
		_isSelectionMode.value = true
		if (initialPhotoId != null) {
			_selectedPhotos.value = setOf(initialPhotoId)
		}
	}
	
	fun exitSelectionMode() {
		_isSelectionMode.value = false
		_selectedPhotos.value = emptySet()
	}
	
	fun toggleSelectAll() {
		if (areAllPhotosSelected.value) {
			_selectedPhotos.value = emptySet()
		} else {
			_selectedPhotos.value = _photos.value.map { it.id }.toSet()
			if (_selectedPhotos.value.isNotEmpty()) {
				_isSelectionMode.value = true
			}
		}
	}
	
	// Tag methods
	private suspend fun loadTagsForPhotos(photoIds: List<String>) {
		val tags = photoTagRepository.getTagsForPhotos(photoIds)
		_photoTags.value = tags
	}
	
	fun toggleTagForSelected(colorFlag: ColorFlag) {
		viewModelScope.launch {
			val selectedIds = _selectedPhotos.value.toList()
			if (selectedIds.isNotEmpty()) {
				photoTagRepository.toggleTagsForPhotos(selectedIds, colorFlag)
				loadTagsForPhotos(_photos.value.map { it.id })
			}
		}
	}
	
	fun removeAllTagsForSelected() {
		viewModelScope.launch {
			val selectedIds = _selectedPhotos.value.toList()
			selectedIds.forEach { photoId ->
				photoTagRepository.removeAllTags(photoId)
			}
			loadTagsForPhotos(_photos.value.map { it.id })
		}
	}
	
	// Star methods
	fun toggleStar(photoId: String) {
		viewModelScope.launch {
			val photo = _photos.value.find { it.id == photoId }
			photo?.let {
				// Note: Google Photos photos cannot be backed up directly
				// This would need to download the photo first
				photoRepository.toggleStarredStatus(photoId)
			}
		}
	}
	
	fun toggleStarForSelected() {
		viewModelScope.launch {
			val selectedIds = _selectedPhotos.value.toList()
			val currentStarredIds = _starredPhotos.value
			
			val shouldStar = selectedIds.any { !currentStarredIds.contains(it) }
			
			selectedIds.forEach { photoId ->
				photoRepository.updateStarredStatus(photoId, shouldStar)
			}
		}
	}
	
	// Preference update methods
	fun updateThumbnailSize(size: Int) {
		viewModelScope.launch {
			preferencesManager.setGridThumbnailSize(size)
		}
	}
	
	fun updateGridScaleMode(mode: String) {
		viewModelScope.launch {
			preferencesManager.setGridScaleMode(mode)
		}
	}
	
	fun updateShowInfoBar(show: Boolean) {
		viewModelScope.launch {
			preferencesManager.setShowInfoBar(show)
		}
	}
}
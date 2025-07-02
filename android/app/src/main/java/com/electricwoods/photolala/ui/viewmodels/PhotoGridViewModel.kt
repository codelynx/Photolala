package com.electricwoods.photolala.ui.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.data.PreferencesManager
import com.electricwoods.photolala.models.ColorFlag
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.repositories.PhotoTagRepository
import com.electricwoods.photolala.services.MediaStoreService
import com.electricwoods.photolala.utils.DeviceUtils
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject
import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext

@HiltViewModel
class PhotoGridViewModel @Inject constructor(
	@ApplicationContext private val context: Context,
	private val mediaStoreService: MediaStoreService,
	private val photoTagRepository: PhotoTagRepository,
	private val preferencesManager: PreferencesManager
) : ViewModel() {
	
	private val _photos = MutableStateFlow<List<PhotoMediaStore>>(emptyList())
	val photos: StateFlow<List<PhotoMediaStore>> = _photos.asStateFlow()
	
	private val _isLoading = MutableStateFlow(false)
	val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
	
	private val _error = MutableStateFlow<String?>(null)
	val error: StateFlow<String?> = _error.asStateFlow()
	
	// Selection state
	private val _selectedPhotos = MutableStateFlow<Set<String>>(emptySet())
	val selectedPhotos: StateFlow<Set<String>> = _selectedPhotos.asStateFlow()
	
	private val _isSelectionMode = MutableStateFlow(false)
	val isSelectionMode: StateFlow<Boolean> = _isSelectionMode.asStateFlow()
	
	val selectionCount: StateFlow<Int> = _selectedPhotos.map { it.size }
		.stateIn(viewModelScope, SharingStarted.Lazily, 0)
	
	val areAllPhotosSelected: StateFlow<Boolean> = combine(
		_photos,
		_selectedPhotos
	) { photos, selected ->
		photos.isNotEmpty() && photos.size == selected.size
	}.stateIn(viewModelScope, SharingStarted.Lazily, false)
	
	// Tag state - maps photoId to set of color flags
	private val _photoTags = MutableStateFlow<Map<String, Set<ColorFlag>>>(emptyMap())
	val photoTags: StateFlow<Map<String, Set<ColorFlag>>> = _photoTags.asStateFlow()
	
	// Grid preferences from DataStore
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
	
	
	init {
		// Load tags for photos when they are loaded
		viewModelScope.launch {
			_photos.collect { photoList ->
				if (photoList.isNotEmpty()) {
					loadTagsForPhotos(photoList.map { it.id })
				}
			}
		}
	}
	
	// Pagination
	private var currentOffset = 0
	private val pageSize = 100
	private var isLoadingMore = false
	private var hasMorePhotos = true
	
	fun loadPhotos() {
		// Skip permission check here - MainActivity handles it
		// The UI will show empty state if no permission
		
		viewModelScope.launch {
			_isLoading.value = true
			_error.value = null
			
			try {
				// Reset pagination
				currentOffset = 0
				hasMorePhotos = true
				
				mediaStoreService.getPhotos(limit = pageSize, offset = 0)
					.catch { e ->
						e.printStackTrace()
						_error.value = e.message ?: "Failed to load photos"
					}
					.collect { photoList ->
						_photos.value = photoList
						currentOffset = photoList.size
						hasMorePhotos = photoList.size == pageSize
					}
			} catch (e: Exception) {
				e.printStackTrace()
				_error.value = e.message ?: "Failed to load photos"
			} finally {
				_isLoading.value = false
			}
		}
	}
	
	fun loadMorePhotos() {
		if (isLoadingMore || !hasMorePhotos || _isLoading.value) return
		
		viewModelScope.launch {
			isLoadingMore = true
			
			try {
				mediaStoreService.getPhotos(limit = pageSize, offset = currentOffset)
					.catch { e ->
						// Don't show error for pagination failures
						println("Failed to load more photos: ${e.message}")
					}
					.collect { photoList ->
						if (photoList.isNotEmpty()) {
							_photos.value = _photos.value + photoList
							currentOffset += photoList.size
							hasMorePhotos = photoList.size == pageSize
						} else {
							hasMorePhotos = false
						}
					}
			} catch (e: Exception) {
				// Silently fail for pagination
				println("Failed to load more photos: ${e.message}")
			} finally {
				isLoadingMore = false
			}
		}
	}
	
	fun refreshPhotos() {
		loadPhotos()
	}
	
	// Selection methods
	fun toggleSelection(photoId: String) {
		_selectedPhotos.update { current ->
			if (current.contains(photoId)) {
				current - photoId
			} else {
				current + photoId
			}
		}
		
		// Start selection mode if we're selecting the first photo
		if (_selectedPhotos.value.size == 1 && !_isSelectionMode.value) {
			_isSelectionMode.value = true
		}
		
		// Exit selection mode if we've deselected all photos
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
	
	fun clearSelection() {
		_selectedPhotos.value = emptySet()
	}
	
	fun toggleSelectAll() {
		if (areAllPhotosSelected.value) {
			// All selected, so deselect all
			clearSelection()
			// Keep selection mode active - user can continue selecting
		} else {
			// Not all selected, so select all
			_selectedPhotos.value = _photos.value.map { it.id }.toSet()
			if (_selectedPhotos.value.isNotEmpty()) {
				_isSelectionMode.value = true
			}
		}
	}
	
	fun isPhotoSelected(photoId: String): Boolean {
		return _selectedPhotos.value.contains(photoId)
	}
	
	fun getSelectedPhotoUris(): List<android.net.Uri> {
		val selectedIds = _selectedPhotos.value
		return _photos.value
			.filter { photo -> selectedIds.contains(photo.id) }
			.map { it.uri }
	}
	
	// DEVELOPMENT ONLY - Delete selected photos
	fun deleteSelectedPhotos() {
		viewModelScope.launch {
			val selectedIds = _selectedPhotos.value.toList()
			if (selectedIds.isEmpty()) return@launch
			
			// Show loading or processing state
			_isLoading.value = true
			
			try {
				val result = mediaStoreService.deletePhotos(selectedIds)
				
				result.fold(
					onSuccess = { deletedCount ->
						// Remove deleted photos from our list
						_photos.value = _photos.value.filterNot { photo ->
							selectedIds.contains(photo.id)
						}
						
						// Clear selection
						clearSelection()
						exitSelectionMode()
						
						// Show success message (in a real app, use a snackbar)
						println("Successfully deleted $deletedCount photos")
					},
					onFailure = { error ->
						// Handle error
						_error.value = error.message ?: "Failed to delete photos"
						println("Delete error: ${error.message}")
					}
				)
			} catch (e: Exception) {
				_error.value = "Failed to delete photos: ${e.message}"
			} finally {
				_isLoading.value = false
			}
		}
	}
	
	// Tag methods
	private suspend fun loadTagsForPhotos(photoIds: List<String>) {
		val tags = photoTagRepository.getTagsForPhotos(photoIds)
		_photoTags.value = tags
	}
	
	fun toggleTag(photoId: String, colorFlag: ColorFlag) {
		viewModelScope.launch {
			photoTagRepository.toggleTag(photoId, colorFlag)
			// Reload tags for this photo
			val currentTags = _photoTags.value.toMutableMap()
			val updatedTags = photoTagRepository.getTagsForPhotos(listOf(photoId))
			if (updatedTags.containsKey(photoId)) {
				currentTags[photoId] = updatedTags[photoId]!!
			} else {
				currentTags.remove(photoId)
			}
			_photoTags.value = currentTags
		}
	}
	
	fun toggleTagForSelected(colorFlag: ColorFlag) {
		viewModelScope.launch {
			val selectedIds = _selectedPhotos.value.toList()
			if (selectedIds.isNotEmpty()) {
				photoTagRepository.toggleTagsForPhotos(selectedIds, colorFlag)
				// Reload tags for selected photos
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
			// Reload tags
			loadTagsForPhotos(_photos.value.map { it.id })
		}
	}
	
	fun getPhotoTags(photoId: String): Set<ColorFlag> {
		return _photoTags.value[photoId] ?: emptySet()
	}
	
	fun hasAnyTag(photoId: String): Boolean {
		return _photoTags.value.containsKey(photoId) && _photoTags.value[photoId]!!.isNotEmpty()
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
	
}
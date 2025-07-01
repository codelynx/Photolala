package com.electricwoods.photolala.ui.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.services.MediaStoreService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PhotoGridViewModel @Inject constructor(
	private val mediaStoreService: MediaStoreService
) : ViewModel() {
	
	private val _photos = MutableStateFlow<List<PhotoMediaStore>>(emptyList())
	val photos: StateFlow<List<PhotoMediaStore>> = _photos.asStateFlow()
	
	private val _isLoading = MutableStateFlow(false)
	val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
	
	private val _error = MutableStateFlow<String?>(null)
	val error: StateFlow<String?> = _error.asStateFlow()
	
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
}
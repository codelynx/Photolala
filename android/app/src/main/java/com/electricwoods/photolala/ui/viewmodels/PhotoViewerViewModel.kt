package com.electricwoods.photolala.ui.viewmodels

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.services.MediaStoreService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

@HiltViewModel
class PhotoViewerViewModel @Inject constructor(
	private val mediaStoreService: MediaStoreService,
	savedStateHandle: SavedStateHandle
) : ViewModel() {
	
	// Photos list passed through navigation
	private val _photos = MutableStateFlow<List<PhotoMediaStore>>(emptyList())
	val photos: StateFlow<List<PhotoMediaStore>> = _photos.asStateFlow()
	
	// Current photo being viewed
	private val _currentPhoto = MutableStateFlow<PhotoMediaStore?>(null)
	val currentPhoto: StateFlow<PhotoMediaStore?> = _currentPhoto.asStateFlow()
	
	// Show/hide photo info
	private val _showInfo = MutableStateFlow(false)
	val showInfo: StateFlow<Boolean> = _showInfo.asStateFlow()
	
	private var currentIndex: Int = 0
	
	fun setPhotos(photoList: List<PhotoMediaStore>, initialIndex: Int) {
		_photos.value = photoList
		currentIndex = initialIndex
		updateCurrentPhoto()
	}
	
	fun setCurrentIndex(index: Int) {
		currentIndex = index
		updateCurrentPhoto()
	}
	
	fun toggleInfo() {
		_showInfo.value = !_showInfo.value
	}
	
	private fun updateCurrentPhoto() {
		_currentPhoto.value = _photos.value.getOrNull(currentIndex)
	}
}
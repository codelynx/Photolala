package com.electricwoods.photolala.ui.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.models.PhotoS3
import com.electricwoods.photolala.services.S3PhotoProvider
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for Cloud Browser screen
 * Manages S3 photo loading and UI state
 */
@HiltViewModel
class CloudBrowserViewModel @Inject constructor(
    private val s3PhotoProvider: S3PhotoProvider
) : ViewModel() {
    
    // UI State
    private val _uiState = MutableStateFlow(CloudBrowserUiState())
    val uiState: StateFlow<CloudBrowserUiState> = _uiState.asStateFlow()
    
    // Photos flow
    private val _photos = MutableStateFlow<List<PhotoS3>>(emptyList())
    val photos: StateFlow<List<PhotoS3>> = _photos.asStateFlow()
    
    // Selected photos for multi-selection
    private val _selectedPhotos = MutableStateFlow<Set<PhotoS3>>(emptySet())
    val selectedPhotos: StateFlow<Set<PhotoS3>> = _selectedPhotos.asStateFlow()
    
    // Search query
    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()
    
    // Filtered photos based on search
    val filteredPhotos: StateFlow<List<PhotoS3>> = combine(
        _photos,
        _searchQuery
    ) { photos, query ->
        if (query.isBlank()) {
            photos
        } else {
            photos.filter { photo ->
                photo.filename.contains(query, ignoreCase = true)
            }
        }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )
    
    init {
        loadPhotos()
    }
    
    /**
     * Load photos from S3
     */
    fun loadPhotos() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            
            try {
                s3PhotoProvider.getPhotos().collect { photoList ->
                    _photos.value = photoList
                    _uiState.update { 
                        it.copy(
                            isLoading = false,
                            isEmpty = photoList.isEmpty()
                        )
                    }
                }
            } catch (e: Exception) {
                _uiState.update { 
                    it.copy(
                        isLoading = false,
                        error = e.message ?: "Failed to load photos"
                    )
                }
            }
        }
    }
    
    /**
     * Refresh photos from S3
     */
    fun refresh() {
        viewModelScope.launch {
            _uiState.update { it.copy(isRefreshing = true) }
            
            try {
                s3PhotoProvider.refresh()
                loadPhotos()
            } finally {
                _uiState.update { it.copy(isRefreshing = false) }
            }
        }
    }
    
    /**
     * Toggle photo selection
     */
    fun togglePhotoSelection(photo: PhotoS3) {
        _selectedPhotos.update { currentSelection ->
            if (currentSelection.contains(photo)) {
                currentSelection - photo
            } else {
                currentSelection + photo
            }
        }
    }
    
    /**
     * Clear all selections
     */
    fun clearSelection() {
        _selectedPhotos.value = emptySet()
    }
    
    /**
     * Select all visible photos
     */
    fun selectAll() {
        _selectedPhotos.value = filteredPhotos.value.toSet()
    }
    
    /**
     * Update search query
     */
    fun updateSearchQuery(query: String) {
        _searchQuery.value = query
    }
    
    /**
     * Download selected photos
     */
    fun downloadSelectedPhotos() {
        viewModelScope.launch {
            // TODO: Implement download functionality
            val selected = _selectedPhotos.value
            if (selected.isNotEmpty()) {
                // Download logic here
            }
        }
    }
    
    /**
     * Load thumbnail for a photo
     */
    suspend fun loadThumbnail(photo: PhotoS3): ByteArray? {
        return s3PhotoProvider.loadThumbnail(photo)
    }
    
    /**
     * Load full image data for a photo
     */
    suspend fun loadImageData(photo: PhotoS3): ByteArray {
        return s3PhotoProvider.loadImageData(photo)
    }
}

/**
 * UI State for Cloud Browser
 */
data class CloudBrowserUiState(
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val isEmpty: Boolean = false,
    val error: String? = null
)
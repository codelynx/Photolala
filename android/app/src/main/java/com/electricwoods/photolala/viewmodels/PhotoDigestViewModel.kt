package com.electricwoods.photolala.viewmodels

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.models.PhotoDigest
import com.electricwoods.photolala.models.PhotoFile
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.models.PhotoS3
import com.electricwoods.photolala.services.PhotoManagerV2
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import timber.log.Timber

/**
 * ViewModel for managing PhotoDigest operations in UI
 * Provides convenient methods for loading thumbnails using the two-level cache
 */
class PhotoDigestViewModel(application: Application) : AndroidViewModel(application) {
	
	private val photoManager = PhotoManagerV2.getInstance(application)
	
	// Cache statistics
	private val _cacheStats = MutableStateFlow<PhotoManagerV2.CacheStats?>(null)
	val cacheStats: StateFlow<PhotoManagerV2.CacheStats?> = _cacheStats
	
	init {
		// Load initial cache stats
		updateCacheStats()
	}
	
	/**
	 * Gets thumbnail bitmap for a PhotoFile
	 */
	suspend fun getThumbnailForFile(photo: PhotoFile): Bitmap? {
		return withContext(Dispatchers.IO) {
			try {
				val photoDigest = photoManager.getPhotoDigestForFile(photo)
				photoDigest?.let {
					BitmapFactory.decodeByteArray(it.thumbnailData, 0, it.thumbnailData.size)
				}
			} catch (e: Exception) {
				Timber.e(e, "Failed to get thumbnail for file: ${photo.path}")
				null
			}
		}
	}
	
	/**
	 * Gets thumbnail bitmap for a PhotoMediaStore
	 */
	suspend fun getThumbnailForMediaStore(photo: PhotoMediaStore): Bitmap? {
		return withContext(Dispatchers.IO) {
			try {
				val photoDigest = photoManager.getPhotoDigestForMediaStore(photo)
				photoDigest?.let {
					BitmapFactory.decodeByteArray(it.thumbnailData, 0, it.thumbnailData.size)
				}
			} catch (e: Exception) {
				Timber.e(e, "Failed to get thumbnail for MediaStore: ${photo.id}")
				null
			}
		}
	}
	
	/**
	 * Gets thumbnail bitmap for a PhotoS3
	 */
	suspend fun getThumbnailForS3(photo: PhotoS3): Bitmap? {
		return withContext(Dispatchers.IO) {
			try {
				val photoDigest = photoManager.getPhotoDigestForS3(photo)
				photoDigest?.let {
					BitmapFactory.decodeByteArray(it.thumbnailData, 0, it.thumbnailData.size)
				}
			} catch (e: Exception) {
				Timber.e(e, "Failed to get thumbnail for S3: ${photo.key}")
				null
			}
		}
	}
	
	/**
	 * Gets PhotoDigest for any photo type
	 */
	suspend fun getPhotoDigest(photo: Any): PhotoDigest? {
		return when (photo) {
			is PhotoFile -> photoManager.getPhotoDigestForFile(photo)
			is PhotoMediaStore -> photoManager.getPhotoDigestForMediaStore(photo)
			is PhotoS3 -> photoManager.getPhotoDigestForS3(photo)
			else -> {
				Timber.w("Unknown photo type: ${photo::class.simpleName}")
				null
			}
		}
	}
	
	/**
	 * Gets thumbnail bitmap for any photo type
	 */
	suspend fun getThumbnail(photo: Any): Bitmap? {
		return when (photo) {
			is PhotoFile -> getThumbnailForFile(photo)
			is PhotoMediaStore -> getThumbnailForMediaStore(photo)
			is PhotoS3 -> getThumbnailForS3(photo)
			else -> {
				Timber.w("Unknown photo type: ${photo::class.simpleName}")
				null
			}
		}
	}
	
	/**
	 * Clears all caches
	 */
	fun clearCaches() {
		viewModelScope.launch {
			photoManager.clearCaches()
			updateCacheStats()
		}
	}
	
	/**
	 * Updates cache statistics
	 */
	fun updateCacheStats() {
		viewModelScope.launch {
			_cacheStats.value = photoManager.getCacheStats()
		}
	}
	
	/**
	 * Formats byte size for display
	 */
	fun formatByteSize(bytes: Long): String {
		return when {
			bytes < 1024 -> "$bytes B"
			bytes < 1024 * 1024 -> "%.1f KB".format(bytes / 1024.0)
			bytes < 1024 * 1024 * 1024 -> "%.1f MB".format(bytes / (1024.0 * 1024))
			else -> "%.1f GB".format(bytes / (1024.0 * 1024 * 1024))
		}
	}
}
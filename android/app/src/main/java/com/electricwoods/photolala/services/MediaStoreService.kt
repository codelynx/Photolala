package com.electricwoods.photolala.services

import com.electricwoods.photolala.models.PhotoMediaStore
import kotlinx.coroutines.flow.Flow

/**
 * Service interface for accessing photos from Android's MediaStore
 * This is the Android equivalent of Apple's PhotoProvider
 */
interface MediaStoreService {
	
	/**
	 * Get all photos from MediaStore
	 * @param limit Number of photos to load per page
	 * @param offset Starting position for pagination
	 * @return Flow of photos for reactive updates
	 */
	suspend fun getPhotos(
		limit: Int = 100,
		offset: Int = 0
	): Flow<List<PhotoMediaStore>>
	
	/**
	 * Get photos from a specific album/bucket
	 * @param bucketId The bucket/album ID from MediaStore
	 * @param limit Number of photos to load per page
	 * @param offset Starting position for pagination
	 * @return Flow of photos from the specified album
	 */
	suspend fun getPhotosFromBucket(
		bucketId: Long,
		limit: Int = 100,
		offset: Int = 0
	): Flow<List<PhotoMediaStore>>
	
	/**
	 * Get all available albums/buckets
	 * @return List of albums with their metadata
	 */
	suspend fun getAlbums(): List<Album>
	
	/**
	 * Get a single photo by its MediaStore ID
	 * @param mediaStoreId The ID from MediaStore
	 * @return The photo if found, null otherwise
	 */
	suspend fun getPhotoById(mediaStoreId: Long): PhotoMediaStore?
	
	/**
	 * Load thumbnail for a photo
	 * @param photo The photo to load thumbnail for
	 * @param size Thumbnail size in pixels (width/height)
	 * @return Thumbnail as ByteArray, null if failed
	 */
	suspend fun loadThumbnail(
		photo: PhotoMediaStore,
		size: Int = 256
	): ByteArray?
	
	/**
	 * Load full image data
	 * @param photo The photo to load
	 * @return Full image data as ByteArray
	 */
	suspend fun loadImageData(photo: PhotoMediaStore): ByteArray
	
	/**
	 * Check if we have permission to access photos
	 * @return true if we have necessary permissions
	 */
	fun hasPermission(): Boolean
	
	/**
	 * Get total photo count
	 * @return Total number of photos accessible
	 */
	suspend fun getTotalPhotoCount(): Int
}

/**
 * Represents an album/bucket from MediaStore
 */
data class Album(
	val id: Long,
	val name: String,
	val coverPhotoUri: String?,
	val photoCount: Int
)
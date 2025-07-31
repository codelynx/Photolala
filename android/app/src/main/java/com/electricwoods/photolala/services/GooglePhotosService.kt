package com.electricwoods.photolala.services

import com.electricwoods.photolala.models.PhotoGooglePhotos
import com.google.photos.types.proto.Album
import com.google.photos.types.proto.MediaItem
import kotlinx.coroutines.flow.Flow

/**
 * Service interface for Google Photos Library API
 * Similar to ApplePhotosProvider on iOS
 */
interface GooglePhotosService {
	/**
	 * Data class for Google Photos album
	 */
	data class GooglePhotosAlbum(
		val id: String,
		val title: String,
		val coverPhotoUrl: String?,
		val mediaItemsCount: Int,
		val isWriteable: Boolean = false
	)
	
	/**
	 * Data class for paginated results
	 */
	data class PhotosPage(
		val photos: List<PhotoGooglePhotos>,
		val nextPageToken: String?
	)
	
	/**
	 * Check if user has authorized Google Photos access
	 */
	suspend fun isAuthorized(): Boolean
	
	/**
	 * Request authorization for Google Photos access
	 */
	suspend fun requestAuthorization(): Result<Unit>
	
	/**
	 * List all albums
	 */
	suspend fun listAlbums(): Result<List<GooglePhotosAlbum>>
	
	/**
	 * List photos from library or specific album
	 * @param albumId Optional album ID, if null returns all photos
	 * @param pageToken Token for pagination
	 * @param pageSize Number of items per page (max 100)
	 */
	suspend fun listPhotos(
		albumId: String? = null,
		pageToken: String? = null,
		pageSize: Int = 50
	): Result<PhotosPage>
	
	/**
	 * Get a specific photo by media item ID
	 */
	suspend fun getPhoto(mediaItemId: String): Result<PhotoGooglePhotos?>
	
	/**
	 * Refresh expired URLs for photos
	 * Google Photos URLs expire after ~60 minutes
	 */
	suspend fun refreshPhotoUrls(mediaItemIds: List<String>): Result<Map<String, String>>
	
	/**
	 * Search photos with filters
	 */
	suspend fun searchPhotos(
		filters: SearchFilters,
		pageToken: String? = null,
		pageSize: Int = 50
	): Result<PhotosPage>
	
	/**
	 * Download photo data (for MD5 calculation or local storage)
	 */
	suspend fun downloadPhotoData(photo: PhotoGooglePhotos): Result<ByteArray>
	
	/**
	 * Get total photo count
	 */
	suspend fun getTotalPhotoCount(): Result<Int>
}

/**
 * Search filters for Google Photos
 */
data class SearchFilters(
	val dateRanges: List<DateRange>? = null,
	val includeArchivedMedia: Boolean = false,
	val excludeNonAppCreatedData: Boolean = false
) {
	data class DateRange(
		val startDate: Date,
		val endDate: Date
	)
	
	data class Date(
		val year: Int,
		val month: Int,
		val day: Int
	)
}
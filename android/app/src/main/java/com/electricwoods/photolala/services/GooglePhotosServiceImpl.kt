package com.electricwoods.photolala.services

import android.content.Context
import android.util.Log
import com.electricwoods.photolala.di.IoDispatcher
import com.electricwoods.photolala.models.PhotoGooglePhotos
import com.electricwoods.photolala.auth.GoogleAuthTokenProvider
import com.electricwoods.photolala.network.GooglePhotosApiClient
import com.google.android.gms.auth.api.signin.GoogleSignIn
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import java.net.URL
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Implementation of GooglePhotosService using Google Photos Library API
 */
@Singleton
class GooglePhotosServiceImpl @Inject constructor(
	@ApplicationContext private val context: Context,
	private val googleSignInLegacyService: GoogleSignInLegacyService,
	@IoDispatcher private val ioDispatcher: CoroutineDispatcher
) : GooglePhotosService {
	
	companion object {
		private const val TAG = "GooglePhotosService"
	}
	
	private val tokenProvider = GoogleAuthTokenProvider(context)
	private var apiClient: GooglePhotosApiClient? = null
	private var cachedToken: String? = null
	
	private suspend fun getApiClient(): GooglePhotosApiClient = withContext(ioDispatcher) {
		// Check if signed in
		val account = GoogleSignIn.getLastSignedInAccount(context)
			?: throw GooglePhotosException.NotSignedIn
		
		// Check if has Google Photos scope
		if (!googleSignInLegacyService.hasGooglePhotosScope()) {
			throw GooglePhotosException.AuthorizationRequired
		}
		
		// For initial testing, we'll need to implement proper OAuth2 flow
		// This requires either:
		// 1. Server-side token exchange (recommended for production)
		// 2. Direct OAuth2 flow using GoogleAuthUtil (for testing)
		// 3. Using Google Photos API key (limited functionality)
		
		// For now, throw a clear error message
		throw GooglePhotosException.ApiError(
			"Google Photos API access requires OAuth2 token exchange. " +
			"Please implement server-side token exchange or use GoogleAuthUtil for testing."
		)
	}
	
	override suspend fun isAuthorized(): Boolean = withContext(ioDispatcher) {
		googleSignInLegacyService.hasGooglePhotosScope()
	}
	
	override suspend fun requestAuthorization(): Result<Unit> = withContext(ioDispatcher) {
		try {
			if (!isAuthorized()) {
				// This would need to trigger the sign-in flow with additional scope
				// For now, return failure indicating auth needed
				Result.failure(GooglePhotosException.AuthorizationRequired)
			} else {
				Result.success(Unit)
			}
		} catch (e: Exception) {
			Log.e(TAG, "Failed to request authorization", e)
			Result.failure(e)
		}
	}
	
	override suspend fun listAlbums(): Result<List<GooglePhotosService.GooglePhotosAlbum>> = withContext(ioDispatcher) {
		try {
			Log.d(TAG, "Listing albums from Google Photos")
			val client = getApiClient()
			
			// Get all albums (might need pagination for large libraries)
			val allAlbums = mutableListOf<GooglePhotosService.GooglePhotosAlbum>()
			var pageToken: String? = null
			
			do {
				val response = client.listAlbums(pageToken = pageToken)
				allAlbums.addAll(response.albums)
				pageToken = response.nextPageToken
			} while (pageToken != null && allAlbums.size < 1000) // Limit to prevent infinite loops
			
			Log.d(TAG, "Found ${allAlbums.size} albums")
			Result.success(allAlbums)
		} catch (e: Exception) {
			Log.e(TAG, "Failed to list albums", e)
			Result.failure(e)
		}
	}
	
	override suspend fun listPhotos(
		albumId: String?,
		pageToken: String?,
		pageSize: Int
	): Result<GooglePhotosService.PhotosPage> = withContext(ioDispatcher) {
		try {
			Log.d(TAG, "Listing photos - albumId: $albumId, pageToken: $pageToken, pageSize: $pageSize")
			val client = getApiClient()
			
			val response = client.listMediaItems(
				albumId = albumId,
				pageToken = pageToken,
				pageSize = pageSize
			)
			
			Log.d(TAG, "Retrieved ${response.photos.size} photos")
			Result.success(GooglePhotosService.PhotosPage(
				photos = response.photos,
				nextPageToken = response.nextPageToken
			))
		} catch (e: Exception) {
			Log.e(TAG, "Failed to list photos", e)
			Result.failure(e)
		}
	}
	
	override suspend fun getPhoto(mediaItemId: String): Result<PhotoGooglePhotos?> = withContext(ioDispatcher) {
		try {
			Log.d(TAG, "Getting photo: $mediaItemId")
			val client = getApiClient()
			val photo = client.getMediaItem(mediaItemId)
			Result.success(photo)
		} catch (e: Exception) {
			Log.e(TAG, "Failed to get photo: $mediaItemId", e)
			Result.failure(e)
		}
	}
	
	override suspend fun refreshPhotoUrls(
		mediaItemIds: List<String>
	): Result<Map<String, String>> = withContext(ioDispatcher) {
		try {
			Log.d(TAG, "Refreshing URLs for ${mediaItemIds.size} items")
			val client = getApiClient()
			
			val refreshedPhotos = client.batchGetMediaItems(mediaItemIds)
			val urlMap = refreshedPhotos.mapValues { (_, photo) ->
				// Return base URL for thumbnail generation
				photo.baseUrl
			}
			
			Log.d(TAG, "Refreshed ${urlMap.size} URLs")
			Result.success(urlMap)
		} catch (e: Exception) {
			Log.e(TAG, "Failed to refresh URLs", e)
			Result.failure(e)
		}
	}
	
	override suspend fun searchPhotos(
		filters: SearchFilters,
		pageToken: String?,
		pageSize: Int
	): Result<GooglePhotosService.PhotosPage> = withContext(ioDispatcher) {
		try {
			Log.d(TAG, "Searching photos with filters")
			val client = getApiClient()
			
			val response = client.searchMediaItems(
				filters = filters,
				pageToken = pageToken,
				pageSize = pageSize
			)
			
			Log.d(TAG, "Search returned ${response.photos.size} photos")
			Result.success(GooglePhotosService.PhotosPage(
				photos = response.photos,
				nextPageToken = response.nextPageToken
			))
		} catch (e: Exception) {
			Log.e(TAG, "Failed to search photos", e)
			Result.failure(e)
		}
	}
	
	override suspend fun downloadPhotoData(photo: PhotoGooglePhotos): Result<ByteArray> = withContext(ioDispatcher) {
		try {
			// In a real implementation, this would download from the baseUrl
			// with proper size parameters (=d for download)
			val downloadUrl = "${photo.baseUrl}=d"
			
			val url = URL(downloadUrl)
			val connection = url.openConnection()
			connection.connectTimeout = 30000
			connection.readTimeout = 30000
			
			val data = connection.getInputStream().use { it.readBytes() }
			
			Log.d(TAG, "Downloaded ${data.size} bytes for photo ${photo.id}")
			Result.success(data)
		} catch (e: Exception) {
			Log.e(TAG, "Failed to download photo data", e)
			Result.failure(e)
		}
	}
	
	override suspend fun getTotalPhotoCount(): Result<Int> = withContext(ioDispatcher) {
		try {
			// Google Photos API doesn't provide a direct count
			// We'd need to paginate through all items to count them
			Result.success(-1)
		} catch (e: Exception) {
			Log.e(TAG, "Failed to get photo count", e)
			Result.failure(e)
		}
	}
}

/**
 * Google Photos specific exceptions
 */
sealed class GooglePhotosException(message: String) : Exception(message) {
	object NotSignedIn : GooglePhotosException("User is not signed in")
	object AuthorizationRequired : GooglePhotosException("Google Photos authorization required")
	object InvalidToken : GooglePhotosException("Invalid or expired token")
	class ApiError(message: String) : GooglePhotosException(message)
}
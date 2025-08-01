package com.electricwoods.photolala.network

import android.util.Log
import com.electricwoods.photolala.models.PhotoGooglePhotos
import com.electricwoods.photolala.services.GooglePhotosException
import com.electricwoods.photolala.services.GooglePhotosService
import com.electricwoods.photolala.services.SearchFilters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*

/**
 * Google Photos Library API client
 * Handles HTTP requests to Google Photos REST API
 */
class GooglePhotosApiClient(
	private val accessToken: String
) {
	companion object {
		private const val TAG = "GooglePhotosApiClient"
		private const val BASE_URL = "https://photoslibrary.googleapis.com/v1"
		private const val DEFAULT_PAGE_SIZE = 50
		private const val MAX_PAGE_SIZE = 100
		
		// Date format for API responses
		private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
			timeZone = TimeZone.getTimeZone("UTC")
		}
	}
	
	/**
	 * List all albums
	 */
	suspend fun listAlbums(
		pageToken: String? = null,
		pageSize: Int = DEFAULT_PAGE_SIZE
	): AlbumsResponse = withContext(Dispatchers.IO) {
		val url = buildUrl("albums") {
			if (pageToken != null) append("&pageToken=$pageToken")
			append("&pageSize=${pageSize.coerceIn(1, MAX_PAGE_SIZE)}")
		}
		
		val response = executeRequest(url, "GET")
		parseAlbumsResponse(response)
	}
	
	/**
	 * List photos in the library or a specific album
	 */
	suspend fun listMediaItems(
		albumId: String? = null,
		pageToken: String? = null,
		pageSize: Int = DEFAULT_PAGE_SIZE
	): MediaItemsResponse = withContext(Dispatchers.IO) {
		if (albumId != null) {
			// Search within album
			searchMediaItems(
				albumId = albumId,
				pageToken = pageToken,
				pageSize = pageSize
			)
		} else {
			// List all media items
			val url = buildUrl("mediaItems") {
				if (pageToken != null) append("&pageToken=$pageToken")
				append("&pageSize=${pageSize.coerceIn(1, MAX_PAGE_SIZE)}")
			}
			
			val response = executeRequest(url, "GET")
			parseMediaItemsResponse(response)
		}
	}
	
	/**
	 * Search for photos with filters
	 */
	suspend fun searchMediaItems(
		albumId: String? = null,
		filters: SearchFilters? = null,
		pageToken: String? = null,
		pageSize: Int = DEFAULT_PAGE_SIZE
	): MediaItemsResponse = withContext(Dispatchers.IO) {
		val url = buildUrl("mediaItems:search")
		
		val requestBody = JSONObject().apply {
			if (albumId != null) {
				put("albumId", albumId)
			}
			
			if (filters != null) {
				val filtersJson = JSONObject()
				
				// Date range filter
				if (filters.dateRange != null) {
					val dateFilter = JSONObject()
					val ranges = JSONArray()
					val range = JSONObject()
					
					if (filters.dateRange.first != null) {
						val startDate = JSONObject()
						val cal = Calendar.getInstance().apply { time = filters.dateRange.first }
						startDate.put("year", cal.get(Calendar.YEAR))
						startDate.put("month", cal.get(Calendar.MONTH) + 1)
						startDate.put("day", cal.get(Calendar.DAY_OF_MONTH))
						range.put("startDate", startDate)
					}
					
					if (filters.dateRange.second != null) {
						val endDate = JSONObject()
						val cal = Calendar.getInstance().apply { time = filters.dateRange.second }
						endDate.put("year", cal.get(Calendar.YEAR))
						endDate.put("month", cal.get(Calendar.MONTH) + 1)
						endDate.put("day", cal.get(Calendar.DAY_OF_MONTH))
						range.put("endDate", endDate)
					}
					
					ranges.put(range)
					dateFilter.put("ranges", ranges)
					filtersJson.put("dateFilter", dateFilter)
				}
				
				// Media type filter
				if (filters.mediaTypes.isNotEmpty()) {
					val mediaTypeFilter = JSONObject()
					val types = JSONArray()
					filters.mediaTypes.forEach { type ->
						types.put(when (type) {
							SearchFilters.MediaType.PHOTO -> "PHOTO"
							SearchFilters.MediaType.VIDEO -> "VIDEO"
						})
					}
					mediaTypeFilter.put("mediaTypes", types)
					filtersJson.put("mediaTypeFilter", mediaTypeFilter)
				}
				
				put("filters", filtersJson)
			}
			
			if (pageToken != null) {
				put("pageToken", pageToken)
			}
			put("pageSize", pageSize.coerceIn(1, MAX_PAGE_SIZE))
		}
		
		val response = executeRequest(url, "POST", requestBody.toString())
		parseMediaItemsResponse(response)
	}
	
	/**
	 * Get a single media item by ID
	 */
	suspend fun getMediaItem(mediaItemId: String): PhotoGooglePhotos? = withContext(Dispatchers.IO) {
		val url = buildUrl("mediaItems/$mediaItemId")
		
		try {
			val response = executeRequest(url, "GET")
			val json = JSONObject(response)
			parseMediaItem(json)
		} catch (e: Exception) {
			Log.e(TAG, "Failed to get media item: $mediaItemId", e)
			null
		}
	}
	
	/**
	 * Batch get media items to refresh URLs
	 */
	suspend fun batchGetMediaItems(mediaItemIds: List<String>): Map<String, PhotoGooglePhotos> = withContext(Dispatchers.IO) {
		if (mediaItemIds.isEmpty()) return@withContext emptyMap()
		
		val url = buildUrl("mediaItems:batchGet")
		val result = mutableMapOf<String, PhotoGooglePhotos>()
		
		// API limits batch size to 50
		mediaItemIds.chunked(50).forEach { batch ->
			val urlWithParams = url + batch.joinToString("&") { "mediaItemIds=$it" }
			
			try {
				val response = executeRequest(urlWithParams, "GET")
				val json = JSONObject(response)
				val results = json.optJSONArray("mediaItemResults") ?: return@forEach
				
				for (i in 0 until results.length()) {
					val itemResult = results.getJSONObject(i)
					val mediaItem = itemResult.optJSONObject("mediaItem") ?: continue
					val photo = parseMediaItem(mediaItem)
					if (photo != null) {
						result[photo.mediaItemId] = photo
					}
				}
			} catch (e: Exception) {
				Log.e(TAG, "Failed to batch get media items", e)
			}
		}
		
		result
	}
	
	// Helper functions
	
	private fun buildUrl(endpoint: String, params: StringBuilder.() -> Unit = {}): String {
		return StringBuilder("$BASE_URL/$endpoint?").apply(params).toString()
	}
	
	private fun executeRequest(
		url: String,
		method: String,
		body: String? = null
	): String {
		val connection = (URL(url).openConnection() as HttpURLConnection).apply {
			requestMethod = method
			setRequestProperty("Authorization", "Bearer $accessToken")
			setRequestProperty("Content-Type", "application/json")
			connectTimeout = 30000
			readTimeout = 30000
			
			if (body != null) {
				doOutput = true
				outputStream.use { it.write(body.toByteArray()) }
			}
		}
		
		try {
			val responseCode = connection.responseCode
			if (responseCode == HttpURLConnection.HTTP_OK) {
				return connection.inputStream.use { it.readBytes().toString(Charsets.UTF_8) }
			} else {
				val errorBody = connection.errorStream?.use { it.readBytes().toString(Charsets.UTF_8) } ?: ""
				Log.e(TAG, "API request failed with code $responseCode: $errorBody")
				
				when (responseCode) {
					HttpURLConnection.HTTP_UNAUTHORIZED -> throw GooglePhotosException.InvalidToken
					HttpURLConnection.HTTP_FORBIDDEN -> throw GooglePhotosException.AuthorizationRequired
					else -> throw GooglePhotosException.ApiError("HTTP $responseCode: $errorBody")
				}
			}
		} finally {
			connection.disconnect()
		}
	}
	
	private fun parseAlbumsResponse(response: String): AlbumsResponse {
		val json = JSONObject(response)
		val albums = mutableListOf<GooglePhotosService.GooglePhotosAlbum>()
		
		val albumsArray = json.optJSONArray("albums") ?: JSONArray()
		for (i in 0 until albumsArray.length()) {
			val albumJson = albumsArray.getJSONObject(i)
			albums.add(GooglePhotosService.GooglePhotosAlbum(
				id = albumJson.getString("id"),
				title = albumJson.optString("title", "Untitled"),
				mediaItemsCount = albumJson.optString("mediaItemsCount", "0").toIntOrNull() ?: 0,
				coverPhotoBaseUrl = albumJson.optString("coverPhotoBaseUrl"),
				coverPhotoMediaItemId = albumJson.optString("coverPhotoMediaItemId")
			))
		}
		
		return AlbumsResponse(
			albums = albums,
			nextPageToken = json.optString("nextPageToken").takeIf { it.isNotEmpty() }
		)
	}
	
	private fun parseMediaItemsResponse(response: String): MediaItemsResponse {
		val json = JSONObject(response)
		val photos = mutableListOf<PhotoGooglePhotos>()
		
		val itemsArray = json.optJSONArray("mediaItems") ?: JSONArray()
		for (i in 0 until itemsArray.length()) {
			val item = parseMediaItem(itemsArray.getJSONObject(i))
			if (item != null) {
				photos.add(item)
			}
		}
		
		return MediaItemsResponse(
			photos = photos,
			nextPageToken = json.optString("nextPageToken").takeIf { it.isNotEmpty() }
		)
	}
	
	private fun parseMediaItem(json: JSONObject): PhotoGooglePhotos? {
		// Skip non-photo items
		val mimeType = json.optString("mimeType", "")
		if (!mimeType.startsWith("image/")) {
			return null
		}
		
		val metadata = json.optJSONObject("mediaMetadata")
		val width = metadata?.optString("width", "0")?.toIntOrNull() ?: 0
		val height = metadata?.optString("height", "0")?.toIntOrNull() ?: 0
		
		// Parse creation time
		val creationTime = metadata?.optString("creationTime")?.let { timeStr ->
			try {
				dateFormat.parse(timeStr)
			} catch (e: Exception) {
				Log.w(TAG, "Failed to parse creation time: $timeStr", e)
				null
			}
		} ?: Date()
		
		return PhotoGooglePhotos(
			mediaItemId = json.getString("id"),
			filename = json.optString("filename", "unknown.jpg"),
			mimeType = mimeType,
			baseUrl = json.getString("baseUrl"),
			productUrl = json.optString("productUrl", ""),
			width = width,
			height = height,
			creationTime = creationTime,
			modifiedTime = Date() // API doesn't provide modified time
		)
	}
	
	// Response data classes
	data class AlbumsResponse(
		val albums: List<GooglePhotosService.GooglePhotosAlbum>,
		val nextPageToken: String?
	)
	
	data class MediaItemsResponse(
		val photos: List<PhotoGooglePhotos>,
		val nextPageToken: String?
	)
}
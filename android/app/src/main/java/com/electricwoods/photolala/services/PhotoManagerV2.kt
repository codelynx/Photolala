package com.electricwoods.photolala.services

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import com.electricwoods.photolala.models.FileIdentityKey
import com.electricwoods.photolala.models.PhotoDigest
import com.electricwoods.photolala.models.PhotoDigestMetadata
import com.electricwoods.photolala.models.PhotoFile
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.models.PhotoS3
import com.electricwoods.photolala.utils.MD5Utils
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import timber.log.Timber
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.time.Instant
import kotlin.math.max
import kotlin.math.min

/**
 * PhotoManagerV2 - Manages two-level PhotoDigest cache architecture
 * Replaces the old PhotoManager with improved performance and deduplication
 */
class PhotoManagerV2(private val context: Context) {
	
	companion object {
		// Thumbnail configuration
		private const val THUMBNAIL_SHORT_SIDE = 256
		private const val THUMBNAIL_MAX_LONG_SIDE = 512
		private const val THUMBNAIL_QUALITY = 85
		
		// Concurrent loading configuration
		private const val MAX_CONCURRENT_LOADS = 12
		
		@Volatile
		private var INSTANCE: PhotoManagerV2? = null
		
		/**
		 * Gets singleton instance
		 */
		fun getInstance(context: Context): PhotoManagerV2 {
			return INSTANCE ?: synchronized(this) {
				INSTANCE ?: PhotoManagerV2(context.applicationContext).also {
					INSTANCE = it
				}
			}
		}
	}
	
	// Cache instances
	private val pathToMD5Cache = PathToMD5Cache.getInstance(context)
	private val photoDigestCache = PhotoDigestCache.getInstance(context)
	
	// Loading queue management
	private val loadingScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
	private val loadingChannel = Channel<LoadRequest>(Channel.UNLIMITED)
	
	init {
		// Start loading workers
		repeat(MAX_CONCURRENT_LOADS) { workerId ->
			loadingScope.launch {
				processLoadingQueue(workerId)
			}
		}
	}
	
	/**
	 * Load request data
	 */
	private data class LoadRequest(
		val uri: Uri,
		val path: String,
		val continuation: CompletableDeferred<PhotoDigest?>,
		val source: PhotoSource,
		val metadata: Map<String, Any>? = null
	)
	
	/**
	 * Photo source types
	 */
	enum class PhotoSource {
		FILE,
		MEDIA_STORE,
		S3
	}
	
	/**
	 * Gets PhotoDigest for a local file
	 */
	suspend fun getPhotoDigestForFile(file: PhotoFile): PhotoDigest? {
		val path = file.path
		val fileObj = File(path)
		
		if (!fileObj.exists()) {
			Timber.w("PhotoManagerV2: File not found: $path")
			return null
		}
		
		// Try two-level cache lookup
		return performTwoLevelCacheLookup(
			path = path,
			file = fileObj,
			uri = Uri.fromFile(fileObj),
			source = PhotoSource.FILE
		)
	}
	
	/**
	 * Gets PhotoDigest for a MediaStore photo
	 */
	suspend fun getPhotoDigestForMediaStore(photo: PhotoMediaStore): PhotoDigest? {
		val uri = Uri.parse(photo.uri)
		
		// For MediaStore, we use URI as path since we don't have file access
		// This is similar to Apple Photos approach - fast browsing without MD5
		val cacheKey = "mediastore|${photo.id}"
		
		// Check if we have a cached MD5 for this MediaStore ID
		val cachedMD5 = pathToMD5Cache.getMD5(
			FileIdentityKey(
				pathMD5 = MD5Utils.md5(cacheKey),
				fileSize = photo.size,
				modificationTimestamp = photo.dateModified / 1000
			)
		)
		
		if (cachedMD5 != null) {
			// Try to get PhotoDigest from Level 2 cache
			photoDigestCache.get(cachedMD5)?.let { return it }
		}
		
		// Need to generate thumbnail and potentially compute MD5
		return loadPhotoDigest(
			LoadRequest(
				uri = uri,
				path = cacheKey,
				continuation = CompletableDeferred(),
				source = PhotoSource.MEDIA_STORE,
				metadata = mapOf(
					"id" to photo.id,
					"displayName" to photo.displayName,
					"size" to photo.size,
					"dateModified" to photo.dateModified
				)
			)
		)
	}
	
	/**
	 * Gets PhotoDigest for an S3 photo
	 */
	suspend fun getPhotoDigestForS3(photo: PhotoS3): PhotoDigest? {
		// S3 photos already have MD5 from catalog
		val md5 = photo.md5Hash
		
		// Check Level 2 cache directly
		photoDigestCache.get(md5)?.let { return it }
		
		// Need to download thumbnail from S3
		// This would be implemented with S3DownloadService
		Timber.d("PhotoManagerV2: S3 thumbnail download not yet implemented")
		return null
	}
	
	/**
	 * Performs two-level cache lookup for local files
	 */
	private suspend fun performTwoLevelCacheLookup(
		path: String,
		file: File,
		uri: Uri,
		source: PhotoSource
	): PhotoDigest? {
		// Level 1: Check if we have MD5 for this file identity
		val fileKey = FileIdentityKey.fromPath(
			path = path,
			size = file.length(),
			modTimestamp = file.lastModified() / 1000
		)
		
		val cachedMD5 = pathToMD5Cache.getMD5(fileKey)
		
		if (cachedMD5 != null) {
			// Level 2: Try to get PhotoDigest using MD5
			photoDigestCache.get(cachedMD5)?.let { 
				Timber.d("PhotoManagerV2: Cache hit for $path")
				return it 
			}
			
			// Have MD5 but no PhotoDigest - need to generate thumbnail only
			return generatePhotoDigestWithKnownMD5(
				path = path,
				file = file,
				uri = uri,
				md5 = cachedMD5
			)
		}
		
		// No cached MD5 - need to compute MD5 and generate thumbnail
		return generatePhotoDigestWithMD5Computation(
			path = path,
			file = file,
			uri = uri,
			fileKey = fileKey
		)
	}
	
	/**
	 * Generates PhotoDigest when MD5 is already known
	 */
	private suspend fun generatePhotoDigestWithKnownMD5(
		path: String,
		file: File,
		uri: Uri,
		md5: String
	): PhotoDigest? {
		return withContext(Dispatchers.IO) {
			try {
				// Generate thumbnail
				val thumbnail = generateThumbnail(uri, path)
				
				// Create metadata
				val metadata = PhotoDigestMetadata(
					filename = file.name,
					fileSize = file.length(),
					pixelWidth = null, // Would need to extract from image
					pixelHeight = null,
					creationDate = Instant.ofEpochMilli(file.lastModified()),
					modificationTimestamp = file.lastModified() / 1000,
					exifData = extractBasicExifData(path)
				)
				
				// Create PhotoDigest
				val photoDigest = photoDigestCache.createPhotoDigest(
					md5Hash = md5,
					thumbnailBitmap = thumbnail,
					metadata = metadata
				)
				
				// Store in Level 2 cache
				photoDigestCache.put(photoDigest)
				
				Timber.d("PhotoManagerV2: Generated PhotoDigest with known MD5 for $path")
				photoDigest
			} catch (e: Exception) {
				Timber.e(e, "PhotoManagerV2: Failed to generate PhotoDigest for $path")
				null
			}
		}
	}
	
	/**
	 * Generates PhotoDigest with MD5 computation
	 */
	private suspend fun generatePhotoDigestWithMD5Computation(
		path: String,
		file: File,
		uri: Uri,
		fileKey: FileIdentityKey
	): PhotoDigest? {
		return withContext(Dispatchers.IO) {
			try {
				// Read file once for both MD5 and thumbnail
				val fileData = file.readBytes()
				
				// Compute MD5
				val md5 = MD5Utils.md5(fileData)
				
				// Store in Level 1 cache
				pathToMD5Cache.setMD5(fileKey, md5)
				
				// Generate thumbnail from data
				val bitmap = BitmapFactory.decodeByteArray(fileData, 0, fileData.size)
				val thumbnail = scaleBitmapForThumbnail(bitmap, path)
				bitmap.recycle()
				
				// Create metadata
				val metadata = PhotoDigestMetadata(
					filename = file.name,
					fileSize = file.length(),
					pixelWidth = bitmap.width,
					pixelHeight = bitmap.height,
					creationDate = Instant.ofEpochMilli(file.lastModified()),
					modificationTimestamp = file.lastModified() / 1000,
					exifData = extractBasicExifData(path)
				)
				
				// Create PhotoDigest
				val photoDigest = photoDigestCache.createPhotoDigest(
					md5Hash = md5,
					thumbnailBitmap = thumbnail,
					metadata = metadata
				)
				
				// Store in Level 2 cache
				photoDigestCache.put(photoDigest)
				
				Timber.d("PhotoManagerV2: Generated PhotoDigest with MD5 computation for $path")
				photoDigest
			} catch (e: Exception) {
				Timber.e(e, "PhotoManagerV2: Failed to generate PhotoDigest for $path")
				null
			}
		}
	}
	
	/**
	 * Generates thumbnail for a photo
	 */
	private suspend fun generateThumbnail(uri: Uri, path: String): Bitmap {
		return withContext(Dispatchers.IO) {
			// For Android Q+, use built-in thumbnail generation
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				try {
					val thumbnail = context.contentResolver.loadThumbnail(
						uri,
						Size(THUMBNAIL_SHORT_SIDE, THUMBNAIL_SHORT_SIDE),
						null
					)
					return@withContext scaleBitmapForThumbnail(thumbnail, path)
				} catch (e: Exception) {
					Timber.w(e, "PhotoManagerV2: Failed to load thumbnail using ContentResolver")
				}
			}
			
			// Fallback: Load and scale manually
			val options = BitmapFactory.Options().apply {
				inJustDecodeBounds = true
			}
			
			context.contentResolver.openInputStream(uri)?.use { input ->
				BitmapFactory.decodeStream(input, null, options)
			}
			
			// Calculate sample size
			options.inSampleSize = calculateInSampleSize(options, THUMBNAIL_SHORT_SIDE)
			options.inJustDecodeBounds = false
			
			val bitmap = context.contentResolver.openInputStream(uri)?.use { input ->
				BitmapFactory.decodeStream(input, null, options)
			} ?: throw IllegalStateException("Failed to decode bitmap")
			
			val scaled = scaleBitmapForThumbnail(bitmap, path)
			if (scaled != bitmap) {
				bitmap.recycle()
			}
			scaled
		}
	}
	
	/**
	 * Scales bitmap for thumbnail with proper orientation
	 */
	private fun scaleBitmapForThumbnail(bitmap: Bitmap, path: String): Bitmap {
		// Get EXIF orientation
		val orientation = try {
			ExifInterface(path).getAttributeInt(
				ExifInterface.TAG_ORIENTATION,
				ExifInterface.ORIENTATION_NORMAL
			)
		} catch (e: Exception) {
			ExifInterface.ORIENTATION_NORMAL
		}
		
		// Apply rotation if needed
		val rotatedBitmap = when (orientation) {
			ExifInterface.ORIENTATION_ROTATE_90 -> rotateBitmap(bitmap, 90f)
			ExifInterface.ORIENTATION_ROTATE_180 -> rotateBitmap(bitmap, 180f)
			ExifInterface.ORIENTATION_ROTATE_270 -> rotateBitmap(bitmap, 270f)
			else -> bitmap
		}
		
		// Calculate scale
		val width = rotatedBitmap.width
		val height = rotatedBitmap.height
		val shortSide = min(width, height)
		val longSide = max(width, height)
		
		val scale = THUMBNAIL_SHORT_SIDE.toFloat() / shortSide
		var scaledWidth = (width * scale).toInt()
		var scaledHeight = (height * scale).toInt()
		
		// Limit long side
		if (max(scaledWidth, scaledHeight) > THUMBNAIL_MAX_LONG_SIDE) {
			val longScale = THUMBNAIL_MAX_LONG_SIDE.toFloat() / max(scaledWidth, scaledHeight)
			scaledWidth = (scaledWidth * longScale).toInt()
			scaledHeight = (scaledHeight * longScale).toInt()
		}
		
		// Scale bitmap
		val scaledBitmap = Bitmap.createScaledBitmap(rotatedBitmap, scaledWidth, scaledHeight, true)
		
		// Clean up
		if (rotatedBitmap != bitmap && rotatedBitmap != scaledBitmap) {
			rotatedBitmap.recycle()
		}
		if (bitmap != scaledBitmap && bitmap != rotatedBitmap) {
			bitmap.recycle()
		}
		
		return scaledBitmap
	}
	
	/**
	 * Rotates bitmap by specified degrees
	 */
	private fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
		val matrix = Matrix().apply { postRotate(degrees) }
		return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
	}
	
	/**
	 * Calculates sample size for efficient bitmap loading
	 */
	private fun calculateInSampleSize(options: BitmapFactory.Options, reqSize: Int): Int {
		val height = options.outHeight
		val width = options.outWidth
		var inSampleSize = 1
		
		if (height > reqSize || width > reqSize) {
			val halfHeight = height / 2
			val halfWidth = width / 2
			
			while ((halfHeight / inSampleSize) >= reqSize && (halfWidth / inSampleSize) >= reqSize) {
				inSampleSize *= 2
			}
		}
		
		return inSampleSize
	}
	
	/**
	 * Extracts basic EXIF data
	 */
	private fun extractBasicExifData(path: String): Map<String, String>? {
		return try {
			val exif = ExifInterface(path)
			mapOf(
				"Make" to (exif.getAttribute(ExifInterface.TAG_MAKE) ?: ""),
				"Model" to (exif.getAttribute(ExifInterface.TAG_MODEL) ?: ""),
				"DateTime" to (exif.getAttribute(ExifInterface.TAG_DATETIME) ?: ""),
				"Orientation" to (exif.getAttribute(ExifInterface.TAG_ORIENTATION) ?: "1")
			).filterValues { it.isNotEmpty() }
		} catch (e: Exception) {
			null
		}
	}
	
	/**
	 * Processes loading queue
	 */
	private suspend fun processLoadingQueue(workerId: Int) {
		for (request in loadingChannel) {
			try {
				val result = loadPhotoDigest(request)
				request.continuation.complete(result)
			} catch (e: Exception) {
				Timber.e(e, "PhotoManagerV2: Worker $workerId failed to process request")
				request.continuation.completeExceptionally(e)
			}
		}
	}
	
	/**
	 * Loads PhotoDigest for a request
	 */
	private suspend fun loadPhotoDigest(request: LoadRequest): PhotoDigest? {
		// Implementation depends on source type
		return when (request.source) {
			PhotoSource.FILE -> {
				// Already handled in performTwoLevelCacheLookup
				null
			}
			PhotoSource.MEDIA_STORE -> {
				// Generate thumbnail without MD5 (like Apple Photos)
				generateMediaStoreThumbnail(request)
			}
			PhotoSource.S3 -> {
				// Download from S3
				null // TODO: Implement S3 download
			}
		}
	}
	
	/**
	 * Generates thumbnail for MediaStore photo
	 */
	private suspend fun generateMediaStoreThumbnail(request: LoadRequest): PhotoDigest? {
		return withContext(Dispatchers.IO) {
			try {
				val thumbnail = generateThumbnail(request.uri, request.path)
				
				// For now, use a temporary MD5 based on MediaStore ID
				// This will be replaced with actual MD5 when photo is starred/backed up
				val tempMD5 = "mediastore_${request.metadata?.get("id")}"
				
				val metadata = PhotoDigestMetadata(
					filename = request.metadata?.get("displayName") as? String ?: "Unknown",
					fileSize = request.metadata?.get("size") as? Long ?: 0L,
					pixelWidth = null,
					pixelHeight = null,
					creationDate = request.metadata?.get("dateModified")?.let { 
						Instant.ofEpochMilli(it as Long) 
					},
					modificationTimestamp = (request.metadata?.get("dateModified") as? Long ?: 0L) / 1000,
					exifData = null
				)
				
				val photoDigest = photoDigestCache.createPhotoDigest(
					md5Hash = tempMD5,
					thumbnailBitmap = thumbnail,
					metadata = metadata
				)
				
				// Don't cache MediaStore photos in Level 2 by default
				// Only cache when they get a real MD5 (starred/backed up)
				
				photoDigest
			} catch (e: Exception) {
				Timber.e(e, "PhotoManagerV2: Failed to generate MediaStore thumbnail")
				null
			}
		}
	}
	
	/**
	 * Clears all caches
	 */
	suspend fun clearCaches() {
		pathToMD5Cache.clear()
		photoDigestCache.clear()
	}
	
	/**
	 * Gets cache statistics
	 */
	fun getCacheStats(): CacheStats {
		val pathStats = pathToMD5Cache.getStats()
		val digestStats = photoDigestCache.getStats()
		
		return CacheStats(
			level1EntryCount = pathStats.entryCount,
			level1MemorySize = pathStats.memorySizeBytes,
			level2MemoryEntryCount = digestStats.memoryEntryCount,
			level2MemorySize = digestStats.memorySizeBytes,
			level2DiskEntryCount = digestStats.diskEntryCount,
			level2DiskSize = digestStats.diskSizeBytes
		)
	}
	
	/**
	 * Combined cache statistics
	 */
	data class CacheStats(
		val level1EntryCount: Int,
		val level1MemorySize: Long,
		val level2MemoryEntryCount: Int,
		val level2MemorySize: Long,
		val level2DiskEntryCount: Int,
		val level2DiskSize: Long
	)
}
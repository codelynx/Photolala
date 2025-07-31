package com.electricwoods.photolala.services

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import com.electricwoods.photolala.models.PhotoDigest
import com.electricwoods.photolala.models.PhotoDigestMetadata
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import timber.log.Timber
import java.io.ByteArrayOutputStream
import java.io.File
import java.time.Instant

/**
 * Level 2 Cache: Maps content MD5 to PhotoDigest (thumbnail + metadata)
 * Provides memory and disk caching with sharded storage
 */
class PhotoDigestCache(private val context: Context) {
	
	// Memory cache configuration
	companion object {
		private const val MAX_MEMORY_ITEMS = 500
		private const val MAX_MEMORY_SIZE_MB = 100
		private const val CACHE_SUBDIRECTORY = "photos"
		private const val METADATA_EXTENSION = ".json"
		private const val THUMBNAIL_EXTENSION = ".dat"
		
		@Volatile
		private var INSTANCE: PhotoDigestCache? = null
		
		/**
		 * Gets singleton instance
		 */
		fun getInstance(context: Context): PhotoDigestCache {
			return INSTANCE ?: synchronized(this) {
				INSTANCE ?: PhotoDigestCache(context.applicationContext).also {
					INSTANCE = it
				}
			}
		}
	}
	
	// Memory cache using Android's LruCache
	private val memoryCache = object : LruCache<String, PhotoDigest>(MAX_MEMORY_ITEMS) {
		override fun sizeOf(key: String, value: PhotoDigest): Int {
			// Estimate size: thumbnail data + metadata overhead
			return value.thumbnailData.size + 1024 // 1KB for metadata
		}
		
		override fun entryRemoved(evicted: Boolean, key: String, oldValue: PhotoDigest, newValue: PhotoDigest?) {
			if (evicted) {
				Timber.d("PhotoDigestCache: Evicted entry for $key")
			}
		}
	}
	
	// Mutex for disk operations
	private val diskMutex = Mutex()
	
	// JSON configuration
	private val json = Json {
		ignoreUnknownKeys = true
		prettyPrint = true
	}
	
	// Base cache directory
	private val cacheDir: File
		get() = File(context.cacheDir, CACHE_SUBDIRECTORY).also { it.mkdirs() }
	
	/**
	 * Gets PhotoDigest for MD5 hash
	 */
	suspend fun get(md5Hash: String): PhotoDigest? {
		// Check memory cache first
		memoryCache.get(md5Hash)?.let { 
			// Update last accessed time
			val updated = it.copy(lastAccessedAt = Instant.now())
			memoryCache.put(md5Hash, updated)
			return updated
		}
		
		// Load from disk
		return loadFromDisk(md5Hash)?.also {
			// Update last accessed time and store in memory
			val updated = it.copy(lastAccessedAt = Instant.now())
			memoryCache.put(md5Hash, updated)
			saveToDisk(updated) // Update disk with new access time
		}
	}
	
	/**
	 * Stores PhotoDigest
	 */
	suspend fun put(photoDigest: PhotoDigest) {
		// Store in memory cache
		memoryCache.put(photoDigest.md5Hash, photoDigest)
		
		// Store on disk
		saveToDisk(photoDigest)
	}
	
	/**
	 * Removes PhotoDigest
	 */
	suspend fun remove(md5Hash: String) {
		// Remove from memory cache
		memoryCache.remove(md5Hash)
		
		// Remove from disk
		deleteFromDisk(md5Hash)
	}
	
	/**
	 * Clears all caches
	 */
	suspend fun clear() {
		// Clear memory cache
		memoryCache.evictAll()
		
		// Clear disk cache
		withContext(Dispatchers.IO) {
			diskMutex.withLock {
				cacheDir.deleteRecursively()
				cacheDir.mkdirs()
			}
		}
	}
	
	/**
	 * Gets cache statistics
	 */
	fun getStats(): CacheStats {
		val diskSize = calculateDiskSize()
		return CacheStats(
			memoryEntryCount = memoryCache.size(),
			memoryMaxCount = memoryCache.maxSize(),
			memorySizeBytes = memoryCache.size() * 50 * 1024L, // Rough estimate
			diskSizeBytes = diskSize,
			diskEntryCount = countDiskEntries()
		)
	}
	
	/**
	 * Creates PhotoDigest from raw data
	 */
	suspend fun createPhotoDigest(
		md5Hash: String,
		thumbnailBitmap: Bitmap,
		metadata: PhotoDigestMetadata
	): PhotoDigest {
		// Convert bitmap to byte array
		val thumbnailData = withContext(Dispatchers.IO) {
			ByteArrayOutputStream().use { stream ->
				thumbnailBitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
				stream.toByteArray()
			}
		}
		
		return PhotoDigest(
			md5Hash = md5Hash,
			thumbnailData = thumbnailData,
			metadata = metadata,
			createdAt = Instant.now(),
			lastAccessedAt = Instant.now()
		)
	}
	
	/**
	 * Gets sharded directory for MD5 hash
	 */
	private fun getShardedDir(md5Hash: String): File {
		val shard = md5Hash.take(2)
		return File(cacheDir, shard).also { it.mkdirs() }
	}
	
	/**
	 * Loads PhotoDigest from disk
	 */
	private suspend fun loadFromDisk(md5Hash: String): PhotoDigest? {
		return withContext(Dispatchers.IO) {
			diskMutex.withLock {
				try {
					val dir = getShardedDir(md5Hash)
					val metadataFile = File(dir, "$md5Hash$METADATA_EXTENSION")
					val thumbnailFile = File(dir, "$md5Hash$THUMBNAIL_EXTENSION")
					
					if (!metadataFile.exists() || !thumbnailFile.exists()) {
						return@withLock null
					}
					
					// Read metadata
					val metadataJson = metadataFile.readText()
					val metadata = json.decodeFromString<PhotoDigestDiskData>(metadataJson)
					
					// Read thumbnail data
					val thumbnailData = thumbnailFile.readBytes()
					
					// Create PhotoDigest
					PhotoDigest(
						md5Hash = md5Hash,
						thumbnailData = thumbnailData,
						metadata = metadata.metadata,
						createdAt = metadata.createdAt,
						lastAccessedAt = metadata.lastAccessedAt
					)
				} catch (e: Exception) {
					Timber.e(e, "PhotoDigestCache: Failed to load from disk: $md5Hash")
					null
				}
			}
		}
	}
	
	/**
	 * Saves PhotoDigest to disk
	 */
	private suspend fun saveToDisk(photoDigest: PhotoDigest) {
		withContext(Dispatchers.IO) {
			diskMutex.withLock {
				try {
					val dir = getShardedDir(photoDigest.md5Hash)
					val metadataFile = File(dir, "${photoDigest.md5Hash}$METADATA_EXTENSION")
					val thumbnailFile = File(dir, "${photoDigest.md5Hash}$THUMBNAIL_EXTENSION")
					
					// Save metadata
					val diskData = PhotoDigestDiskData(
						version = 1,
						md5Hash = photoDigest.md5Hash,
						metadata = photoDigest.metadata,
						createdAt = photoDigest.createdAt,
						lastAccessedAt = photoDigest.lastAccessedAt
					)
					val metadataJson = json.encodeToString(diskData)
					metadataFile.writeText(metadataJson)
					
					// Save thumbnail data
					thumbnailFile.writeBytes(photoDigest.thumbnailData)
					
					Timber.d("PhotoDigestCache: Saved to disk: ${photoDigest.md5Hash}")
				} catch (e: Exception) {
					Timber.e(e, "PhotoDigestCache: Failed to save to disk: ${photoDigest.md5Hash}")
				}
			}
		}
	}
	
	/**
	 * Deletes PhotoDigest from disk
	 */
	private suspend fun deleteFromDisk(md5Hash: String) {
		withContext(Dispatchers.IO) {
			diskMutex.withLock {
				try {
					val dir = getShardedDir(md5Hash)
					val metadataFile = File(dir, "$md5Hash$METADATA_EXTENSION")
					val thumbnailFile = File(dir, "$md5Hash$THUMBNAIL_EXTENSION")
					
					metadataFile.delete()
					thumbnailFile.delete()
					
					Timber.d("PhotoDigestCache: Deleted from disk: $md5Hash")
				} catch (e: Exception) {
					Timber.e(e, "PhotoDigestCache: Failed to delete from disk: $md5Hash")
				}
			}
		}
	}
	
	/**
	 * Calculates total disk cache size
	 */
	private fun calculateDiskSize(): Long {
		var totalSize = 0L
		cacheDir.walkTopDown().forEach { file ->
			if (file.isFile) {
				totalSize += file.length()
			}
		}
		return totalSize
	}
	
	/**
	 * Counts disk cache entries
	 */
	private fun countDiskEntries(): Int {
		var count = 0
		cacheDir.walkTopDown().forEach { file ->
			if (file.isFile && file.extension == "json") {
				count++
			}
		}
		return count
	}
	
	/**
	 * Cache statistics
	 */
	data class CacheStats(
		val memoryEntryCount: Int,
		val memoryMaxCount: Int,
		val memorySizeBytes: Long,
		val diskSizeBytes: Long,
		val diskEntryCount: Int
	)
	
	/**
	 * Disk storage format for PhotoDigest metadata
	 */
	@kotlinx.serialization.Serializable
	private data class PhotoDigestDiskData(
		val version: Int,
		val md5Hash: String,
		val metadata: PhotoDigestMetadata,
		@kotlinx.serialization.Serializable(with = com.electricwoods.photolala.models.InstantSerializer::class)
		val createdAt: Instant,
		@kotlinx.serialization.Serializable(with = com.electricwoods.photolala.models.InstantSerializer::class)
		val lastAccessedAt: Instant
	)
}
package com.electricwoods.photolala.services

import android.content.Context
import com.electricwoods.photolala.models.FileIdentityKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import timber.log.Timber
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * Level 1 Cache: Maps file identity (path+size+timestamp) to content MD5
 * Prevents redundant MD5 computation for unchanged files
 */
class PathToMD5Cache(private val context: Context) {
	
	// In-memory cache
	private val memoryCache = ConcurrentHashMap<String, String>()
	
	// Mutex for disk operations
	private val diskMutex = Mutex()
	
	// JSON configuration
	private val json = Json {
		ignoreUnknownKeys = true
		prettyPrint = true
	}
	
	// Cache file location
	private val cacheFile: File
		get() = File(context.cacheDir, "path-to-md5-cache.json")
	
	init {
		// Load cache from disk on initialization
		loadFromDisk()
	}
	
	/**
	 * Gets MD5 for a file identity, returns null if not cached
	 */
	suspend fun getMD5(key: FileIdentityKey): String? {
		return memoryCache[key.cacheKey]
	}
	
	/**
	 * Gets MD5 for a file path, validating against current file attributes
	 */
	suspend fun getMD5ForPath(path: String, file: File): String? {
		if (!file.exists()) return null
		
		val key = FileIdentityKey.fromPath(
			path = path,
			size = file.length(),
			modTimestamp = file.lastModified() / 1000 // Convert to seconds
		)
		
		return getMD5(key)
	}
	
	/**
	 * Sets MD5 for a file identity
	 */
	suspend fun setMD5(key: FileIdentityKey, md5: String) {
		memoryCache[key.cacheKey] = md5
		saveToDisk()
	}
	
	/**
	 * Sets MD5 for a file path with current attributes
	 */
	suspend fun setMD5ForPath(path: String, file: File, md5: String) {
		if (!file.exists()) return
		
		val key = FileIdentityKey.fromPath(
			path = path,
			size = file.length(),
			modTimestamp = file.lastModified() / 1000 // Convert to seconds
		)
		
		setMD5(key, md5)
	}
	
	/**
	 * Removes entry for a file identity
	 */
	suspend fun remove(key: FileIdentityKey) {
		memoryCache.remove(key.cacheKey)
		saveToDisk()
	}
	
	/**
	 * Clears all cache entries
	 */
	suspend fun clear() {
		memoryCache.clear()
		saveToDisk()
	}
	
	/**
	 * Gets cache statistics
	 */
	fun getStats(): CacheStats {
		return CacheStats(
			entryCount = memoryCache.size,
			memorySizeBytes = estimateMemorySize()
		)
	}
	
	/**
	 * Loads cache from disk
	 */
	private fun loadFromDisk() {
		try {
			if (!cacheFile.exists()) return
			
			val cacheData = cacheFile.readText()
			val entries = json.decodeFromString<PathToMD5CacheData>(cacheData)
			
			memoryCache.clear()
			memoryCache.putAll(entries.entries)
			
			Timber.d("PathToMD5Cache: Loaded ${entries.entries.size} entries from disk")
		} catch (e: Exception) {
			Timber.e(e, "PathToMD5Cache: Failed to load from disk")
		}
	}
	
	/**
	 * Saves cache to disk
	 */
	private suspend fun saveToDisk() {
		withContext(Dispatchers.IO) {
			diskMutex.withLock {
				try {
					val cacheData = PathToMD5CacheData(
						version = 1,
						entries = memoryCache.toMap()
					)
					
					val jsonString = json.encodeToString(cacheData)
					cacheFile.writeText(jsonString)
					
					Timber.d("PathToMD5Cache: Saved ${memoryCache.size} entries to disk")
				} catch (e: Exception) {
					Timber.e(e, "PathToMD5Cache: Failed to save to disk")
				}
			}
		}
	}
	
	/**
	 * Estimates memory usage
	 */
	private fun estimateMemorySize(): Long {
		// Rough estimate: average key length (64) + MD5 length (32) + overhead (32) = 128 bytes per entry
		return memoryCache.size * 128L
	}
	
	/**
	 * Cache statistics
	 */
	data class CacheStats(
		val entryCount: Int,
		val memorySizeBytes: Long
	)
	
	/**
	 * Serializable cache data structure
	 */
	@Serializable
	private data class PathToMD5CacheData(
		val version: Int,
		val entries: Map<String, String>
	)
	
	companion object {
		@Volatile
		private var INSTANCE: PathToMD5Cache? = null
		
		/**
		 * Gets singleton instance
		 */
		fun getInstance(context: Context): PathToMD5Cache {
			return INSTANCE ?: synchronized(this) {
				INSTANCE ?: PathToMD5Cache(context.applicationContext).also {
					INSTANCE = it
				}
			}
		}
	}
}
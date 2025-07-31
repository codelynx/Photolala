package com.electricwoods.photolala.services

import android.util.Log
import com.electricwoods.photolala.models.PhotoMediaStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Service for managing the photo catalog that syncs with S3
 * Matches the iOS PhotolalaCatalogServiceV2 implementation
 */
@Singleton
class CatalogService @Inject constructor(
	private val s3Service: S3Service
) {
	companion object {
		private const val TAG = "CatalogService"
		private const val CATALOG_FILENAME = "catalog.json"
		private const val CSV_HEADER = "md5,filename,size,photodate,modified,width,height,applephotoid"
		private val dateFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
			timeZone = TimeZone.getTimeZone("UTC")
		}
	}
	
	data class CatalogEntry(
		val md5: String,
		val filename: String,
		val size: Long,
		val photoDate: Date,
		val modifiedDate: Date,
		val width: Int,
		val height: Int,
		val applePhotoId: String? = null
	) {
		fun toCSVLine(): String {
			val photodateStr = dateFormatter.format(photoDate)
			val modifiedStr = dateFormatter.format(modifiedDate)
			val appleId = applePhotoId ?: ""
			return "$md5,$filename,$size,$photodateStr,$modifiedStr,$width,$height,$appleId"
		}
		
		companion object {
			fun fromCSVLine(line: String): CatalogEntry? {
				val parts = line.split(",")
				if (parts.size < 7) return null
				
				return try {
					CatalogEntry(
						md5 = parts[0],
						filename = parts[1],
						size = parts[2].toLong(),
						photoDate = dateFormatter.parse(parts[3]) ?: Date(),
						modifiedDate = dateFormatter.parse(parts[4]) ?: Date(),
						width = parts[5].toInt(),
						height = parts[6].toInt(),
						applePhotoId = parts.getOrNull(7)?.ifEmpty { null }
					)
				} catch (e: Exception) {
					Log.e(TAG, "Failed to parse CSV line: $line", e)
					null
				}
			}
		}
	}
	
	/**
	 * Create an empty catalog for a new user
	 */
	suspend fun createEmptyCatalog(userId: String): Result<Unit> = withContext(Dispatchers.IO) {
		try {
			// Create catalog with just the header
			val catalogContent = CSV_HEADER
			val key = "$userId/$CATALOG_FILENAME"
			
			// Upload to S3
			val result = s3Service.uploadData(catalogContent.toByteArray(), key, "text/csv")
			
			if (result.isSuccess) {
				Log.d(TAG, "Created empty catalog for user: $userId")
				Result.success(Unit)
			} else {
				Result.failure(result.exceptionOrNull() ?: Exception("Failed to upload catalog"))
			}
		} catch (e: Exception) {
			Log.e(TAG, "Failed to create empty catalog", e)
			Result.failure(e)
		}
	}
	
	/**
	 * Download and parse the catalog from S3
	 */
	suspend fun downloadCatalog(userId: String): Result<List<CatalogEntry>> = withContext(Dispatchers.IO) {
		try {
			val key = "$userId/$CATALOG_FILENAME"
			val result = s3Service.downloadData(key)
			
			if (result.isSuccess) {
				val data = result.getOrNull() ?: return@withContext Result.success(emptyList())
				val content = String(data)
				val entries = parseCatalogCSV(content)
				Result.success(entries)
			} else {
				// If catalog doesn't exist, return empty list
				Result.success(emptyList())
			}
		} catch (e: Exception) {
			Log.e(TAG, "Failed to download catalog", e)
			Result.failure(e)
		}
	}
	
	/**
	 * Add a new photo entry to the catalog
	 */
	suspend fun addPhotoToCatalog(
		userId: String,
		photo: PhotoMediaStore,
		md5: String,
		width: Int,
		height: Int
	): Result<Unit> = withContext(Dispatchers.IO) {
		try {
			// Download current catalog
			val currentEntries = downloadCatalog(userId).getOrDefault(emptyList()).toMutableList()
			
			// Check if already exists
			if (currentEntries.any { it.md5 == md5 }) {
				Log.d(TAG, "Photo already in catalog: $md5")
				return@withContext Result.success(Unit)
			}
			
			// Add new entry
			val newEntry = CatalogEntry(
				md5 = md5,
				filename = photo.displayName,
				size = photo.fileSize ?: 0L,
				photoDate = photo.creationDate ?: Date(),
				modifiedDate = photo.modificationDate ?: Date(),
				width = width,
				height = height
			)
			currentEntries.add(newEntry)
			
			// Upload updated catalog
			uploadCatalog(userId, currentEntries)
		} catch (e: Exception) {
			Log.e(TAG, "Failed to add photo to catalog", e)
			Result.failure(e)
		}
	}
	
	/**
	 * Upload the catalog to S3
	 */
	private suspend fun uploadCatalog(userId: String, entries: List<CatalogEntry>): Result<Unit> {
		return try {
			// Build CSV content
			val csvLines = mutableListOf(CSV_HEADER)
			entries.forEach { entry ->
				csvLines.add(entry.toCSVLine())
			}
			val content = csvLines.joinToString("\n")
			
			// Upload to S3
			val key = "$userId/$CATALOG_FILENAME"
			val result = s3Service.uploadData(content.toByteArray(), key, "text/csv")
			
			if (result.isSuccess) {
				Log.d(TAG, "Updated catalog with ${entries.size} entries")
				Result.success(Unit)
			} else {
				Result.failure(result.exceptionOrNull() ?: Exception("Failed to upload catalog"))
			}
		} catch (e: Exception) {
			Log.e(TAG, "Failed to upload catalog", e)
			Result.failure(e)
		}
	}
	
	/**
	 * Parse CSV catalog content
	 */
	private fun parseCatalogCSV(content: String): List<CatalogEntry> {
		val lines = content.lines()
		if (lines.isEmpty()) return emptyList()
		
		// Skip header line
		return lines.drop(1)
			.filter { it.isNotBlank() }
			.mapNotNull { CatalogEntry.fromCSVLine(it) }
	}
}
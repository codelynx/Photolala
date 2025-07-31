package com.electricwoods.photolala.services

import com.amazonaws.services.s3.AmazonS3Client
import com.amazonaws.services.s3.model.ListObjectsV2Request
import com.amazonaws.services.s3.model.S3ObjectSummary
import com.electricwoods.photolala.models.ArchiveStatus
import com.electricwoods.photolala.models.PhotoS3
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.withContext
import android.util.Log
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Provider for fetching and managing photos stored in S3
 * Similar to iOS S3PhotoProvider
 */
@Singleton
class S3PhotoProvider @Inject constructor(
    private val s3Client: AmazonS3Client,
    private val s3Service: S3Service,
    private val identityManager: IdentityManager
) {
    companion object {
        private const val BUCKET_NAME = "photolala"
        private const val PHOTOS_PREFIX = "photos/"
        private const val THUMBNAILS_PREFIX = "thumbnails/"
        private const val CATALOG_KEY = "catalog.json"
        private const val PAGE_SIZE = 100
    }
    
    /**
     * Get all photos from S3 for the current user
     * @return Flow of S3 photos
     */
    suspend fun getPhotos(): Flow<List<PhotoS3>> = flow {
        val userId = identityManager.currentUser.value?.serviceUserID
            ?: throw IllegalStateException("User not authenticated")
        
        val photos = loadPhotosFromS3(userId)
        emit(photos)
    }
    
    /**
     * Load photos from S3 catalog
     */
    private suspend fun loadPhotosFromS3(userId: String): List<PhotoS3> = withContext(Dispatchers.IO) {
        val photos = mutableListOf<PhotoS3>()
        
        try {
            // First, try to load catalog for faster access
            val catalogKey = "$userId/catalog.json"
            val catalogData = s3Service.downloadData(catalogKey)
            
            if (catalogData.isSuccess) {
                // Parse catalog and create PhotoS3 objects
                // TODO: Implement catalog parsing
                return@withContext parseCatalog(catalogData.getOrNull(), userId)
            }
            
            // Fallback: List objects directly from S3
            val userPrefix = "users/$userId/$PHOTOS_PREFIX"
            var continuationToken: String? = null
            
            do {
                val listRequest = ListObjectsV2Request()
                    .withBucketName(BUCKET_NAME)
                    .withPrefix(userPrefix)
                    .withMaxKeys(PAGE_SIZE)
                
                if (continuationToken != null) {
                    listRequest.continuationToken = continuationToken
                }
                
                val result = s3Client.listObjectsV2(listRequest)
                
                Log.d("S3PhotoProvider", "ListObjectsV2 returned ${result.objectSummaries.size} objects for prefix: $userPrefix")
                
                result.objectSummaries.forEach { summary ->
                    Log.d("S3PhotoProvider", "Found object: ${summary.key} (size: ${summary.size})")
                    if (summary.key.endsWith(".jpg", true) || 
                        summary.key.endsWith(".jpeg", true) || 
                        summary.key.endsWith(".png", true)) {
                        
                        photos.add(createPhotoS3FromSummary(summary, userId))
                        Log.d("S3PhotoProvider", "Added photo: ${summary.key}")
                    }
                }
                
                continuationToken = result.nextContinuationToken
            } while (continuationToken != null)
            
        } catch (e: Exception) {
            // Handle errors - return empty list or cached data
            Log.e("S3PhotoProvider", "Error listing photos", e)
            e.printStackTrace()
        }
        
        Log.d("S3PhotoProvider", "Returning ${photos.size} photos from S3")
        return@withContext photos.sortedByDescending { it.creationDate }
    }
    
    /**
     * Create PhotoS3 object from S3ObjectSummary
     */
    private fun createPhotoS3FromSummary(summary: S3ObjectSummary, userId: String): PhotoS3 {
        val filename = summary.key.substringAfterLast("/")
        val photoKey = summary.key
        val thumbnailKey = photoKey.replace("/$PHOTOS_PREFIX", "/$THUMBNAILS_PREFIX")
            .replace(Regex("\\.(jpg|jpeg|png)$", RegexOption.IGNORE_CASE), "_thumb.jpg")
        
        return PhotoS3(
            id = summary.eTag ?: photoKey, // Use ETag as ID if available
            photoKey = photoKey,
            thumbnailKey = thumbnailKey,
            filename = filename,
            fileSize = summary.size,
            width = null, // Will be loaded from metadata or EXIF
            height = null,
            creationDate = summary.lastModified ?: Date(),
            modificationDate = summary.lastModified,
            md5Hash = summary.eTag?.replace("\"", ""), // ETag is MD5 for normal uploads
            archiveStatus = ArchiveStatus.STANDARD,
            bucketName = BUCKET_NAME
        )
    }
    
    /**
     * Parse catalog CSV to create PhotoS3 objects
     * Format: md5,filename,size,photodate,modified,width,height,applephotoid
     */
    private fun parseCatalog(catalogData: ByteArray?, userId: String): List<PhotoS3> {
        if (catalogData == null) return emptyList()
        
        return try {
            val content = String(catalogData)
            val lines = content.lines()
            
            if (lines.isEmpty()) return emptyList()
            
            // Skip header line and parse remaining entries
            lines.drop(1)
                .filter { it.isNotBlank() }
                .mapNotNull { line ->
                    parseCatalogLine(line, userId)
                }
        } catch (e: Exception) {
            Log.e("S3PhotoProvider", "Failed to parse catalog", e)
            emptyList()
        }
    }
    
    /**
     * Parse a single catalog CSV line
     */
    private fun parseCatalogLine(line: String, userId: String): PhotoS3? {
        return try {
            val parts = line.split(",")
            if (parts.size < 7) return null
            
            val md5 = parts[0]
            val filename = parts[1]
            val size = parts[2].toLongOrNull() ?: 0L
            val width = parts[5].toIntOrNull() ?: 0
            val height = parts[6].toIntOrNull() ?: 0
            
            PhotoS3(
                id = md5,
                photoKey = "users/$userId/photos/$md5.jpg",
                thumbnailKey = "users/$userId/thumbnails/$md5.jpg",
                filename = filename,
                fileSize = size,
                width = width,
                height = height,
                creationDate = Date(),
                modificationDate = Date(),
                md5Hash = md5,
                archiveStatus = ArchiveStatus.STANDARD
            )
        } catch (e: Exception) {
            Log.e("S3PhotoProvider", "Failed to parse catalog line: $line", e)
            null
        }
    }
    
    /**
     * Load thumbnail for an S3 photo
     */
    suspend fun loadThumbnail(photo: PhotoS3): ByteArray? = withContext(Dispatchers.IO) {
        return@withContext try {
            // First try to load from thumbnail key if available
            if (!photo.thumbnailKey.isNullOrEmpty()) {
                val result = s3Service.downloadData(photo.thumbnailKey)
                if (result.isSuccess) {
                    return@withContext result.getOrNull()
                }
            }
            
            // Fallback: Download full image and generate thumbnail
            // In production, this should generate and cache thumbnails
            val fullImageResult = s3Service.downloadData(photo.photoKey)
            fullImageResult.getOrNull()
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    /**
     * Load full image data for an S3 photo
     */
    suspend fun loadImageData(photo: PhotoS3): ByteArray = withContext(Dispatchers.IO) {
        val result = s3Service.downloadData(photo.photoKey)
        return@withContext result.getOrThrow()
    }
    
    /**
     * Refresh photos from S3
     */
    suspend fun refresh() {
        // Force reload from S3
        // This will trigger a new emission in the flow
    }
    
    /**
     * Search photos by filename
     */
    suspend fun searchPhotos(query: String): List<PhotoS3> {
        val allPhotos = getPhotos().collectFirst()
        return allPhotos?.filter { photo ->
            photo.filename.contains(query, ignoreCase = true)
        } ?: emptyList()
    }
}

// Extension function to collect just the first emission from flow
private suspend fun <T> Flow<T>.collectFirst(): T? {
    var result: T? = null
    try {
        this.collect { value ->
            result = value
            throw FirstEmissionCollectedException()
        }
    } catch (e: FirstEmissionCollectedException) {
        // Expected - we got our first emission
    }
    return result
}

private class FirstEmissionCollectedException : Exception()
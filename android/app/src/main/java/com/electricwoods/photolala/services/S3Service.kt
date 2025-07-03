package com.electricwoods.photolala.services

import android.content.Context
import android.net.Uri
import com.amazonaws.services.s3.AmazonS3Client
import com.amazonaws.services.s3.model.ObjectMetadata
import com.amazonaws.services.s3.model.PutObjectRequest
import com.amazonaws.services.s3.model.S3Object
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileInputStream
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class S3Service @Inject constructor(
    @ApplicationContext private val context: Context,
    private val s3Client: AmazonS3Client
) {
    companion object {
        private const val BUCKET_NAME = "photolala" // Update with your actual bucket name
        private const val PHOTOS_PREFIX = "photos/"
    }
    
    /**
     * Upload a photo to S3
     * @param uri The URI of the photo to upload
     * @param key The S3 key (path) for the photo
     * @return The S3 URL of the uploaded photo
     */
    suspend fun uploadPhoto(uri: Uri, key: String): String = withContext(Dispatchers.IO) {
        // Create a temporary file from the URI
        val tempFile = createTempFileFromUri(uri)
        
        try {
            // Prepare metadata
            val metadata = ObjectMetadata().apply {
                contentType = context.contentResolver.getType(uri) ?: "image/jpeg"
                contentLength = tempFile.length()
            }
            
            // Create put request
            val putRequest = PutObjectRequest(
                BUCKET_NAME,
                "$PHOTOS_PREFIX$key",
                FileInputStream(tempFile),
                metadata
            )
            
            // Upload to S3
            s3Client.putObject(putRequest)
            
            // Return the S3 URL
            return@withContext "https://$BUCKET_NAME.s3.amazonaws.com/$PHOTOS_PREFIX$key"
        } finally {
            // Clean up temp file
            tempFile.delete()
        }
    }
    
    /**
     * List photos in S3 bucket
     * @param prefix Optional prefix to filter photos
     * @return List of S3 object keys
     */
    suspend fun listPhotos(prefix: String? = null): List<String> = withContext(Dispatchers.IO) {
        val listRequest = s3Client.listObjects(
            BUCKET_NAME,
            "$PHOTOS_PREFIX${prefix ?: ""}"
        )
        
        return@withContext listRequest.objectSummaries.map { it.key }
    }
    
    /**
     * Delete a photo from S3
     * @param key The S3 key of the photo to delete
     */
    suspend fun deletePhoto(key: String) = withContext(Dispatchers.IO) {
        s3Client.deleteObject(BUCKET_NAME, key)
    }
    
    /**
     * Get a pre-signed URL for downloading a photo
     * @param key The S3 key of the photo
     * @param expirationHours How long the URL should be valid (default: 24 hours)
     * @return Pre-signed URL
     */
    suspend fun getPreSignedUrl(key: String, expirationHours: Int = 24): String = withContext(Dispatchers.IO) {
        val expiration = java.util.Date(System.currentTimeMillis() + (expirationHours * 3600 * 1000))
        val url = s3Client.generatePresignedUrl(BUCKET_NAME, key, expiration)
        return@withContext url.toString()
    }
    
    private fun createTempFileFromUri(uri: Uri): File {
        val tempFile = File.createTempFile("upload_", ".jpg", context.cacheDir)
        context.contentResolver.openInputStream(uri)?.use { input ->
            tempFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return tempFile
    }
    
    /**
     * Upload raw data to S3
     * @param data The byte array to upload
     * @param key The S3 key (path) for the data
     */
    suspend fun uploadData(data: ByteArray, key: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val metadata = ObjectMetadata().apply {
                contentLength = data.size.toLong()
                contentType = "text/plain"
            }
            
            val putRequest = PutObjectRequest(
                BUCKET_NAME,
                key,
                ByteArrayInputStream(data),
                metadata
            )
            
            s3Client.putObject(putRequest)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Download raw data from S3
     * @param key The S3 key (path) for the data
     * @return The downloaded data as byte array
     */
    suspend fun downloadData(key: String): Result<ByteArray> = withContext(Dispatchers.IO) {
        try {
            val s3Object: S3Object = s3Client.getObject(BUCKET_NAME, key)
            val data = s3Object.objectContent.use { stream ->
                stream.readBytes()
            }
            Result.success(data)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * Create a folder (by creating an empty object with trailing slash)
     * @param folderPath The folder path to create (should end with /)
     */
    suspend fun createFolder(folderPath: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val metadata = ObjectMetadata().apply {
                contentLength = 0
            }
            
            val putRequest = PutObjectRequest(
                BUCKET_NAME,
                folderPath,
                ByteArrayInputStream(ByteArray(0)),
                metadata
            )
            
            s3Client.putObject(putRequest)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
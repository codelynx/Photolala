package com.electricwoods.photolala.services

import android.content.Context
import android.net.Uri
import android.util.Log
import com.electricwoods.photolala.data.local.dao.PhotoDao
import com.electricwoods.photolala.data.local.entities.PhotoEntity
import com.electricwoods.photolala.di.IoDispatcher
import com.electricwoods.photolala.models.BackupState
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.repositories.PhotoRepository
import com.electricwoods.photolala.utils.MD5Calculator
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.io.File
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages the backup queue for photos marked with stars
 * Similar to iOS BackupQueueManager
 */
@Singleton
class BackupQueueManager @Inject constructor(
	@ApplicationContext private val context: Context,
	private val s3Service: S3Service,
	private val photoRepository: PhotoRepository,
	private val identityManager: IdentityManager,
	private val mediaStoreService: MediaStoreService,
	@IoDispatcher private val ioDispatcher: CoroutineDispatcher
) {
	companion object {
		private const val TAG = "BackupQueueManager"
		private const val BATCH_SIZE = 10
		private const val INACTIVITY_DELAY_MS = 5 * 60 * 1000L // 5 minutes
		private const val RETRY_DELAY_MS = 30 * 1000L // 30 seconds
	}
	
	// State flows
	private val _isUploading = MutableStateFlow(false)
	val isUploading: StateFlow<Boolean> = _isUploading.asStateFlow()
	
	private val _uploadProgress = MutableStateFlow(0f)
	val uploadProgress: StateFlow<Float> = _uploadProgress.asStateFlow()
	
	private val _currentUploadingPhoto = MutableStateFlow<String?>(null)
	val currentUploadingPhoto: StateFlow<String?> = _currentUploadingPhoto.asStateFlow()
	
	private val _uploadedCount = MutableStateFlow(0)
	val uploadedCount: StateFlow<Int> = _uploadedCount.asStateFlow()
	
	private val _failedUploads = MutableStateFlow<Map<String, String>>(emptyMap())
	val failedUploads: StateFlow<Map<String, String>> = _failedUploads.asStateFlow()
	
	// Coroutine management
	private val scope = CoroutineScope(SupervisorJob() + ioDispatcher)
	private var uploadJob: Job? = null
	private var inactivityTimer: Job? = null
	
	init {
		// Monitor starred photos and start backup after inactivity
		scope.launch {
			photoRepository.getStarredPhotos()
				.distinctUntilChanged()
				.collect { starredPhotos ->
					Log.d(TAG, "Starred photos changed: ${starredPhotos.size} photos")
					resetInactivityTimer()
				}
		}
	}
	
	/**
	 * Start backup process immediately
	 */
	fun startBackup() {
		Log.d(TAG, "Manual backup started")
		uploadJob?.cancel()
		uploadJob = scope.launch {
			performBackup()
		}
	}
	
	/**
	 * Stop backup process
	 */
	fun stopBackup() {
		Log.d(TAG, "Backup stopped")
		uploadJob?.cancel()
		uploadJob = null
		_isUploading.value = false
		_uploadProgress.value = 0f
		_currentUploadingPhoto.value = null
	}
	
	/**
	 * Reset the inactivity timer
	 */
	private fun resetInactivityTimer() {
		inactivityTimer?.cancel()
		inactivityTimer = scope.launch {
			delay(INACTIVITY_DELAY_MS)
			Log.d(TAG, "Inactivity timer expired, starting auto backup")
			performBackup()
		}
	}
	
	/**
	 * Perform the actual backup
	 */
	private suspend fun performBackup() = withContext(ioDispatcher) {
		// Check if user is signed in
		val currentUser = identityManager.currentUser.value
		if (currentUser == null) {
			Log.w(TAG, "Cannot backup: user not signed in")
			return@withContext
		}
		
		_isUploading.value = true
		_uploadedCount.value = 0
		_failedUploads.value = emptyMap()
		
		try {
			// Get all starred photos that haven't been backed up
			val starredPhotos = photoRepository.getStarredPhotos().first()
			val photosToBackup = starredPhotos.filter { 
				it.backupState != BackupState.UPLOADED 
			}
			
			Log.d(TAG, "Found ${photosToBackup.size} photos to backup")
			
			if (photosToBackup.isEmpty()) {
				Log.d(TAG, "No photos to backup")
				return@withContext
			}
			
			// Process photos in batches
			photosToBackup.chunked(BATCH_SIZE).forEachIndexed { batchIndex, batch ->
				Log.d(TAG, "Processing batch ${batchIndex + 1} with ${batch.size} photos")
				
				batch.forEachIndexed { photoIndex, photoEntity ->
					val overallProgress = (batchIndex * BATCH_SIZE + photoIndex).toFloat() / photosToBackup.size
					_uploadProgress.value = overallProgress
					_currentUploadingPhoto.value = photoEntity.filename
					
					try {
						uploadPhoto(photoEntity, currentUser.serviceUserID)
						_uploadedCount.value = _uploadedCount.value + 1
					} catch (e: Exception) {
						Log.e(TAG, "Failed to upload ${photoEntity.filename}", e)
						_failedUploads.value = _failedUploads.value + (photoEntity.id to (e.message ?: "Unknown error"))
					}
					
					// Check if cancelled
					if (!isActive) {
						Log.d(TAG, "Backup cancelled")
						return@withContext
					}
				}
			}
			
			Log.d(TAG, "Backup completed: ${_uploadedCount.value} uploaded, ${_failedUploads.value.size} failed")
			
		} catch (e: Exception) {
			Log.e(TAG, "Backup failed", e)
		} finally {
			_isUploading.value = false
			_uploadProgress.value = 0f
			_currentUploadingPhoto.value = null
		}
	}
	
	/**
	 * Upload a single photo
	 */
	private suspend fun uploadPhoto(photoEntity: PhotoEntity, userId: String) {
		Log.d(TAG, "Uploading photo: ${photoEntity.filename}")
		
		// Get the photo from MediaStore
		val uri = photoEntity.uri?.let { Uri.parse(it) } ?: throw Exception("Photo URI is null")
		
		// Calculate MD5 if not already done
		val md5Hash = photoEntity.md5Hash ?: calculateMD5(uri)
		
		// Generate S3 key
		val photoKey = "users/$userId/photos/$md5Hash.jpg"
		val thumbnailKey = "users/$userId/thumbnails/$md5Hash.jpg"
		
		// Check if already exists in S3
		if (checkIfExists(photoKey)) {
			Log.d(TAG, "Photo already exists in S3: $photoKey")
			// Update local database
			updatePhotoBackupState(photoEntity.id, BackupState.UPLOADED, photoKey, thumbnailKey)
			return
		}
		
		// Upload full size photo
		val photoUrl = s3Service.uploadPhoto(uri, photoKey)
		Log.d(TAG, "Uploaded photo to: $photoUrl")
		
		// Generate and upload thumbnail
		// TODO: Implement thumbnail generation
		// For now, we'll skip thumbnail upload
		
		// Update local database
		updatePhotoBackupState(photoEntity.id, BackupState.UPLOADED, photoKey, thumbnailKey)
	}
	
	/**
	 * Calculate MD5 hash for a photo
	 */
	private suspend fun calculateMD5(uri: Uri): String = withContext(Dispatchers.IO) {
		context.contentResolver.openInputStream(uri)?.use { input ->
			MD5Calculator.calculate(input)
		} ?: throw Exception("Cannot open photo for MD5 calculation")
	}
	
	/**
	 * Check if a file exists in S3
	 */
	private suspend fun checkIfExists(key: String): Boolean {
		return try {
			s3Service.downloadData(key).isSuccess
		} catch (e: Exception) {
			false
		}
	}
	
	/**
	 * Update photo backup state in database
	 */
	private suspend fun updatePhotoBackupState(
		photoId: String, 
		state: BackupState, 
		s3Key: String?,
		s3ThumbnailKey: String?
	) {
		val photo = photoRepository.getPhotoById(photoId)
		photo?.let {
			val updated = it.copy(
				backupState = state,
				s3Key = s3Key,
				s3ThumbnailKey = s3ThumbnailKey
			)
			photoRepository.updatePhoto(updated)
		}
	}
	
	/**
	 * Get backup statistics
	 */
	suspend fun getBackupStats(): BackupStats {
		val starredPhotos = photoRepository.getStarredPhotos().first()
		val uploaded = starredPhotos.count { it.backupState == BackupState.UPLOADED }
		val pending = starredPhotos.count { it.backupState != BackupState.UPLOADED }
		val totalSize = starredPhotos.sumOf { it.fileSize ?: 0L }
		
		return BackupStats(
			totalPhotos = starredPhotos.size,
			uploadedPhotos = uploaded,
			pendingPhotos = pending,
			totalSizeBytes = totalSize
		)
	}
	
	/**
	 * Clear the entire backup queue (unstar all photos)
	 */
	suspend fun clearBackupQueue() {
		val starredPhotos = photoRepository.getStarredPhotos().first()
		starredPhotos.forEach { photo ->
			photoRepository.updateStarredStatus(photo.id, false)
		}
	}
	
	fun onCleared() {
		scope.cancel()
	}
}

data class BackupStats(
	val totalPhotos: Int,
	val uploadedPhotos: Int,
	val pendingPhotos: Int,
	val totalSizeBytes: Long
)
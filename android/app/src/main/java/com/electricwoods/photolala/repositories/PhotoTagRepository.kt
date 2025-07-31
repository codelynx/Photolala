package com.electricwoods.photolala.repositories

import com.electricwoods.photolala.backup.TagBackupManager
import com.electricwoods.photolala.data.local.dao.TagDao
import com.electricwoods.photolala.data.local.entities.TagEntity
import com.electricwoods.photolala.models.ColorFlag
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for photo tag operations
 * Manages color flag tags for photos (replacing the bookmark system)
 * Now integrated with Android Backup Service for cross-device sync
 */
@Singleton
class PhotoTagRepository @Inject constructor(
	private val tagDao: TagDao,
	private val tagBackupManager: TagBackupManager
) {
	
	/**
	 * Get all tags for a specific photo as a Flow
	 */
	fun getTagsForPhoto(photoId: String): Flow<Set<ColorFlag>> {
		return tagDao.getTagsForPhotoFlow(photoId)
			.map { entities ->
				entities.map { it.colorFlag }.toSet()
			}
	}
	
	/**
	 * Get tags for multiple photos
	 */
	suspend fun getTagsForPhotos(photoIds: List<String>): Map<String, Set<ColorFlag>> {
		val result = mutableMapOf<String, Set<ColorFlag>>()
		photoIds.forEach { photoId ->
			val tags = tagDao.getTagsForPhoto(photoId)
			if (tags.isNotEmpty()) {
				result[photoId] = tags.map { it.colorFlag }.toSet()
			}
		}
		return result
	}
	
	/**
	 * Toggle a color flag for a photo
	 * If the flag exists, remove it. Otherwise, add it.
	 */
	suspend fun toggleTag(photoId: String, colorFlag: ColorFlag) {
		val existingTags = tagDao.getTagsForPhoto(photoId)
		val hasFlag = existingTags.any { it.colorFlag == colorFlag }
		
		if (hasFlag) {
			// Remove the flag
			tagDao.deleteTag(photoId, colorFlag)
		} else {
			// Add the flag
			val tag = TagEntity(
				photoId = photoId,
				colorFlag = colorFlag,
				timestamp = System.currentTimeMillis()
			)
			tagDao.insertTag(tag)
		}
		
		// Sync with backup service
		val currentTags = tagDao.getTagsForPhoto(photoId).map { it.colorFlag }.toSet()
		tagBackupManager.saveTag(photoId, currentTags)
	}
	
	/**
	 * Set multiple tags for a photo (replaces all existing tags)
	 */
	suspend fun setTags(photoId: String, colorFlags: Set<ColorFlag>) {
		// Remove all existing tags
		tagDao.deleteAllTagsForPhoto(photoId)
		
		// Add new tags
		colorFlags.forEach { flag ->
			val tag = TagEntity(
				photoId = photoId,
				colorFlag = flag,
				timestamp = System.currentTimeMillis()
			)
			tagDao.insertTag(tag)
		}
		
		// Sync with backup service
		tagBackupManager.saveTag(photoId, colorFlags)
	}
	
	/**
	 * Add a tag to a photo (without removing existing tags)
	 */
	suspend fun addTag(photoId: String, colorFlag: ColorFlag) {
		val tag = TagEntity(
			photoId = photoId,
			colorFlag = colorFlag,
			timestamp = System.currentTimeMillis()
		)
		tagDao.insertTag(tag)
	}
	
	/**
	 * Remove a specific tag from a photo
	 */
	suspend fun removeTag(photoId: String, colorFlag: ColorFlag) {
		tagDao.deleteTag(photoId, colorFlag)
	}
	
	/**
	 * Remove all tags from a photo
	 */
	suspend fun removeAllTags(photoId: String) {
		tagDao.deleteAllTagsForPhoto(photoId)
		// Remove from backup service
		tagBackupManager.removeTag(photoId)
	}
	
	/**
	 * Get all photos with a specific tag
	 */
	suspend fun getPhotosByTag(colorFlag: ColorFlag): List<String> {
		return tagDao.getPhotosByTag(colorFlag).map { it.photoId }
	}
	
	/**
	 * Check if a photo has any tags
	 */
	suspend fun hasTags(photoId: String): Boolean {
		return tagDao.getTagsForPhoto(photoId).isNotEmpty()
	}
	
	/**
	 * Check if a photo has a specific tag
	 */
	suspend fun hasTag(photoId: String, colorFlag: ColorFlag): Boolean {
		val tags = tagDao.getTagsForPhoto(photoId)
		return tags.any { it.colorFlag == colorFlag }
	}
	
	/**
	 * Batch toggle tags for multiple photos
	 * Used when multiple photos are selected
	 */
	suspend fun toggleTagsForPhotos(photoIds: List<String>, colorFlag: ColorFlag) {
		photoIds.forEach { photoId ->
			toggleTag(photoId, colorFlag)
		}
	}
	
	/**
	 * Migrate all tags from Room to backup service
	 * This should be called once after update
	 */
	suspend fun migrateToBackupService() {
		val allTags = tagDao.getAllTags()
		val tagsByPhoto = allTags.groupBy { it.photoId }
			.mapValues { (_, tags) -> tags.map { it.colorFlag }.toSet() }
		
		tagBackupManager.importTags(tagsByPhoto)
	}
	
	/**
	 * Load tags from backup service and sync with Room
	 * This is called on app startup to restore backed up tags
	 */
	suspend fun syncFromBackupService() {
		val backupTags = tagBackupManager.loadAllTags()
		
		// For each photo in backup
		backupTags.forEach { (photoId, flags) ->
			// Get current tags from Room
			val currentTags = tagDao.getTagsForPhoto(photoId).map { it.colorFlag }.toSet()
			
			// Find tags to add (in backup but not in Room)
			val tagsToAdd = flags - currentTags
			tagsToAdd.forEach { flag ->
				val tag = TagEntity(
					photoId = photoId,
					colorFlag = flag,
					timestamp = System.currentTimeMillis()
				)
				tagDao.insertTag(tag)
			}
			
			// We don't remove tags that are in Room but not in backup
			// This preserves any local changes made before backup
		}
	}
	
	/**
	 * Get all tags from the database (for migration purposes)
	 */
	suspend fun getAllTags(): Map<String, Set<ColorFlag>> {
		val allTags = tagDao.getAllTags()
		return allTags.groupBy { it.photoId }
			.mapValues { (_, tags) -> tags.map { it.colorFlag }.toSet() }
	}
	
	/**
	 * Debug method to log all current tags
	 */
	suspend fun logAllTags() {
		val allTags = getAllTags()
		android.util.Log.d("TagBackup", "=== CURRENT TAGS IN DATABASE ===")
		android.util.Log.d("TagBackup", "Total photos with tags: ${allTags.size}")
		allTags.forEach { (photoId, flags) ->
			android.util.Log.d("TagBackup", "$photoId -> ${flags.map { it.name }}")
		}
		android.util.Log.d("TagBackup", "================================")
	}
}
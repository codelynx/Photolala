package com.electricwoods.photolala.repositories

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
 */
@Singleton
class PhotoTagRepository @Inject constructor(
	private val tagDao: TagDao
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
}
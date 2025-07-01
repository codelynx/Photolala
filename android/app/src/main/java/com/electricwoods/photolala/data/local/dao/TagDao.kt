package com.electricwoods.photolala.data.local.dao

import androidx.room.*
import com.electricwoods.photolala.data.local.entities.TagEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TagDao {
	@Query("SELECT * FROM tags WHERE photoId = :photoId")
	suspend fun getTagsForPhoto(photoId: String): List<TagEntity>

	@Query("SELECT * FROM tags WHERE photoId = :photoId")
	fun getTagsForPhotoFlow(photoId: String): Flow<List<TagEntity>>

	@Query("SELECT * FROM tags WHERE tagValue = :tagValue")
	suspend fun getPhotosByTag(tagValue: Int): List<TagEntity>

	@Insert(onConflict = OnConflictStrategy.REPLACE)
	suspend fun insertTag(tag: TagEntity)

	@Delete
	suspend fun deleteTag(tag: TagEntity)

	@Query("DELETE FROM tags WHERE photoId = :photoId AND tagValue = :tagValue")
	suspend fun deleteTag(photoId: String, tagValue: Int)

	@Query("DELETE FROM tags WHERE photoId = :photoId")
	suspend fun deleteAllTagsForPhoto(photoId: String)
}
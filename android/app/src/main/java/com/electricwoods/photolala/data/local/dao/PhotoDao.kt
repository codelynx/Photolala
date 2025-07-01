package com.electricwoods.photolala.data.local.dao

import androidx.room.*
import com.electricwoods.photolala.data.local.entities.PhotoEntity
import com.electricwoods.photolala.models.PhotoSource
import kotlinx.coroutines.flow.Flow

@Dao
interface PhotoDao {
	@Query("SELECT * FROM photos WHERE source = :source ORDER BY dateCreated DESC")
	fun getPhotosBySource(source: PhotoSource): Flow<List<PhotoEntity>>

	@Query("SELECT * FROM photos WHERE isStarred = 1 ORDER BY dateCreated DESC")
	fun getStarredPhotos(): Flow<List<PhotoEntity>>

	@Query("SELECT * FROM photos WHERE id = :photoId")
	suspend fun getPhotoById(photoId: String): PhotoEntity?

	@Insert(onConflict = OnConflictStrategy.REPLACE)
	suspend fun insertPhoto(photo: PhotoEntity)

	@Insert(onConflict = OnConflictStrategy.REPLACE)
	suspend fun insertPhotos(photos: List<PhotoEntity>)

	@Update
	suspend fun updatePhoto(photo: PhotoEntity)

	@Delete
	suspend fun deletePhoto(photo: PhotoEntity)

	@Query("DELETE FROM photos WHERE id = :photoId")
	suspend fun deletePhotoById(photoId: String)

	@Query("UPDATE photos SET isStarred = :isStarred WHERE id = :photoId")
	suspend fun updateStarredStatus(photoId: String, isStarred: Boolean)
}
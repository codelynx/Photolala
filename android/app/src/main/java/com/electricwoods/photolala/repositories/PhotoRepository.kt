package com.electricwoods.photolala.repositories

import com.electricwoods.photolala.data.local.dao.PhotoDao
import com.electricwoods.photolala.data.local.entities.PhotoEntity
import com.electricwoods.photolala.di.IoDispatcher
import com.electricwoods.photolala.models.PhotoMediaStore
import com.electricwoods.photolala.models.PhotoSource
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PhotoRepository @Inject constructor(
	private val photoDao: PhotoDao,
	@IoDispatcher private val ioDispatcher: CoroutineDispatcher
) {
	
	fun getPhotosBySource(source: PhotoSource): Flow<List<PhotoEntity>> {
		return photoDao.getPhotosBySource(source)
	}
	
	fun getStarredPhotos(): Flow<List<PhotoEntity>> {
		return photoDao.getStarredPhotos()
	}
	
	suspend fun getPhotoById(photoId: String): PhotoEntity? = withContext(ioDispatcher) {
		photoDao.getPhotoById(photoId)
	}
	
	suspend fun updateStarredStatus(photoId: String, isStarred: Boolean) = withContext(ioDispatcher) {
		photoDao.updateStarredStatus(photoId, isStarred)
	}
	
	suspend fun toggleStarredStatus(photoId: String) = withContext(ioDispatcher) {
		val photo = photoDao.getPhotoById(photoId)
		photo?.let {
			photoDao.updateStarredStatus(photoId, !it.isStarred)
		}
	}
	
	suspend fun insertOrUpdatePhoto(photo: PhotoMediaStore, isStarred: Boolean = false) = withContext(ioDispatcher) {
		val entity = PhotoEntity(
			id = photo.id,
			uri = photo.uri.toString(),
			path = photo.uri.path ?: photo.filename,
			filename = photo.filename,
			fileSize = photo.fileSize,
			width = photo.width,
			height = photo.height,
			dateCreated = photo.creationDate,
			dateModified = photo.modificationDate,
			source = PhotoSource.MEDIA_STORE,
			isStarred = isStarred
		)
		photoDao.insertPhoto(entity)
	}
	
	suspend fun updatePhoto(photo: PhotoEntity) = withContext(ioDispatcher) {
		photoDao.updatePhoto(photo)
	}
	
	suspend fun getStarredCount(): Int = withContext(ioDispatcher) {
		photoDao.getStarredPhotos().let { flow ->
			// This is a simple implementation - in production you might want a specific count query
			var count = 0
			flow.collect { photos ->
				count = photos.size
			}
			count
		}
	}
}
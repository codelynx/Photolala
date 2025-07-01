package com.electricwoods.photolala.services

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import com.electricwoods.photolala.di.IoDispatcher
import com.electricwoods.photolala.models.PhotoMediaStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class MediaStoreServiceImpl @Inject constructor(
	@ApplicationContext private val context: Context,
	@IoDispatcher private val ioDispatcher: CoroutineDispatcher
) : MediaStoreService {
	
	private val contentResolver: ContentResolver = context.contentResolver
	
	// MediaStore columns we need
	private val projection = arrayOf(
		MediaStore.Images.Media._ID,
		MediaStore.Images.Media.DISPLAY_NAME,
		MediaStore.Images.Media.SIZE,
		MediaStore.Images.Media.DATE_ADDED,
		MediaStore.Images.Media.DATE_MODIFIED,
		MediaStore.Images.Media.WIDTH,
		MediaStore.Images.Media.HEIGHT,
		MediaStore.Images.Media.MIME_TYPE,
		MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
		MediaStore.Images.Media.BUCKET_ID
	)
	
	override suspend fun getPhotos(
		limit: Int,
		offset: Int
	): Flow<List<PhotoMediaStore>> = flow {
		val photos = withContext(ioDispatcher) {
			queryPhotos(
				selection = null,
				selectionArgs = null,
				sortOrder = "${MediaStore.Images.Media.DATE_MODIFIED} DESC",
				limit = limit,
				offset = offset
			)
		}
		emit(photos)
	}.flowOn(ioDispatcher)
	
	override suspend fun getPhotosFromBucket(
		bucketId: Long,
		limit: Int,
		offset: Int
	): Flow<List<PhotoMediaStore>> = flow {
		val photos = withContext(ioDispatcher) {
			queryPhotosWithBucket(
				bucketId = bucketId,
				sortOrder = "${MediaStore.Images.Media.DATE_MODIFIED} DESC",
				limit = limit,
				offset = offset
			)
		}
		emit(photos)
	}.flowOn(ioDispatcher)
	
	override suspend fun getAlbums(): List<Album> = withContext(ioDispatcher) {
		val albums = mutableMapOf<Long, Album>()
		
		contentResolver.query(
			MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
			arrayOf(
				MediaStore.Images.Media.BUCKET_ID,
				MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
				MediaStore.Images.Media._ID
			),
			null,
			null,
			"${MediaStore.Images.Media.DATE_MODIFIED} DESC"
		)?.use { cursor ->
			val bucketIdColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_ID)
			val bucketNameColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
			val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
			
			while (cursor.moveToNext()) {
				val bucketId = cursor.getLong(bucketIdColumn)
				val bucketName = cursor.getString(bucketNameColumn) ?: "Unknown"
				
				if (!albums.containsKey(bucketId)) {
					val photoId = cursor.getLong(idColumn)
					val uri = ContentUris.withAppendedId(
						MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
						photoId
					)
					
					albums[bucketId] = Album(
						id = bucketId,
						name = bucketName,
						coverPhotoUri = uri.toString(),
						photoCount = 1
					)
				} else {
					albums[bucketId] = albums[bucketId]!!.copy(
						photoCount = albums[bucketId]!!.photoCount + 1
					)
				}
			}
		}
		
		albums.values.toList().sortedByDescending { it.photoCount }
	}
	
	override suspend fun getPhotoById(mediaStoreId: Long): PhotoMediaStore? = 
		withContext(ioDispatcher) {
			val uri = ContentUris.withAppendedId(
				MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
				mediaStoreId
			)
			
			contentResolver.query(
				uri,
				projection,
				null,
				null,
				null
			)?.use { cursor ->
				if (cursor.moveToFirst()) {
					cursorToPhoto(cursor)
				} else null
			}
		}
	
	override suspend fun loadThumbnail(
		photo: PhotoMediaStore,
		size: Int
	): ByteArray? = withContext(ioDispatcher) {
		try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				// Use the modern thumbnail API
				val bitmap = contentResolver.loadThumbnail(
					photo.uri,
					android.util.Size(size, size),
					null
				)
				// Convert bitmap to ByteArray
				val stream = java.io.ByteArrayOutputStream()
				bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, stream)
				stream.toByteArray()
			} else {
				// For older versions, load the full image (not ideal but works)
				loadImageData(photo)
			}
		} catch (e: Exception) {
			null
		}
	}
	
	override suspend fun loadImageData(photo: PhotoMediaStore): ByteArray = 
		withContext(ioDispatcher) {
			contentResolver.openInputStream(photo.uri)?.use { stream ->
				stream.readBytes()
			} ?: throw IllegalStateException("Cannot open photo: ${photo.uri}")
		}
	
	override fun hasPermission(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			// Android 13+ uses READ_MEDIA_IMAGES
			ContextCompat.checkSelfPermission(
				context,
				android.Manifest.permission.READ_MEDIA_IMAGES
			) == PackageManager.PERMISSION_GRANTED
		} else {
			// Older versions use READ_EXTERNAL_STORAGE
			ContextCompat.checkSelfPermission(
				context,
				android.Manifest.permission.READ_EXTERNAL_STORAGE
			) == PackageManager.PERMISSION_GRANTED
		}
	}
	
	override suspend fun getTotalPhotoCount(): Int = withContext(ioDispatcher) {
		contentResolver.query(
			MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
			arrayOf("COUNT(*)"),
			null,
			null,
			null
		)?.use { cursor ->
			if (cursor.moveToFirst()) {
				cursor.getInt(0)
			} else 0
		} ?: 0
	}
	
	private fun queryPhotos(
		selection: String?,
		selectionArgs: Array<String>?,
		sortOrder: String,
		limit: Int,
		offset: Int
	): List<PhotoMediaStore> {
		val photos = mutableListOf<PhotoMediaStore>()
		
		// Query all and manually paginate - LIMIT/OFFSET not reliably supported across all devices
		var count = 0
		contentResolver.query(
			MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
			projection,
			selection,
			selectionArgs,
			sortOrder
		)?.use { cursor ->
			// Skip to offset
			if (offset > 0) {
				cursor.moveToPosition(offset - 1)
			}
			
			// Read up to limit items
			while (cursor.moveToNext() && count < limit) {
				photos.add(cursorToPhoto(cursor))
				count++
			}
		}
		
		return photos
	}
	
	private fun queryPhotosWithBucket(
		bucketId: Long,
		sortOrder: String,
		limit: Int,
		offset: Int
	): List<PhotoMediaStore> {
		return queryPhotos(
			selection = "${MediaStore.Images.Media.BUCKET_ID} = ?",
			selectionArgs = arrayOf(bucketId.toString()),
			sortOrder = sortOrder,
			limit = limit,
			offset = offset
		)
	}
	
	private fun cursorToPhoto(cursor: android.database.Cursor): PhotoMediaStore {
		val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
		val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
		val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
		val dateAddedColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
		val dateModifiedColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_MODIFIED)
		val widthColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.WIDTH)
		val heightColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.HEIGHT)
		val mimeTypeColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
		val bucketNameColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
		val bucketIdColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_ID)
		
		val id = cursor.getLong(idColumn)
		val uri = ContentUris.withAppendedId(
			MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
			id
		)
		
		return PhotoMediaStore(
			mediaStoreId = id,
			uri = uri,
			filename = cursor.getString(nameColumn) ?: "Unknown",
			fileSize = cursor.getLongOrNull(sizeColumn),
			width = cursor.getIntOrNull(widthColumn),
			height = cursor.getIntOrNull(heightColumn),
			creationDate = cursor.getLongOrNull(dateAddedColumn)?.let { Date(it * 1000) },
			modificationDate = cursor.getLongOrNull(dateModifiedColumn)?.let { Date(it * 1000) },
			mimeType = cursor.getStringOrNull(mimeTypeColumn),
			bucketName = cursor.getStringOrNull(bucketNameColumn),
			bucketId = cursor.getLongOrNull(bucketIdColumn)
		)
	}
	
	// Extension functions for null-safe cursor reading
	private fun android.database.Cursor.getLongOrNull(columnIndex: Int): Long? =
		if (isNull(columnIndex)) null else getLong(columnIndex)
	
	private fun android.database.Cursor.getIntOrNull(columnIndex: Int): Int? =
		if (isNull(columnIndex)) null else getInt(columnIndex)
	
	private fun android.database.Cursor.getStringOrNull(columnIndex: Int): String? =
		if (isNull(columnIndex)) null else getString(columnIndex)
}
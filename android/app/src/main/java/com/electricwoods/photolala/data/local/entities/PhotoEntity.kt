package com.electricwoods.photolala.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.electricwoods.photolala.models.ArchiveStatus
import com.electricwoods.photolala.models.BackupState
import com.electricwoods.photolala.models.PhotoSource
import java.util.Date

@Entity(tableName = "photos")
data class PhotoEntity(
	@PrimaryKey
	val id: String,
	val uri: String? = null, // For local files
	val path: String,
	val filename: String,
	val fileSize: Long? = null,
	val width: Int? = null,
	val height: Int? = null,
	val dateCreated: Date? = null,
	val dateModified: Date? = null,
	val md5Hash: String? = null,
	val source: PhotoSource,
	val archiveStatus: ArchiveStatus = ArchiveStatus.STANDARD,
	val backupState: BackupState = BackupState.NOT_BACKED_UP,
	val isStarred: Boolean = false,
	val thumbnailPath: String? = null,
	val s3Key: String? = null, // For S3 photos
	val s3ThumbnailKey: String? = null,
	val lastAccessed: Long = System.currentTimeMillis(),
	val lastSynced: Long? = null
)
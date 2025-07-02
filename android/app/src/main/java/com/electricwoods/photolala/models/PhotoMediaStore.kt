package com.electricwoods.photolala.models

import android.net.Uri
import java.util.Date

/**
 * Represents a photo from Android's MediaStore (Google Photos, Gallery, etc.)
 * Equivalent to iOS PhotoApple
 */
data class PhotoMediaStore(
	val mediaStoreId: Long,
	val uri: Uri,
	override val filename: String,
	override val fileSize: Long?,
	override val width: Int? = null,
	override val height: Int? = null,
	override val creationDate: Date?,
	override val modificationDate: Date?,
	override val md5Hash: String? = null,
	override val archiveStatus: ArchiveStatus = ArchiveStatus.STANDARD,
	var backupState: BackupState = BackupState.NOT_BACKED_UP,
	var colorFlags: Set<ColorFlag> = emptySet(),
	val mimeType: String? = null,
	val bucketName: String? = null, // Album/folder name
	val bucketId: Long? = null
) : PhotoItem {
	
	override val id: String = "gmp#$mediaStoreId"
	
	override val displayName: String
		get() = filename
	
	override val isArchived: Boolean = false
	
	override val source: PhotoSource = PhotoSource.MEDIA_STORE
	
	override suspend fun loadThumbnail(): ByteArray? {
		// Implementation will use MediaStore thumbnail API
		// ContentResolver.loadThumbnail() for API 29+
		// or MediaStore.Images.Thumbnails for older APIs
		return null
	}
	
	override suspend fun loadImageData(): ByteArray {
		// Load using ContentResolver
		// context.contentResolver.openInputStream(uri)
		return ByteArray(0)
	}
	
	override fun contextMenuItems(): List<PhotoContextMenuItem> {
		return listOf(
			PhotoContextMenuItem(
				title = "Open in Gallery",
				icon = android.R.drawable.ic_menu_gallery,
				action = {
					// Open in system gallery app
				}
			),
			PhotoContextMenuItem(
				title = "Share",
				icon = android.R.drawable.ic_menu_share,
				action = {
					// Share photo
				}
			),
			PhotoContextMenuItem(
				title = "Details",
				icon = android.R.drawable.ic_menu_info_details,
				action = {
					// Show photo details
				}
			)
		)
	}
}
package com.electricwoods.photolala.models

import android.content.Context
import android.net.Uri
import java.io.File
import java.util.Date

/**
 * Represents a local photo file from device storage
 * Equivalent to iOS PhotoFile
 */
data class PhotoFile(
	override val id: String,
	val uri: Uri,
	val path: String,
	override val filename: String,
	override val fileSize: Long?,
	override val width: Int? = null,
	override val height: Int? = null,
	override val creationDate: Date?,
	override val modificationDate: Date?,
	override val md5Hash: String? = null,
	override val archiveStatus: ArchiveStatus = ArchiveStatus.STANDARD,
	var backupState: BackupState = BackupState.NOT_BACKED_UP,
	var colorFlags: Set<ColorFlag> = emptySet()
) : PhotoItem {
	
	override val displayName: String
		get() = md5Hash?.let { hash ->
			"#${hash.takeLast(5)}"
		} ?: filename
	
	override val isArchived: Boolean = false
	
	override val source: PhotoSource = PhotoSource.LOCAL
	
	override suspend fun loadThumbnail(): ByteArray? {
		// Implementation will use Android's thumbnail system
		// This will be implemented with MediaStore or Coil
		return null
	}
	
	override suspend fun loadImageData(): ByteArray {
		// Load from file system
		return File(path).readBytes()
	}
	
	override fun contextMenuItems(): List<PhotoContextMenuItem> {
		return listOf(
			PhotoContextMenuItem(
				title = "Show in Files",
				icon = android.R.drawable.ic_menu_view,
				action = {
					// Open file manager
				}
			),
			PhotoContextMenuItem(
				title = "Share",
				icon = android.R.drawable.ic_menu_share,
				action = {
					// Share photo
				}
			)
		)
	}
}
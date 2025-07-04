package com.electricwoods.photolala.models

import java.util.Date

/**
 * Represents a photo stored in S3 cloud storage
 * Equivalent to iOS PhotoS3
 */
data class PhotoS3(
	override val id: String,
	val photoKey: String,
	val thumbnailKey: String?,
	override val filename: String,
	override val fileSize: Long?,
	override val width: Int? = null,
	override val height: Int? = null,
	override val creationDate: Date?,
	override val modificationDate: Date?,
	override val md5Hash: String?,
	override val archiveStatus: ArchiveStatus,
	val bucketName: String = "photolala",
	var colorFlags: Set<ColorFlag> = emptySet()
) : PhotoItem {
	
	override val displayName: String = filename
	
	override val isArchived: Boolean
		get() = archiveStatus.isArchived
	
	override val source: PhotoSource = PhotoSource.S3_CLOUD
	
	override suspend fun loadThumbnail(): ByteArray? {
		// This will be implemented by S3PhotoProvider
		// The provider has access to S3Service for downloading
		throw UnsupportedOperationException("Use S3PhotoProvider.loadThumbnail() instead")
	}
	
	override suspend fun loadImageData(): ByteArray {
		// This will be implemented by S3PhotoProvider
		// The provider has access to S3Service for downloading
		throw UnsupportedOperationException("Use S3PhotoProvider.loadImageData() instead")
	}
	
	override fun contextMenuItems(): List<PhotoContextMenuItem> {
		val items = mutableListOf<PhotoContextMenuItem>()
		
		items.add(PhotoContextMenuItem(
			title = "Download",
			icon = android.R.drawable.ic_menu_save,
			action = {
				// Trigger download
			}
		))
		
		if (isArchived) {
			items.add(PhotoContextMenuItem(
				title = "Restore from Archive",
				icon = android.R.drawable.ic_menu_revert,
				action = {
					// Trigger restore
				}
			))
		}
		
		items.add(PhotoContextMenuItem(
			title = "Copy S3 Path",
			icon = android.R.drawable.ic_menu_edit,
			action = {
				// Copy to clipboard
			}
		))
		
		return items
	}
}
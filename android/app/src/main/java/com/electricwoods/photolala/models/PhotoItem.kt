package com.electricwoods.photolala.models

import java.util.Date

/**
 * Interface matching Apple's PhotoItem protocol
 * All photo types must implement this interface
 */
interface PhotoItem {
	val id: String
	val displayName: String
	val filename: String
	val fileSize: Long?
	val width: Int?
	val height: Int?
	val aspectRatio: Double?
		get() = width?.let { w -> height?.let { h -> w.toDouble() / h } }
	
	val creationDate: Date?
	val modificationDate: Date?
	
	val isArchived: Boolean
	val archiveStatus: ArchiveStatus
	val md5Hash: String?
	
	val source: PhotoSource
	
	// Methods that need implementation
	suspend fun loadThumbnail(): ByteArray?
	suspend fun loadImageData(): ByteArray
	fun contextMenuItems(): List<PhotoContextMenuItem>
}

data class PhotoContextMenuItem(
	val title: String,
	val icon: Int? = null, // Resource ID for icon
	val action: suspend () -> Unit
)
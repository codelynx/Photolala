package com.electricwoods.photolala.models

import android.net.Uri
import com.electricwoods.photolala.utils.MD5Utils
import java.util.Date

/**
 * Represents a photo from Google Photos Library
 * Similar to PhotoApple on iOS
 */
data class PhotoGooglePhotos(
	val mediaItemId: String, // Stable Google Photos ID (like PHAsset.localIdentifier)
	override val filename: String,
	override val fileSize: Long? = null, // Not available from API
	override val width: Int?,
	override val height: Int?,
	override val creationDate: Date?,
	override val modificationDate: Date?,
	val baseUrl: String, // Temporary URL (expires ~60 min)
	val productUrl: String, // Permanent link to Google Photos
	val mimeType: String?,
	// Additional metadata for identification
	val pseudoHash: String? = null, // Generated from metadata combination
	val cameraMake: String? = null,
	val cameraModel: String? = null
) : PhotoItem {
	// Use "ggp#" prefix for Google Photos (like "gmp#" for MediaStore, "gap#" for Apple Photos)
	override val id: String = "ggp#$mediaItemId"
	
	override val displayName: String 
		get() = filename.substringBeforeLast('.')
	
	val uri: Uri
		get() = Uri.parse(baseUrl) // Temporary URL for image loading
	
	override val isArchived: Boolean = false
	
	override val archiveStatus: ArchiveStatus = ArchiveStatus.STANDARD
	
	// MD5 cannot be computed without downloading the full image
	override val md5Hash: String? = null
	
	override val source: PhotoSource = PhotoSource.GOOGLE_PHOTOS
	
	/**
	 * Generate stable identifier for cross-source matching
	 * Similar to how iOS creates pseudo-hash for deduplication
	 */
	fun generatePseudoHash(): String {
		val components = listOf(
			filename,
			creationDate?.time?.toString() ?: "",
			width?.toString() ?: "",
			height?.toString() ?: "",
			cameraMake ?: "",
			cameraModel ?: ""
		)
		return MD5Utils.md5(components.joinToString("|"))
	}
	
	/**
	 * Check if the baseUrl has likely expired (URLs expire after ~60 minutes)
	 */
	fun isUrlExpired(urlTimestamp: Long): Boolean {
		val expirationTime = 55 * 60 * 1000L // 55 minutes in milliseconds
		return System.currentTimeMillis() - urlTimestamp > expirationTime
	}
	
	// PhotoItem interface implementation
	override suspend fun loadThumbnail(): ByteArray? {
		// TODO: Download thumbnail from Google Photos
		// For now, return null - thumbnails will be loaded via Coil
		return null
	}
	
	override suspend fun loadImageData(): ByteArray {
		// TODO: Download full image from Google Photos
		// This would need to be implemented with GooglePhotosService
		throw NotImplementedError("Google Photos image download not yet implemented")
	}
	
	override fun contextMenuItems(): List<PhotoContextMenuItem> {
		return listOf(
			PhotoContextMenuItem(
				title = "View in Google Photos",
				action = {
					// Open productUrl in browser
				}
			),
			PhotoContextMenuItem(
				title = "Download",
				action = {
					// Download photo to device
				}
			)
		)
	}
	
	companion object {
		/**
		 * Create PhotoGooglePhotos from Google Photos API MediaItem
		 * Using generic type to avoid compile-time dependency
		 */
		fun fromMediaItem(item: Any): PhotoGooglePhotos {
			// This will be properly implemented when called from GooglePhotosServiceImpl
			// which has access to the MediaItem type
			return PhotoGooglePhotos(
				mediaItemId = "temp-id",
				filename = "temp.jpg",
				fileSize = null,
				width = null,
				height = null,
				creationDate = null,
				modificationDate = null,
				baseUrl = "",
				productUrl = "",
				mimeType = null
			)
		}
		
		/**
		 * Extract media item ID from photo ID
		 */
		fun extractMediaItemId(photoId: String): String? {
			return if (photoId.startsWith("ggp#")) {
				photoId.removePrefix("ggp#")
			} else {
				null
			}
		}
	}
}
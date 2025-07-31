package com.electricwoods.photolala.models

import java.util.Date

/**
 * Photo source enum matching iOS
 */
enum class PhotoSource {
	LOCAL,
	MEDIA_STORE, // Android's MediaStore (equivalent to Apple Photos)
	S3_CLOUD,
	GOOGLE_PHOTOS // Google Photos Library
}

/**
 * Photo metadata matching iOS PhotoMetadata
 */
data class PhotoMetadata(
	val fileSize: Long? = null,
	val pixelWidth: Int? = null,
	val pixelHeight: Int? = null,
	val fileCreationDate: Date? = null,
	val fileModificationDate: Date? = null,
	// Camera info
	val cameraMake: String? = null,
	val cameraModel: String? = null,
	val lensMake: String? = null,
	val lensModel: String? = null,
	// Photo settings
	val dateTaken: Date? = null,
	val aperture: Float? = null,
	val shutterSpeed: String? = null,
	val iso: Int? = null,
	val focalLength: Float? = null,
	// Location
	val gpsLatitude: Double? = null,
	val gpsLongitude: Double? = null,
	val gpsAltitude: Double? = null,
	// Other
	val orientation: Int = 1,
	val colorSpace: String? = null
)

/**
 * Extended photo metadata for display
 */
data class ExtendedPhotoMetadata(
	val basic: PhotoMetadata,
	val formattedFileSize: String,
	val formattedDimensions: String?,
	val formattedDate: String?,
	val cameraInfo: String?,
	val locationInfo: String?,
	val captureSettings: String?
)
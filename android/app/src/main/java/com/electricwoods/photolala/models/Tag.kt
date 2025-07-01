package com.electricwoods.photolala.models

/**
 * Tag model representing color flags applied to photos
 * Matches iOS PhotoTag structure
 */
data class PhotoTag(
	val photoId: String,
	val colorFlag: ColorFlag,
	val timestamp: Long = System.currentTimeMillis()
) {
	// For CSV export compatibility with iOS
	fun toCsvString(): String {
		return "$photoId,${colorFlag.value},$timestamp"
	}
	
	companion object {
		fun fromCsvString(csv: String): PhotoTag? {
			val parts = csv.split(",")
			if (parts.size != 3) return null
			
			return try {
				val photoId = parts[0]
				val flagValue = parts[1].toInt()
				val timestamp = parts[2].toLong()
				val colorFlag = ColorFlag.fromValue(flagValue) ?: return null
				
				PhotoTag(photoId, colorFlag, timestamp)
			} catch (e: Exception) {
				null
			}
		}
	}
}
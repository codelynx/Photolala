package com.electricwoods.photolala.models

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.Instant
import java.util.Base64

/**
 * PhotoDigest - Unified representation of thumbnail + metadata
 * Matches the iOS PhotoDigest structure for cross-platform consistency
 */
@Serializable
data class PhotoDigest(
	val md5Hash: String,
	@Serializable(with = ByteArraySerializer::class)
	val thumbnailData: ByteArray,
	val metadata: PhotoDigestMetadata,
	@Serializable(with = InstantSerializer::class)
	val createdAt: Instant,
	@Serializable(with = InstantSerializer::class)
	val lastAccessedAt: Instant
) {
	@Transient
	val cacheKey: String = md5Hash
	
	override fun equals(other: Any?): Boolean {
		if (this === other) return true
		if (javaClass != other?.javaClass) return false
		
		other as PhotoDigest
		
		if (md5Hash != other.md5Hash) return false
		if (!thumbnailData.contentEquals(other.thumbnailData)) return false
		if (metadata != other.metadata) return false
		if (createdAt != other.createdAt) return false
		if (lastAccessedAt != other.lastAccessedAt) return false
		
		return true
	}
	
	override fun hashCode(): Int {
		var result = md5Hash.hashCode()
		result = 31 * result + thumbnailData.contentHashCode()
		result = 31 * result + metadata.hashCode()
		result = 31 * result + createdAt.hashCode()
		result = 31 * result + lastAccessedAt.hashCode()
		return result
	}
}

/**
 * Simplified metadata for PhotoDigest
 * Contains only essential information needed for display
 */
@Serializable
data class PhotoDigestMetadata(
	val filename: String,
	val fileSize: Long,
	val pixelWidth: Int?,
	val pixelHeight: Int?,
	@Serializable(with = InstantSerializer::class)
	val creationDate: Instant?,
	val modificationTimestamp: Long, // Unix seconds
	val exifData: Map<String, String>? = null
)

/**
 * File identity key for Level 1 cache
 * Combines path MD5, file size, and modification timestamp
 */
data class FileIdentityKey(
	val pathMD5: String,
	val fileSize: Long,
	val modificationTimestamp: Long // Unix seconds
) {
	/**
	 * Creates cache key in format: {pathMD5}|{fileSize}|{modTimestamp}
	 */
	val cacheKey: String
		get() = "$pathMD5|$fileSize|$modificationTimestamp"
	
	companion object {
		/**
		 * Creates FileIdentityKey from a file path
		 */
		fun fromPath(path: String, size: Long, modTimestamp: Long): FileIdentityKey {
			// Normalize path using canonical path, convert to lowercase, then MD5
			// This handles case-insensitive filesystems properly
			val normalizedPath = try {
				java.io.File(path).canonicalPath.lowercase()
			} catch (e: Exception) {
				// Fallback to simple normalization if canonical path fails
				path.replace("\\", "/").lowercase()
			}
			val pathMD5 = MD5Utils.md5(normalizedPath)
			return FileIdentityKey(pathMD5, size, modTimestamp)
		}
		
		/**
		 * Parses cache key back to FileIdentityKey
		 */
		fun fromCacheKey(cacheKey: String): FileIdentityKey? {
			val parts = cacheKey.split("|")
			if (parts.size != 3) return null
			
			return try {
				FileIdentityKey(
					pathMD5 = parts[0],
					fileSize = parts[1].toLong(),
					modificationTimestamp = parts[2].toLong()
				)
			} catch (e: NumberFormatException) {
				null
			}
		}
	}
}

// Custom serializers for kotlinx.serialization
object ByteArraySerializer : KSerializer<ByteArray> {
	override val descriptor = PrimitiveSerialDescriptor("ByteArray", PrimitiveKind.STRING)
	
	override fun serialize(encoder: Encoder, value: ByteArray) {
		encoder.encodeString(Base64.getEncoder().encodeToString(value))
	}
	
	override fun deserialize(decoder: Decoder): ByteArray {
		return Base64.getDecoder().decode(decoder.decodeString())
	}
}

object InstantSerializer : KSerializer<Instant> {
	override val descriptor = PrimitiveSerialDescriptor("Instant", PrimitiveKind.LONG)
	
	override fun serialize(encoder: Encoder, value: Instant) {
		encoder.encodeLong(value.epochSecond)
	}
	
	override fun deserialize(decoder: Decoder): Instant {
		return Instant.ofEpochSecond(decoder.decodeLong())
	}
}
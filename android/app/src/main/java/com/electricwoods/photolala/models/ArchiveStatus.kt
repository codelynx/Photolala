package com.electricwoods.photolala.models

/**
 * Archive status matching iOS ArchiveStatus
 * Represents S3 storage classes for archived photos
 */
enum class ArchiveStatus {
	STANDARD,
	INFREQUENT_ACCESS,
	GLACIER_INSTANT_RETRIEVAL,
	GLACIER_FLEXIBLE_RETRIEVAL,
	GLACIER_DEEP_ARCHIVE;
	
	val isArchived: Boolean
		get() = this != STANDARD
	
	val canRetrieveInstantly: Boolean
		get() = this == STANDARD || this == GLACIER_INSTANT_RETRIEVAL
}
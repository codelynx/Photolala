package com.electricwoods.photolala.models

/**
 * Backup state matching iOS BackupState
 * Tracks the backup status of a photo
 */
enum class BackupState {
	NOT_BACKED_UP,
	QUEUED,
	UPLOADING,
	UPLOADED,
	FAILED;
	
	val isBackedUp: Boolean
		get() = this == UPLOADED
	
	val isInProgress: Boolean
		get() = this == QUEUED || this == UPLOADING
}
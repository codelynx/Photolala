package com.electricwoods.photolala.backup

import android.app.backup.BackupAgentHelper
import android.app.backup.SharedPreferencesBackupHelper

/**
 * Backup agent for syncing photo tags across devices using Android Backup Service.
 * Tags are stored in SharedPreferences as key-value pairs where:
 * - Key: Photo ID (e.g., "md5#abc123...")
 * - Value: Comma-separated color flag values (e.g., "1,3,5")
 */
class TagBackupAgent : BackupAgentHelper() {
	companion object {
		const val PREFS_BACKUP_KEY = "photo_tags"
		const val PREFS_FILE_NAME = "photo_tags_backup"
	}

	override fun onCreate() {
		// Create a backup helper for SharedPreferences
		val helper = SharedPreferencesBackupHelper(this, PREFS_FILE_NAME)
		addHelper(PREFS_BACKUP_KEY, helper)
	}
}
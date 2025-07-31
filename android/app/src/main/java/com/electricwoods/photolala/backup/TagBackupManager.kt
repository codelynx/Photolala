package com.electricwoods.photolala.backup

import android.app.backup.BackupManager
import android.content.Context
import android.content.SharedPreferences
import com.electricwoods.photolala.models.ColorFlag
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages photo tags in SharedPreferences for Android Backup Service.
 * This enables automatic backup and restore of tags across devices.
 */
@Singleton
class TagBackupManager @Inject constructor(
	@ApplicationContext private val context: Context
) {
	private val prefs: SharedPreferences = context.getSharedPreferences(
		TagBackupAgent.PREFS_FILE_NAME,
		Context.MODE_PRIVATE
	)
	
	private val backupManager = BackupManager(context)
	
	/**
	 * Save tags for a photo and trigger backup
	 */
	fun saveTag(photoId: String, flags: Set<ColorFlag>) {
		if (flags.isEmpty()) {
			removeTag(photoId)
			return
		}
		
		val flagsString = flags.joinToString(",") { it.value.toString() }
		prefs.edit()
			.putString(photoId, flagsString)
			.apply()
		
		// Log for testing
		android.util.Log.d("TagBackup", "SAVED: $photoId -> $flagsString (flags: ${flags.map { it.name }})")
		
		// Notify backup service that data has changed
		backupManager.dataChanged()
	}
	
	/**
	 * Remove all tags for a photo
	 */
	fun removeTag(photoId: String) {
		prefs.edit()
			.remove(photoId)
			.apply()
		
		backupManager.dataChanged()
	}
	
	/**
	 * Get tags for a specific photo
	 */
	fun getTag(photoId: String): Set<ColorFlag> {
		val flagsString = prefs.getString(photoId, null) ?: return emptySet()
		
		return flagsString.split(",")
			.mapNotNull { it.toIntOrNull() }
			.mapNotNull { value -> 
				ColorFlag.values().find { it.value == value }
			}
			.toSet()
	}
	
	/**
	 * Load all tags from SharedPreferences
	 */
	fun loadAllTags(): Map<String, Set<ColorFlag>> {
		val allTags = prefs.all.mapNotNull { (key, value) ->
			// Only process entries that look like photo IDs
			if (key.startsWith("md5#") && value is String) {
				val flags = value.split(",")
					.mapNotNull { it.toIntOrNull() }
					.mapNotNull { intValue -> 
						ColorFlag.values().find { it.value == intValue }
					}
					.toSet()
				
				if (flags.isNotEmpty()) {
					key to flags
				} else {
					null
				}
			} else {
				null
			}
		}.toMap()
		
		// Log all loaded tags
		android.util.Log.d("TagBackup", "LOADED ${allTags.size} tags from backup:")
		allTags.forEach { (photoId, flags) ->
			android.util.Log.d("TagBackup", "  - $photoId -> ${flags.map { it.name }}")
		}
		
		return allTags
	}
	
	/**
	 * Clear all tags (use with caution)
	 */
	fun clearAllTags() {
		prefs.edit().clear().apply()
		backupManager.dataChanged()
	}
	
	/**
	 * Get total number of tagged photos
	 */
	fun getTaggedPhotoCount(): Int {
		return prefs.all.count { (key, value) ->
			key.startsWith("md5#") && value is String && value.isNotEmpty()
		}
	}
	
	/**
	 * Migrate tags from another source (e.g., Room database)
	 */
	fun importTags(tags: Map<String, Set<ColorFlag>>) {
		prefs.edit().apply {
			// Clear existing tags first
			clear()
			
			// Add all new tags
			tags.forEach { (photoId, flags) ->
				if (flags.isNotEmpty()) {
					putString(photoId, flags.joinToString(",") { it.value.toString() })
				}
			}
		}.apply()
		
		backupManager.dataChanged()
	}
}
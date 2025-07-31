package com.electricwoods.photolala.startup

import android.content.Context
import androidx.startup.Initializer
import androidx.work.WorkManager
import com.electricwoods.photolala.repositories.PhotoTagRepository
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Initializes tag synchronization from Android Backup Service on app startup
 */
class TagSyncInitializer : Initializer<Unit> {
	
	@EntryPoint
	@InstallIn(SingletonComponent::class)
	interface TagSyncInitializerEntryPoint {
		fun photoTagRepository(): PhotoTagRepository
	}
	
	override fun create(context: Context) {
		val entryPoint = EntryPointAccessors.fromApplication(
			context.applicationContext,
			TagSyncInitializerEntryPoint::class.java
		)
		
		val repository = entryPoint.photoTagRepository()
		
		// Launch sync in background
		val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
		scope.launch {
			try {
				// First, check if we need to migrate from Room to backup service
				// This will be a one-time operation after the update
				val prefs = context.getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
				val hasMigrated = prefs.getBoolean("tags_migrated_to_backup", false)
				
				if (!hasMigrated) {
					// Migrate existing tags to backup service
					repository.migrateToBackupService()
					prefs.edit().putBoolean("tags_migrated_to_backup", true).apply()
				}
				
				// Always sync from backup service on startup
				// This restores tags from backup if this is a fresh install
				repository.syncFromBackupService()
			} catch (e: Exception) {
				// Log error but don't crash the app
				e.printStackTrace()
			}
		}
	}
	
	override fun dependencies(): List<Class<out Initializer<*>>> {
		// We depend on WorkManager being initialized first
		return listOf(androidx.work.WorkManagerInitializer::class.java)
	}
}
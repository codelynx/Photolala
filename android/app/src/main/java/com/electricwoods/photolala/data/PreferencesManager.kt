package com.electricwoods.photolala.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import com.electricwoods.photolala.utils.DeviceUtils
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PreferencesManager @Inject constructor(
	@ApplicationContext private val context: Context,
	private val dataStore: DataStore<Preferences>
) {
	companion object {
		// View preferences
		val PHOTO_VIEWER_SCALE_MODE = stringPreferencesKey("photo_viewer_scale_mode")
		val GRID_THUMBNAIL_SIZE = intPreferencesKey("grid_thumbnail_size")
		val GRID_SCALE_MODE = stringPreferencesKey("grid_scale_mode")
		val SHOW_INFO_BAR = booleanPreferencesKey("show_info_bar")
		
		// User authentication
		val ENCRYPTED_USER_DATA = stringPreferencesKey("encrypted_user_data")
		
		// Default values
		const val DEFAULT_SCALE_MODE = "fit" // "fit" or "fill"
		const val DEFAULT_THUMBNAIL_SIZE = 100 // Will be overridden by device-aware default
		const val DEFAULT_GRID_SCALE_MODE = "fill" // Grid defaults to fill for better appearance
		const val DEFAULT_SHOW_INFO_BAR = true // Show info bar by default like iOS
	}
	
	// Device-aware default values
	private val defaultThumbnailSize: Int by lazy {
		DeviceUtils.getRecommendedThumbnailSizes(context)[1].first // Medium size
	}
	
	
	// Photo viewer scale mode preference
	val photoViewerScaleMode: Flow<String> = dataStore.data
		.catch { exception ->
			if (exception is IOException) {
				emit(emptyPreferences())
			} else {
				throw exception
			}
		}
		.map { preferences ->
			preferences[PHOTO_VIEWER_SCALE_MODE] ?: DEFAULT_SCALE_MODE
		}
	
	suspend fun setPhotoViewerScaleMode(mode: String) {
		dataStore.edit { preferences ->
			preferences[PHOTO_VIEWER_SCALE_MODE] = mode
		}
	}
	
	// Grid thumbnail size preference
	val gridThumbnailSize: Flow<Int> = dataStore.data
		.catch { exception ->
			if (exception is IOException) {
				emit(emptyPreferences())
			} else {
				throw exception
			}
		}
		.map { preferences ->
			preferences[GRID_THUMBNAIL_SIZE] ?: defaultThumbnailSize
		}
	
	suspend fun setGridThumbnailSize(size: Int) {
		dataStore.edit { preferences ->
			preferences[GRID_THUMBNAIL_SIZE] = size
		}
	}
	
	// Grid scale mode preference
	val gridScaleMode: Flow<String> = dataStore.data
		.catch { exception ->
			if (exception is IOException) {
				emit(emptyPreferences())
			} else {
				throw exception
			}
		}
		.map { preferences ->
			preferences[GRID_SCALE_MODE] ?: DEFAULT_GRID_SCALE_MODE
		}
	
	suspend fun setGridScaleMode(mode: String) {
		dataStore.edit { preferences ->
			preferences[GRID_SCALE_MODE] = mode
		}
	}
	
	// Show info bar preference
	val showInfoBar: Flow<Boolean> = dataStore.data
		.catch { exception ->
			if (exception is IOException) {
				emit(emptyPreferences())
			} else {
				throw exception
			}
		}
		.map { preferences ->
			preferences[SHOW_INFO_BAR] ?: DEFAULT_SHOW_INFO_BAR
		}
	
	suspend fun setShowInfoBar(show: Boolean) {
		dataStore.edit { preferences ->
			preferences[SHOW_INFO_BAR] = show
		}
	}
	
	// User authentication preferences
	suspend fun setEncryptedUserData(encryptedData: String) {
		dataStore.edit { preferences ->
			preferences[ENCRYPTED_USER_DATA] = encryptedData
		}
	}
	
	fun getEncryptedUserData(): String? {
		return runBlocking {
			try {
				dataStore.data.first()[ENCRYPTED_USER_DATA]
			} catch (e: Exception) {
				null
			}
		}
	}
	
	suspend fun clearUserData() {
		dataStore.edit { preferences ->
			preferences.remove(ENCRYPTED_USER_DATA)
		}
	}
}
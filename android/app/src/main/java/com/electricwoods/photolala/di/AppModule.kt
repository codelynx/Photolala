package com.electricwoods.photolala.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import androidx.room.Room
import com.electricwoods.photolala.data.local.PhotolalaDatabase
import com.electricwoods.photolala.services.MediaStoreService
import com.electricwoods.photolala.services.MediaStoreServiceImpl
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import javax.inject.Qualifier
import javax.inject.Singleton

// Create extension for DataStore
val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "photolala_preferences")

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

	@Provides
	@Singleton
	fun provideDataStore(
		@ApplicationContext context: Context
	): DataStore<Preferences> = context.dataStore

	@Provides
	@Singleton
	fun provideDatabase(
		@ApplicationContext context: Context
	): PhotolalaDatabase {
		return Room.databaseBuilder(
			context,
			PhotolalaDatabase::class.java,
			"photolala_database"
		)
			.fallbackToDestructiveMigration() // For development only
			.build()
	}
	
	@Provides
	fun provideTagDao(database: PhotolalaDatabase) = database.tagDao()

	@Provides
	@IoDispatcher
	fun provideIoDispatcher(): CoroutineDispatcher = Dispatchers.IO

	@Provides
	@MainDispatcher
	fun provideMainDispatcher(): CoroutineDispatcher = Dispatchers.Main

	@Provides
	@DefaultDispatcher
	fun provideDefaultDispatcher(): CoroutineDispatcher = Dispatchers.Default
}

// Service bindings module
@Module
@InstallIn(SingletonComponent::class)
abstract class ServiceModule {
	
	@Binds
	abstract fun bindMediaStoreService(
		mediaStoreServiceImpl: MediaStoreServiceImpl
	): MediaStoreService
}

// Qualifiers for different dispatchers
@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class IoDispatcher

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class MainDispatcher

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class DefaultDispatcher
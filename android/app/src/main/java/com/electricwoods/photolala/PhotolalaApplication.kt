package com.electricwoods.photolala

import android.app.Application
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.disk.DiskCache
import coil.memory.MemoryCache
import coil.request.CachePolicy
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class PhotolalaApplication : Application(), ImageLoaderFactory {
	override fun onCreate() {
		super.onCreate()
		// Initialize any app-wide configurations here
	}
	
	override fun newImageLoader(): ImageLoader {
		return ImageLoader.Builder(this)
			.memoryCache {
				MemoryCache.Builder(this)
					.maxSizePercent(0.25) // Use 25% of available memory
					.build()
			}
			.diskCache {
				DiskCache.Builder()
					.directory(cacheDir.resolve("image_cache"))
					.maxSizePercent(0.05) // Use 5% of available disk space
					.build()
			}
			.respectCacheHeaders(false) // Don't respect cache headers from server
			.crossfade(true) // Enable crossfade animations
			.memoryCachePolicy(CachePolicy.ENABLED)
			.diskCachePolicy(CachePolicy.ENABLED)
			.build()
	}
}
package com.electricwoods.photolala

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class PhotolalaApplication : Application() {
	override fun onCreate() {
		super.onCreate()
		// Initialize any app-wide configurations here
	}
}
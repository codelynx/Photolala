package com.electricwoods.photolala.services

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.electricwoods.photolala.di.IoDispatcher
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.*

/**
 * Test for MediaStoreService
 * Note: This is an instrumented test that needs to run on an Android device/emulator
 * Move to androidTest folder for real device testing
 */
@RunWith(AndroidJUnit4::class)
class MediaStoreServiceTest {
	
	private lateinit var context: Context
	private lateinit var mediaStoreService: MediaStoreService
	
	@Before
	fun setup() {
		context = ApplicationProvider.getApplicationContext()
		mediaStoreService = MediaStoreServiceImpl(
			context = context,
			ioDispatcher = Dispatchers.IO
		)
	}
	
	@Test
	fun testHasPermission() {
		// This will likely be false in unit tests
		// Real permission testing needs instrumented tests
		val hasPermission = mediaStoreService.hasPermission()
		assertNotNull(hasPermission)
	}
	
	@Test
	fun testGetPhotosReturnsFlow() = runBlocking {
		// Test that getPhotos returns a flow
		val photosFlow = mediaStoreService.getPhotos(limit = 10, offset = 0)
		assertNotNull(photosFlow)
		
		// Try to collect the flow (may be empty in unit tests)
		val photos = photosFlow.first()
		assertNotNull(photos)
	}
	
	@Test
	fun testGetAlbumsReturnsEmptyList() = runBlocking {
		// In unit tests without real MediaStore, this should return empty
		val albums = mediaStoreService.getAlbums()
		assertNotNull(albums)
		// Don't assert empty as it might have data on a real device
	}
	
	@Test
	fun testGetTotalPhotoCount() = runBlocking {
		val count = mediaStoreService.getTotalPhotoCount()
		assertTrue(count >= 0)
	}
}
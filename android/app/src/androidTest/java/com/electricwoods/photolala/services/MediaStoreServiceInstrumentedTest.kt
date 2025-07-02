package com.electricwoods.photolala.services

import android.Manifest
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.rule.GrantPermissionRule
import com.electricwoods.photolala.models.PhotoMediaStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.*

/**
 * Instrumented test for MediaStoreService
 * This runs on an Android device/emulator with real MediaStore access
 */
@RunWith(AndroidJUnit4::class)
class MediaStoreServiceInstrumentedTest {
	
	@get:Rule
	val permissionRule: GrantPermissionRule = GrantPermissionRule.grant(
		Manifest.permission.READ_MEDIA_IMAGES,
		Manifest.permission.READ_EXTERNAL_STORAGE
	)
	
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
	fun testHasPermissionReturnsTrue() {
		assertTrue("Should have media permission", mediaStoreService.hasPermission())
	}
	
	@Test
	fun testGetPhotosWithPagination() = runBlocking {
		// Test first page
		val firstPage = mediaStoreService.getPhotos(limit = 10, offset = 0).first()
		assertNotNull("First page should not be null", firstPage)
		assertTrue("First page size should be <= 10", firstPage.size <= 10)
		
		// Test second page
		val secondPage = mediaStoreService.getPhotos(limit = 10, offset = 10).first()
		assertNotNull("Second page should not be null", secondPage)
		
		// Verify no overlap between pages
		if (firstPage.isNotEmpty() && secondPage.isNotEmpty()) {
			val firstPageIds = firstPage.map { it.mediaStoreId }.toSet()
			val secondPageIds = secondPage.map { it.mediaStoreId }.toSet()
			assertTrue("Pages should not overlap", firstPageIds.intersect(secondPageIds).isEmpty())
		}
	}
	
	@Test
	fun testGetAlbums() = runBlocking {
		val albums = mediaStoreService.getAlbums()
		assertNotNull("Albums should not be null", albums)
		
		// If there are albums, verify they have proper data
		albums.forEach { album ->
			assertTrue("Album should have valid ID", album.id > 0)
			assertNotNull("Album should have name", album.name)
			assertTrue("Album should have photo count", album.photoCount > 0)
		}
	}
	
	@Test
	fun testGetPhotoById() = runBlocking {
		// First get some photos
		val photos = mediaStoreService.getPhotos(limit = 1, offset = 0).first()
		
		if (photos.isNotEmpty()) {
			val firstPhoto = photos.first()
			val retrievedPhoto = mediaStoreService.getPhotoById(firstPhoto.mediaStoreId)
			
			assertNotNull("Retrieved photo should not be null", retrievedPhoto)
			assertEquals("Photo IDs should match", firstPhoto.mediaStoreId, retrievedPhoto?.mediaStoreId)
			assertEquals("Photo URIs should match", firstPhoto.uri, retrievedPhoto?.uri)
		}
	}
	
	@Test
	fun testLoadThumbnail() = runBlocking {
		// Get a photo to test with
		val photos = mediaStoreService.getPhotos(limit = 1, offset = 0).first()
		
		if (photos.isNotEmpty()) {
			val photo = photos.first()
			val thumbnail = mediaStoreService.loadThumbnail(photo, size = 256)
			
			assertNotNull("Thumbnail should not be null", thumbnail)
			assertTrue("Thumbnail should have data", thumbnail!!.isNotEmpty())
		}
	}
	
	@Test
	fun testPhotoProperties() = runBlocking {
		val photos = mediaStoreService.getPhotos(limit = 5, offset = 0).first()
		
		photos.forEach { photo ->
			// Verify required properties
			assertTrue("Photo should have valid ID", photo.mediaStoreId > 0)
			assertNotNull("Photo should have URI", photo.uri)
			assertNotNull("Photo should have filename", photo.filename)
			assertEquals("Photo ID should match gmp# format", "gmp#${photo.mediaStoreId}", photo.id)
			
			// Log photo info for debugging
			println("Photo: ${photo.filename}, Size: ${photo.fileSize}, ${photo.width}x${photo.height}")
		}
	}
}
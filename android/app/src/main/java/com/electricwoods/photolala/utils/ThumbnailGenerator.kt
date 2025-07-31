package com.electricwoods.photolala.utils

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.min

/**
 * Generates thumbnails matching iOS implementation
 * - Scales shorter side to 256px
 * - Crops to maximum 512x512 from center
 * - JPEG format with 0.8 quality
 */
@Singleton
class ThumbnailGenerator @Inject constructor(
	@ApplicationContext private val context: Context
) {
	companion object {
		private const val TAG = "ThumbnailGenerator"
		private const val MIN_SIDE_SIZE = 256
		private const val MAX_SIZE = 512
		private const val JPEG_QUALITY = 80 // 0.8 * 100
	}
	
	/**
	 * Generate thumbnail from photo URI
	 * @return JPEG byte array of thumbnail, null if failed
	 */
	suspend fun generateThumbnail(photoUri: Uri): ByteArray? = withContext(Dispatchers.IO) {
		try {
			// Load original image
			val options = BitmapFactory.Options().apply {
				inJustDecodeBounds = true
			}
			
			context.contentResolver.openInputStream(photoUri)?.use { input ->
				BitmapFactory.decodeStream(input, null, options)
			}
			
			val originalWidth = options.outWidth
			val originalHeight = options.outHeight
			
			if (originalWidth <= 0 || originalHeight <= 0) {
				Log.e(TAG, "Invalid image dimensions")
				return@withContext null
			}
			
			// Calculate scale factor - scale so shorter side becomes 256px
			val minSide = min(originalWidth, originalHeight)
			val scale = MIN_SIDE_SIZE.toFloat() / minSide.toFloat()
			
			// Calculate scaled dimensions
			val scaledWidth = (originalWidth * scale).toInt()
			val scaledHeight = (originalHeight * scale).toInt()
			
			// Calculate crop dimensions (max 512x512)
			val cropWidth = min(scaledWidth, MAX_SIZE)
			val cropHeight = min(scaledHeight, MAX_SIZE)
			
			// Calculate sample size for efficient loading
			val sampleSize = calculateSampleSize(originalWidth, originalHeight, cropWidth, cropHeight)
			
			// Load and scale bitmap
			val scaledBitmap = context.contentResolver.openInputStream(photoUri)?.use { input ->
				val decodeOptions = BitmapFactory.Options().apply {
					inSampleSize = sampleSize
				}
				val bitmap = BitmapFactory.decodeStream(input, null, decodeOptions)
				bitmap?.let { scaleBitmap(it, scaledWidth, scaledHeight) }
			}
			
			if (scaledBitmap == null) {
				Log.e(TAG, "Failed to decode bitmap")
				return@withContext null
			}
			
			// Crop from center
			val croppedBitmap = centerCrop(scaledBitmap, cropWidth, cropHeight)
			
			// Convert to JPEG
			val outputStream = ByteArrayOutputStream()
			croppedBitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, outputStream)
			
			// Clean up
			scaledBitmap.recycle()
			croppedBitmap.recycle()
			
			return@withContext outputStream.toByteArray()
			
		} catch (e: Exception) {
			Log.e(TAG, "Failed to generate thumbnail", e)
			return@withContext null
		}
	}
	
	/**
	 * Calculate optimal sample size for loading large images
	 */
	private fun calculateSampleSize(
		originalWidth: Int,
		originalHeight: Int,
		targetWidth: Int,
		targetHeight: Int
	): Int {
		var sampleSize = 1
		
		if (originalHeight > targetHeight || originalWidth > targetWidth) {
			val halfHeight = originalHeight / 2
			val halfWidth = originalWidth / 2
			
			while ((halfHeight / sampleSize) >= targetHeight &&
				   (halfWidth / sampleSize) >= targetWidth) {
				sampleSize *= 2
			}
		}
		
		return sampleSize
	}
	
	/**
	 * Scale bitmap to exact dimensions
	 */
	private fun scaleBitmap(source: Bitmap, targetWidth: Int, targetHeight: Int): Bitmap {
		val scaleX = targetWidth.toFloat() / source.width
		val scaleY = targetHeight.toFloat() / source.height
		
		val matrix = Matrix().apply {
			postScale(scaleX, scaleY)
		}
		
		return Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
	}
	
	/**
	 * Center crop bitmap to specified dimensions
	 */
	private fun centerCrop(source: Bitmap, targetWidth: Int, targetHeight: Int): Bitmap {
		val width = min(source.width, targetWidth)
		val height = min(source.height, targetHeight)
		
		val x = (source.width - width) / 2
		val y = (source.height - height) / 2
		
		return Bitmap.createBitmap(source, x, y, width, height)
	}
}
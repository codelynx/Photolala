package com.electricwoods.photolala.utils

import android.content.Context
import android.content.res.Configuration
import android.util.DisplayMetrics

object DeviceUtils {
	
	/**
	 * Device size categories based on smallest width
	 */
	enum class DeviceCategory {
		COMPACT,    // < 380dp (small phones)
		MEDIUM,     // 380-450dp (regular phones)
		EXPANDED    // > 450dp (large phones, tablets)
	}
	
	/**
	 * Get device category based on smallest width
	 */
	fun getDeviceCategory(context: Context): DeviceCategory {
		val smallestWidth = context.resources.configuration.smallestScreenWidthDp
		return when {
			smallestWidth < 380 -> DeviceCategory.COMPACT
			smallestWidth < 450 -> DeviceCategory.MEDIUM
			else -> DeviceCategory.EXPANDED
		}
	}
	
	/**
	 * Get recommended thumbnail sizes based on device category
	 */
	fun getRecommendedThumbnailSizes(context: Context): List<Pair<Int, String>> {
		return when (getDeviceCategory(context)) {
			DeviceCategory.COMPACT -> listOf(
				64 to "Small",
				80 to "Medium",
				100 to "Large"
			)
			DeviceCategory.MEDIUM -> listOf(
				80 to "Small",
				100 to "Medium",
				128 to "Large"
			)
			DeviceCategory.EXPANDED -> listOf(
				100 to "Small",
				128 to "Medium",
				160 to "Large"
			)
		}
	}
	
	/**
	 * Get recommended column count range based on device category and orientation
	 */
	fun getRecommendedColumnRange(context: Context): IntRange {
		val isLandscape = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
		
		return when (getDeviceCategory(context)) {
			DeviceCategory.COMPACT -> if (isLandscape) 4..7 else 3..5
			DeviceCategory.MEDIUM -> if (isLandscape) 5..8 else 3..6
			DeviceCategory.EXPANDED -> if (isLandscape) 6..10 else 4..8
		}
	}
	
	/**
	 * Calculate optimal column count based on screen width and thumbnail size
	 */
	fun calculateOptimalColumns(
		context: Context,
		thumbnailSize: Int,
		minSpacing: Int = 2
	): Int {
		val displayMetrics = context.resources.displayMetrics
		val screenWidth = displayMetrics.widthPixels
		val dpWidth = screenWidth / displayMetrics.density
		
		// Calculate how many items can fit with spacing
		val itemWidthWithSpacing = thumbnailSize + minSpacing
		val columns = (dpWidth / itemWidthWithSpacing).toInt()
		
		// Ensure we're within recommended range
		val range = getRecommendedColumnRange(context)
		return columns.coerceIn(range)
	}
}
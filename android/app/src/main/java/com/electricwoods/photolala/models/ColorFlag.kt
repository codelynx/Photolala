package com.electricwoods.photolala.models

/**
 * Color flag enum matching iOS ColorFlag
 * Used for tagging photos with color labels
 */
enum class ColorFlag(val value: Int, val colorName: String, val hexColor: String) {
	RED(1, "Red", "#FF3B30"),
	ORANGE(2, "Orange", "#FF9500"),
	YELLOW(3, "Yellow", "#FFCC00"),
	GREEN(4, "Green", "#34C759"),
	BLUE(5, "Blue", "#007AFF"),
	PURPLE(6, "Purple", "#AF52DE"),
	GRAY(7, "Gray", "#8E8E93");
	
	companion object {
		fun fromValue(value: Int): ColorFlag? = values().find { it.value == value }
	}
}
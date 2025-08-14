package com.electricwoods.photolala.models

/**
 * Display mode for images
 */
enum class DisplayMode {
    FIT,    // Scale to fit within bounds
    FILL    // Scale to fill bounds (may crop)
}

/**
 * Thumbnail size options
 */
enum class ThumbnailSize {
    SMALL,
    MEDIUM,
    LARGE
}

/**
 * Grouping options for photo organization
 */
enum class GroupingOption {
    NONE,
    YEAR,
    YEAR_MONTH
}
package com.electricwoods.photolala.ui.components.menu

import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.electricwoods.photolala.models.DisplayMode
import com.electricwoods.photolala.models.GroupingOption
import com.electricwoods.photolala.models.ThumbnailSize

/**
 * View settings data class to hold all view-related options
 */
data class ViewSettings(
    val displayMode: DisplayMode = DisplayMode.FIT,
    val thumbnailSize: ThumbnailSize = ThumbnailSize.MEDIUM,
    val showItemInfo: Boolean = false,
    val groupingOption: GroupingOption = GroupingOption.NONE
)

/**
 * A comprehensive view options menu matching iOS/macOS structure
 */
@Composable
fun ViewOptionsMenu(
    expanded: Boolean,
    onDismiss: () -> Unit,
    viewSettings: ViewSettings,
    onViewSettingsChange: (ViewSettings) -> Unit,
    modifier: Modifier = Modifier,
    showGrouping: Boolean = true,
    showThumbnailSize: Boolean = true
) {
    var displaySubmenuExpanded by remember { mutableStateOf(false) }
    var thumbnailSizeSubmenuExpanded by remember { mutableStateOf(false) }

    DropdownMenu(
        expanded = expanded,
        onDismissRequest = {
            displaySubmenuExpanded = false
            thumbnailSizeSubmenuExpanded = false
            onDismiss()
        },
        modifier = modifier
    ) {
        // Display submenu
        NestedDropdownMenuItem(
            text = "Display",
            expanded = displaySubmenuExpanded,
            onExpandedChange = { displaySubmenuExpanded = it }
        ) {
            RadioButtonMenuItem(
                text = "Scale to Fit",
                selected = viewSettings.displayMode == DisplayMode.FIT,
                onClick = {
                    onViewSettingsChange(viewSettings.copy(displayMode = DisplayMode.FIT))
                    displaySubmenuExpanded = false
                }
            )
            RadioButtonMenuItem(
                text = "Scale to Fill",
                selected = viewSettings.displayMode == DisplayMode.FILL,
                onClick = {
                    onViewSettingsChange(viewSettings.copy(displayMode = DisplayMode.FILL))
                    displaySubmenuExpanded = false
                }
            )
        }
        
        // Thumbnail Size submenu (only if enabled)
        if (showThumbnailSize) {
            NestedDropdownMenuItem(
                text = "Thumbnail Size",
                expanded = thumbnailSizeSubmenuExpanded,
                onExpandedChange = { thumbnailSizeSubmenuExpanded = it }
            ) {
                RadioButtonMenuItem(
                    text = "Small",
                    selected = viewSettings.thumbnailSize == ThumbnailSize.SMALL,
                    onClick = {
                        onViewSettingsChange(viewSettings.copy(thumbnailSize = ThumbnailSize.SMALL))
                        thumbnailSizeSubmenuExpanded = false
                    }
                )
                RadioButtonMenuItem(
                    text = "Medium",
                    selected = viewSettings.thumbnailSize == ThumbnailSize.MEDIUM,
                    onClick = {
                        onViewSettingsChange(viewSettings.copy(thumbnailSize = ThumbnailSize.MEDIUM))
                        thumbnailSizeSubmenuExpanded = false
                    }
                )
                RadioButtonMenuItem(
                    text = "Large",
                    selected = viewSettings.thumbnailSize == ThumbnailSize.LARGE,
                    onClick = {
                        onViewSettingsChange(viewSettings.copy(thumbnailSize = ThumbnailSize.LARGE))
                        thumbnailSizeSubmenuExpanded = false
                    }
                )
            }
        }
        
        // Group By section (only if enabled)
        if (showGrouping) {
            HorizontalDivider()
            
            DropdownMenuLabel("Group By")
            
            RadioButtonMenuItem(
                text = "None",
                selected = viewSettings.groupingOption == GroupingOption.NONE,
                onClick = {
                    onViewSettingsChange(viewSettings.copy(groupingOption = GroupingOption.NONE))
                }
            )
            RadioButtonMenuItem(
                text = "Year",
                selected = viewSettings.groupingOption == GroupingOption.YEAR,
                onClick = {
                    onViewSettingsChange(viewSettings.copy(groupingOption = GroupingOption.YEAR))
                }
            )
            RadioButtonMenuItem(
                text = "Year/Month",
                selected = viewSettings.groupingOption == GroupingOption.YEAR_MONTH,
                onClick = {
                    onViewSettingsChange(viewSettings.copy(groupingOption = GroupingOption.YEAR_MONTH))
                }
            )
        }
        
        HorizontalDivider()
        
        // Show Item Info toggle
        CheckboxMenuItem(
            text = "Show Item Info",
            checked = viewSettings.showItemInfo,
            onCheckedChange = { checked ->
                onViewSettingsChange(viewSettings.copy(showItemInfo = checked))
            }
        )
    }
}

/**
 * Icon button that shows the view options menu
 */
@Composable
fun ViewOptionsMenuButton(
    viewSettings: ViewSettings,
    onViewSettingsChange: (ViewSettings) -> Unit,
    modifier: Modifier = Modifier,
    showGrouping: Boolean = true,
    showThumbnailSize: Boolean = true
) {
    var expanded by remember { mutableStateOf(false) }
    
    Box(modifier = modifier) {
        IconButton(
            onClick = { expanded = true }
        ) {
            Icon(
                imageVector = Icons.Default.Tune,
                contentDescription = "View options"
            )
        }
        
        ViewOptionsMenu(
            expanded = expanded,
            onDismiss = { expanded = false },
            viewSettings = viewSettings,
            onViewSettingsChange = onViewSettingsChange,
            showGrouping = showGrouping,
            showThumbnailSize = showThumbnailSize
        )
    }
}
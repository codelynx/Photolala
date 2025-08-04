# Android Toolbar Reorganization Plan

## Overview

This document outlines the plan to reorganize the Android toolbar implementation to match the iOS/macOS structure while following Material Design 3 guidelines.

## Current State Analysis

### Existing Toolbar Implementations

1. **PhotoGridScreen (Local Browser)**
   - Normal mode: Title, optional back, refresh button, GridViewOptionsMenu (Tune icon)
   - Selection mode: Selection count, close button, action buttons (Select All, Tag, Star, Share, Delete)

2. **CloudBrowserScreen**
   - Normal mode: Title, back button, search toggle, refresh button
   - Selection mode: Selection count, download, select all, clear selection

3. **PhotoViewerScreen**
   - Title (filename), back button, info button, ViewOptionsMenu (three dots)

4. **AccountSettingsScreen**
   - Title, back button, no overflow menu

### Current View Options

**GridViewOptionsMenu** (PhotoGridScreen):
- Thumbnail Size (radio buttons)
- Scale Mode (Scale to Fit/Fill)
- Show Info Bar (checkbox)

**ViewOptionsMenu** (PhotoViewerScreen):
- Scale Mode only

### Issues with Current Implementation

1. **Inconsistent menu patterns** - Different screens use different approaches
2. **Scattered view options** - No unified structure
3. **Missing overflow menus** - Some screens lack additional actions
4. **Different icons** - Tune vs MoreVert for similar functions

## Proposed Reorganization

### 1. Unified View Options Menu Structure

Create a consistent ViewOptionsMenu matching iOS/macOS hierarchy:

```
View Menu (Tune icon)
├── Display ▶ (submenu)
│   ├── ◉ Scale to Fit
│   └── ○ Scale to Fill
├── Thumbnail Size ▶ (submenu)
│   ├── ○ Small
│   ├── ◉ Medium
│   └── ○ Large
├── ─────────────────
├── Group By (section label)
│   ├── ◉ None
│   ├── ○ Year
│   └── ○ Year/Month
├── ─────────────────
└── ☑ Show Item Info
```

### 2. Implementation Approach

#### Create Reusable Components

```kotlin
@Composable
fun ViewOptionsMenu(
    expanded: Boolean,
    onDismiss: () -> Unit,
    viewSettings: ViewSettings,
    onViewSettingsChange: (ViewSettings) -> Unit,
    showGrouping: Boolean = true
)

@Composable
fun NestedDropdownMenuItem(
    text: @Composable () -> Unit,
    children: @Composable ColumnScope.() -> Unit
)

@Composable
fun RadioButtonMenuItem(
    text: String,
    selected: Boolean,
    onClick: () -> Unit
)

@Composable
fun CheckboxMenuItem(
    text: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
)
```

#### TopAppBar Integration

```kotlin
TopAppBar(
    title = { Text("Local Browser") },
    navigationIcon = { /* Back button if needed */ },
    actions = {
        // Direct actions (frequently used)
        IconButton(onClick = onRefresh) {
            Icon(Icons.Default.Refresh, "Refresh")
        }
        
        // View options menu
        Box {
            IconButton(onClick = { showViewMenu = true }) {
                Icon(Icons.Default.Tune, "View options")
            }
            ViewOptionsMenu(
                expanded = showViewMenu,
                onDismiss = { showViewMenu = false },
                viewSettings = viewSettings,
                onViewSettingsChange = onViewSettingsChange
            )
        }
        
        // Overflow menu for additional actions
        OverflowMenu(
            onSettingsClick = { /* Navigate to settings */ },
            onHelpClick = { /* Show help */ }
        )
    }
)
```

### 3. Screen-Specific Configurations

#### PhotoGridScreen (Local Browser)
- **Direct buttons**: Refresh
- **View menu**: Full options (Display, Thumbnail Size, Group By, Show Info)
- **Overflow**: Settings, Help, About

#### CloudBrowserScreen
- **Direct buttons**: Search toggle, Refresh
- **View menu**: Full options
- **Overflow**: Offline mode toggle, Settings

#### PhotoViewerScreen
- **Direct buttons**: Info
- **View menu**: Display options only
- **Overflow**: Share, Print, Save As

#### AccountSettingsScreen
- **Direct buttons**: None
- **View menu**: Not applicable
- **Overflow**: Sign Out, Delete Account

### 4. Selection Mode Behavior

Maintain current pattern where selection mode replaces the toolbar, but ensure view options remain accessible:

```kotlin
if (selectionMode) {
    SelectionModeTopAppBar(
        selectedCount = selectedItems.size,
        onClearSelection = { /* Clear */ },
        actions = {
            // Selection-specific actions
            IconButton(onClick = onSelectAll) {
                Icon(Icons.Default.SelectAll, "Select all")
            }
            // View menu still available
            ViewOptionsMenuButton(compact = true)
        }
    )
} else {
    RegularTopAppBar(/* ... */)
}
```

### 5. Material Design 3 Compliance

- Use **IconButton** for single actions
- Use **DropdownMenu** for menu containers
- Use **HorizontalDivider** for visual separation
- Follow **Material You** theming
- Implement **nested menus** using Box positioning
- Use standard icons from **Icons.Default**

### 6. Benefits

1. **Cross-platform consistency** - Same menu structure as iOS/macOS
2. **Material compliance** - Follows Material Design 3 guidelines
3. **Improved organization** - Logical grouping of related options
4. **Reduced clutter** - Less frequently used items in submenus
5. **Better discoverability** - All view options in one place
6. **Scalability** - Easy to add new options

## Implementation Priority

1. **Phase 1**: Create reusable menu components
2. **Phase 2**: Implement ViewOptionsMenu with full structure
3. **Phase 3**: Update PhotoGridScreen as pilot
4. **Phase 4**: Roll out to other screens
5. **Phase 5**: Add overflow menus where missing

## Testing Considerations

- Test on different screen sizes (phones and tablets)
- Verify menu dismissal behavior
- Ensure state persistence across configuration changes
- Test keyboard navigation (if applicable)
- Verify accessibility with TalkBack

## Migration Notes

- Preserve existing settings/preferences
- Update help documentation
- Consider A/B testing the new menu structure
- Gather user feedback during rollout
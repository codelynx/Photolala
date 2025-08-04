# Toolbar Reorganization Plan

## Overview

This document outlines a plan to reorganize the Photolala toolbar to improve usability, reduce clutter, and provide a more logical grouping of related functions.

## Current State Analysis

### Existing Toolbar Items

The current toolbar contains the following items across different browser contexts:

#### Core Items (All Browsers)
- **View Options** (iOS: in gear menu, macOS: separate controls)
  - Display mode toggle (Scale to Fit/Fill)
  - Item info bar toggle
  - Thumbnail size picker (Small/Medium/Large)
- **Refresh button** - Refreshes folder contents
- **Inspector button** - Shows/hides the inspector panel

#### Directory Browser Additional Items
- **Account Management** - Sign In button or User Account menu
- **Backup Queue Indicator** - Shows starred photo count
- **Preview Button** - Visible when photos are selected
- **Grouping Picker** - Year, Month, Day, or None
- **Backup Button** - Visible when photos are selected and S3 enabled

#### Context-Specific Items
- **Albums Button** (Apple Photos browser)
- **Offline Indicator** (S3 browser)
- **Selection Count** (S3 browser)

### Current Issues

1. **Toolbar Crowding** - Limited space, especially on smaller screens
2. **Inconsistent Placement** - Items appear in different orders
3. **Flat Hierarchy** - Most items at the same level
4. **Mixed Priorities** - Frequently and rarely used items compete for space

## Proposed Reorganization

### Direct Toolbar Items (Always Visible)

These items remain in the main toolbar for quick access:

1. **Refresh** - Frequently used, single-click action
2. **Preview** - Essential when photos selected (contextual visibility)
3. **Inspector** - Toggle for side panel
4. **View Menu** - New consolidated menu for all view options (includes grouping)
5. **Account/Sign In** - Important for cloud features
6. **Backup Queue** - Status indicator (when items queued)

### View Menu Structure

Accessed via gear icon (iOS) or "View" label (macOS):

```
View
├── Display ▶ (submenu)
│   ├── ✓ Scale to Fit
│   └── Scale to Fill
├── Thumbnail Size ▶ (submenu)
│   ├── Small
│   ├── ✓ Medium
│   └── Large
├── ─────────────────
├── Group By (inline picker)
│   ├── ✓ None
│   ├── Year
│   └── Year/Month
├── ─────────────────
└── ✓ Show Item Info (toggle)
```

Note: Photos without dates will be placed in an "Unknown" section when grouping is enabled.

## Benefits of Simplified Approach

By removing sort options and limiting grouping choices, we:
- Further reduce menu complexity
- Focus on the most useful grouping options (None, Year, Year/Month)
- Eliminate rarely-used options
- Make the interface more approachable

## Implementation Details

### Technical Approach

- **Submenus**: Display and Thumbnail Size use `Menu` containing `Picker` with `.pickerStyle(.inline)`
- **Inline Picker**: Group By uses `Picker` directly in the menu for flat selection
- **Toggle Button**: Show Item Info uses `Button` with conditional checkmark
- **Automatic Checkmarks**: SwiftUI `Picker` handles checkmark display automatically

### Platform Differences

- **iOS**: Menu accessed via gear icon (`gearshape`)
- **macOS**: Menu accessed via "View" button with chevron
- **Unified Implementation**: Same menu structure and behavior on both platforms

### Menu Behavior

- Checkmarks automatically managed by SwiftUI Picker
- Radio button behavior within picker groups
- Immediate apply on selection
- No console warnings (unlike manual checkmark approach)
- Submenus show arrow indicators (▶) automatically

### Visual Design

- Use system-standard menu components
- Clear separators between logical groups
- Icons for menu items where appropriate
- Consistent with platform conventions

## Benefits

1. **Reduced Clutter**: Frees up toolbar space
2. **Logical Grouping**: Related options together
3. **Scalability**: Easy to add new options without toolbar bloat
4. **Consistency**: Same organization across platforms
5. **Discoverability**: Users can find all view options in one place

## Migration Path

1. Implement new menu structure alongside existing controls
2. Add preference for "Use classic toolbar" during transition
3. Gradually phase out old toolbar layout
4. Remove legacy code after user acceptance

## Future Enhancements

The menu structure allows for easy addition of:
- Column count control
- Thumbnail aspect ratio options
- Additional sort criteria
- View presets
- Custom grouping options
# IAP Developer Tools Implementation

## Overview

This document describes the implementation of consolidated IAP (In-App Purchase) developer tools for Photolala. The tools provide a unified interface for testing and debugging IAP functionality during development.

## Implementation Date

June 17, 2025

## Changes Made

### 1. Menu Structure Reorganization

The menu structure was reorganized to address several issues:
- Eliminated duplicate "View" menus (system vs. custom)
- Created a new "Photolala" menu for app-specific features
- Properly separated user-facing features from developer tools

**New Menu Structure:**
```
Photolala (menu)
├── Manage Subscription...
├── ─────────────────────
├── Cloud Backup Settings...
├── ─────────────────────
└── Developer Tools (submenu)
    └── IAP Developer Tools...
```

### 2. Consolidated IAP Developer View

Created `IAPDeveloperView.swift` that consolidates testing and debugging features:

**Features:**
- **Status Tab**: Shows user status, IAP status, and debug info
- **Products Tab**: Lists available products and purchased items
- **Actions Tab**: Provides quick actions and debug tools

**Key Improvements:**
- Tabbed interface for better organization
- Integrated with both IAPManager and IdentityManager
- Proper window sizing and title display
- Informative receipt viewing with explanations

### 3. Receipt Viewing Enhancement

The receipt viewing functionality now provides:
- Clear indication when receipts are missing (normal in development)
- Explanation of when receipts are generated
- Formatted display of receipt data when available

### 4. Window Management

All windows now properly:
- Display window titles
- Use appropriate sizing
- Support resizing and minimizing
- Maintain proper window levels

## Files Changed

### Added
- `Photolala/Views/IAPDeveloperView.swift` - Consolidated developer tools view

### Modified
- `Photolala/Commands/PhotolalaCommands.swift` - Reorganized menu structure
- `Photolala/Views/IAPDebugView.swift` - Fixed compilation issues

### Retained
- `Photolala/Views/IAPTestView.swift` - Original test view (for reference)

## Technical Details

### Window Creation Pattern
```swift
private func showIAPDeveloper() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
        styleMask: [.titled, .closable, .resizable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    
    window.title = "IAP Developer Tools"
    window.center()
    window.contentView = NSHostingView(rootView: IAPDeveloperView())
    window.makeKeyAndOrderFront(nil)
    
    // Ensure title visibility
    window.titleVisibility = .visible
    window.titlebarAppearsTransparent = false
}
```

### TabView Title Bar Issue and Solution

**Problem Discovered**: Using `TabView` with `.tabViewStyle(.automatic)` on macOS causes the content to be pushed into the window's title bar area, making the segmented control appear in the wrong location.

**Solution**: Replace TabView with a manual implementation using switch statement:

```swift
// Instead of problematic TabView:
TabView(selection: $selectedTab) {
    statusTab.tag(ViewTab.status)
    productsTab.tag(ViewTab.products)
    actionsTab.tag(ViewTab.actions)
}
.tabViewStyle(.automatic) // Causes title bar issues

// Working solution:
Picker("", selection: $selectedTab) {
    Text("Status").tag(ViewTab.status)
    Text("Products").tag(ViewTab.products)
    Text("Actions").tag(ViewTab.actions)
}
.pickerStyle(.segmented)

Group {
    switch selectedTab {
    case .status: statusTab
    case .products: productsTab
    case .actions: actionsTab
    }
}
```

This approach maintains the same functionality while avoiding SwiftUI's layout quirks with TabView on macOS.

### Debug Compilation Flag
All developer tools are wrapped in `#if DEBUG` to ensure they don't appear in production builds.

## Testing Guide

1. **Access Developer Tools**:
   - Build in Debug configuration
   - Menu: Photolala → Developer Tools → IAP Developer Tools...

2. **Test Features**:
   - Status Tab: Verify user and IAP status display
   - Products Tab: Check product loading and purchase status
   - Actions Tab: Test various debug actions

3. **Receipt Testing**:
   - Click "View Receipt" in Actions tab
   - Verify informative message about missing receipts in development

## Future Considerations

1. Consider adding export functionality for debug logs
2. Add network request monitoring for IAP transactions
3. Implement mock purchase testing for UI development
4. Consider adding transaction history view

## Related Documentation

- [IAP Testing Guide](./iap-testing-guide.md)
- [Subscription Management Design](../history/design-decisions/subscription-management-design.md)
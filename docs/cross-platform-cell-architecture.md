# Cross-Platform Collection View Cell Architecture

## Overview

This document describes the unified architecture pattern for sharing collection view cell implementations between macOS (NSCollectionView) and iOS/iPadOS (UICollectionView), achieving ~95% code reuse while respecting platform differences.

## The Challenge

macOS and iOS have fundamentally different collection view architectures:
- **macOS**: `NSCollectionViewItem` is a **view controller** that manages a view
- **iOS**: `UICollectionViewCell` is a **view** with a content view

Direct unification through inheritance is problematic because these are different types in the view hierarchy.

## The Solution: Composition Pattern

Instead of forcing inheritance, we use composition to separate concerns:

```
┌─────────────────────────────────────┐
│      Platform-Specific Wrapper      │
├─────────────────────────────────────┤
│   NSCollectionViewItem (macOS)      │
│   UICollectionViewCell (iOS)        │
├─────────────────────────────────────┤
│         Minimal pass-through        │
│         (~30 lines per platform)    │
└────────────┬────────────────────────┘
             │ contains/delegates to
             ▼
┌─────────────────────────────────────┐
│        Shared View Component        │
├─────────────────────────────────────┤
│      PhotoCellView: XView           │
├─────────────────────────────────────┤
│    • All UI components              │
│    • Business logic                 │
│    • Async operations               │
│    • 95% of implementation          │
└─────────────────────────────────────┘
```

## Implementation Structure

### 1. Cross-Platform Type Aliases (`CrossPlatformTypes.swift`)

```swift
#if os(macOS)
import AppKit
typealias XView = NSView
typealias XImageView = NSImageView
typealias XImage = NSImage
typealias XColor = NSColor
typealias XActivityIndicator = NSProgressIndicator
#else
import UIKit
typealias XView = UIView
typealias XImageView = UIImageView
typealias XImage = UIImage
typealias XColor = UIColor
typealias XActivityIndicator = UIActivityIndicatorView
#endif
```

### 2. Shared View Implementation (`PhotoCellView.swift`)

The shared view inherits from `XView` and contains:
- All UI components (image view, loading indicator, selection overlay)
- View setup and constraint configuration
- Business logic (`configure()`, `reset()`, async loading)
- Platform-specific adjustments via `#if os()` where necessary

```swift
class PhotoCellView: XView {
    private var photoImageView: XImageView!
    private var loadingView: XActivityIndicator!

    func configure(with item: PhotoBrowserItem, source: any PhotoSourceProtocol) {
        // Shared implementation
    }

    func reset() {
        // Called by platform wrappers in prepareForReuse
        currentLoadTask?.cancel()
        stopLoading() // Important: stop animations
        photoImageView.image = nil
        // Reset to idle state
    }
}
```

### 3. Platform Wrappers (`PhotoCell.swift`)

Minimal wrappers that integrate with platform-specific collection views:

#### macOS Wrapper
```swift
class PhotoCell: NSCollectionViewItem {
    private var photoCellView: PhotoCellView {
        return view as! PhotoCellView
    }

    override func loadView() {
        self.view = PhotoCellView() // Set the view
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoCellView.reset() // Delegate to shared view
    }
}
```

#### iOS Wrapper
```swift
class PhotoCell: UICollectionViewCell {
    private let photoCellView = PhotoCellView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Add PhotoCellView as subview with constraints
        contentView.addSubview(photoCellView)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoCellView.reset() // Delegate to shared view
    }
}
```

## Key Design Decisions

### 1. Method Naming
- Platform wrappers use standard methods (`prepareForReuse`)
- Shared view uses custom names (`reset()`) to avoid conflicts
- This prevents accidental overrides and makes delegation explicit

### 2. Resource Management
- `reset()` must fully idle the view:
  - Cancel async tasks
  - **Stop animations** (prevents burning CPU in reuse queue)
  - Clear images
  - Reset visual state

### 3. Constraint Management
- Explicit constraints in shared view (crucial for AppKit)
- Platform wrapper handles view hierarchy integration
- macOS: PhotoCellView becomes the item's view
- iOS: PhotoCellView added as contentView subview

### 4. Platform Differences
- Minimize `#if os()` conditionals
- Group platform-specific code in setup methods
- Use type aliases to abstract platform types

## Benefits

1. **Code Reuse**: ~95% of implementation shared
2. **Maintainability**: Single source of truth for cell behavior
3. **Platform Respect**: Preserves native patterns and expectations
4. **Clean Separation**: View logic vs collection integration
5. **Performance**: Proper resource cleanup prevents leaks

## Example: PhotoCell Implementation

### Before (Duplicate Code)
- 264 lines total
- Two complete implementations
- Duplicate bug fixes needed
- Diverging behavior over time

### After (Unified Architecture)
- 89 lines in PhotoCell.swift (wrappers)
- 189 lines in PhotoCellView.swift (shared)
- Single implementation to maintain
- Consistent behavior guaranteed

## Best Practices

1. **Keep wrappers minimal** - Only handle platform integration
2. **Delegate everything** - Pass all logic to shared view
3. **Clean reset** - Ensure complete idle state in `reset()`
4. **Explicit constraints** - Don't rely on autoresizing masks
5. **Test both platforms** - Verify builds and behavior

## Extending the Pattern

This pattern works for any UI component with platform variants:
- Table cells (NSTableCellView vs UITableViewCell)
- Controls (NSButton vs UIButton wrappers)
- Custom views with platform-specific features

The key is identifying the shared behavior and isolating platform integration points.

## Gotchas and Solutions

### Problem: Animation cycles in reuse queue
**Solution**: Always stop animations in `reset()`

### Problem: Different initialization patterns
**Solution**: Handle in wrapper, share setup in view

### Problem: Platform-specific gestures
**Solution**: Add recognizers in shared view with `#if os()`

### Problem: Different selection models
**Solution**: Unified `setSelected()` method in shared view

## Conclusion

This architecture provides maximum code sharing while respecting platform conventions. By using composition instead of inheritance, we avoid fighting the frameworks and create maintainable, performant code that feels native on each platform.
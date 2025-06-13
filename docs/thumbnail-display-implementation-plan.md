# Thumbnail Display Options - Implementation Plan

## Overview

Step-by-step implementation plan for adding thumbnail display customization to Photolala.

## Prerequisites

- [x] PhotoManager with thumbnail generation
- [x] Collection views displaying thumbnails
- [x] Cross-platform architecture

## Implementation Steps

### Step 1: Create Display Settings Model

**File**: `photolala/Models/ThumbnailDisplaySettings.swift`

```swift
import SwiftUI

enum ThumbnailDisplayMode: String, CaseIterable {
    case scaleToFit = "fit"
    case scaleToFill = "fill"
}

@Observable
class ThumbnailDisplaySettings {
    static let shared = ThumbnailDisplaySettings()
    
    var displayMode: ThumbnailDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "thumbnailDisplayMode")
        }
    }
    
    var cellSize: CGFloat {
        didSet {
            UserDefaults.standard.set(cellSize, forKey: "thumbnailCellSize")
        }
    }
    
    private init() {
        let modeString = UserDefaults.standard.string(forKey: "thumbnailDisplayMode") ?? "fit"
        self.displayMode = ThumbnailDisplayMode(rawValue: modeString) ?? .scaleToFit
        self.cellSize = CGFloat(UserDefaults.standard.float(forKey: "thumbnailCellSize"))
        if cellSize == 0 { cellSize = 256 } // Default to Large
    }
}
```

### Step 2: Update Collection View Cell

**File**: `photolala/Views/PhotoCollectionViewController.swift`

Add to PhotoCollectionViewItem/Cell:
```swift
func updateDisplayMode(_ mode: ThumbnailDisplayMode) {
    #if os(macOS)
    imageView?.imageScaling = mode == .scaleToFit ? .scaleProportionallyUpOrDown : .scaleProportionallyDown
    imageView?.imageAlignment = mode == .scaleToFit ? .alignCenter : .alignCenter
    // Add background color for letterboxing in fit mode
    view.wantsLayer = true
    view.layer?.backgroundColor = mode == .scaleToFit ? 
        NSColor.windowBackgroundColor.cgColor : NSColor.clear.cgColor
    #else
    imageView.contentMode = mode == .scaleToFit ? .scaleAspectFit : .scaleAspectFill
    imageView.backgroundColor = mode == .scaleToFit ? .secondarySystemBackground : .clear
    imageView.clipsToBounds = true
    #endif
}
```

### Step 3: Add Toolbar Controls

**macOS** - Update PhotoBrowserView:
```swift
.toolbar {
    ToolbarItemGroup(placement: .primaryAction) {
        // Display mode picker
        Picker("Display", selection: $displaySettings.displayMode) {
            Text("Fit").tag(ThumbnailDisplayMode.scaleToFit)
            Text("Fill").tag(ThumbnailDisplayMode.scaleToFill)
        }
        .pickerStyle(.segmented)
        .help("Toggle between fit and fill display modes")
        
        // Size slider
        Slider(value: $displaySettings.cellSize, in: 100...300, step: 10) {
            Text("Size")
        }
        .frame(width: 150)
        .help("Adjust thumbnail size")
    }
}
```

**iOS** - Add toolbar to PhotoBrowserView:
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
            // Display mode section
            Section("Display Mode") {
                ForEach(ThumbnailDisplayMode.allCases, id: \.self) { mode in
                    Button(action: { displaySettings.displayMode = mode }) {
                        Label(mode.rawValue.capitalized, 
                              systemImage: displaySettings.displayMode == mode ? "checkmark" : "")
                    }
                }
            }
            
            // Size section
            Section("Thumbnail Size") {
                Button("Small", action: { displaySettings.cellSize = 64 })
                Button("Medium", action: { displaySettings.cellSize = 128 })
                Button("Large", action: { displaySettings.cellSize = 256 })
            }
        } label: {
            Image(systemName: "square.grid.3x3")
        }
    }
}
```

### Step 4: Update Collection View Layout

Add to PhotoCollectionViewController:
```swift
func updateCellSize(_ newSize: CGFloat) {
    #if os(macOS)
    guard let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else { return }
    #else
    guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
    #endif
    
    let size = CGSize(width: newSize, height: newSize)
    layout.itemSize = size
    
    // Animate the change
    #if os(macOS)
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        layout.invalidateLayout()
    }
    #else
    UIView.animate(withDuration: 0.3) {
        layout.invalidateLayout()
        self.collectionView.layoutIfNeeded()
    }
    #endif
}
```

### Step 5: Add Gesture Support

**macOS** - Pinch to zoom:
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    let magnificationGesture = NSMagnificationGestureRecognizer(
        target: self, 
        action: #selector(handleMagnification(_:))
    )
    collectionView.addGestureRecognizer(magnificationGesture)
}

@objc private func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {
    let settings = ThumbnailDisplaySettings.shared
    let delta = gesture.magnification * 50
    let newSize = settings.cellSize + delta
    settings.cellSize = min(max(newSize, 64), 512)
    gesture.magnification = 0
}
```

**iOS** - Pinch to zoom:
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    let pinchGesture = UIPinchGestureRecognizer(
        target: self, 
        action: #selector(handlePinch(_:))
    )
    collectionView.addGestureRecognizer(pinchGesture)
}

@objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    if gesture.state == .changed {
        let settings = ThumbnailDisplaySettings.shared
        let newSize = settings.cellSize * gesture.scale
        settings.cellSize = min(max(newSize, 64), 512)
        gesture.scale = 1.0
    }
}
```

### Step 6: Add Keyboard Shortcuts (macOS)

Update PhotolalaCommands:
```swift
// Size commands
@MainActor
func increaseThumbnailSize() {
    let settings = ThumbnailDisplaySettings.shared
    // Jump to next preset size
    if settings.cellSize < 128 {
        settings.cellSize = 128
    } else if settings.cellSize < 256 {
        settings.cellSize = 256
    } else {
        settings.cellSize = min(settings.cellSize + 32, 512)
    }
}

@MainActor  
func decreaseThumbnailSize() {
    let settings = ThumbnailDisplaySettings.shared
    // Jump to previous preset size
    if settings.cellSize > 256 {
        settings.cellSize = 256
    } else if settings.cellSize > 128 {
        settings.cellSize = 128
    } else if settings.cellSize > 64 {
        settings.cellSize = 64
    } else {
        settings.cellSize = max(settings.cellSize - 32, 64)
    }
}

@MainActor
func resetThumbnailSize() {
    ThumbnailDisplaySettings.shared.cellSize = 256 // Large default
}

// Display mode command
@MainActor
func toggleDisplayMode() {
    let settings = ThumbnailDisplaySettings.shared
    settings.displayMode = settings.displayMode == .scaleToFit ? .scaleToFill : .scaleToFit
}
```

Add to CommandMenu:
```swift
CommandMenu("View") {
    Section("Thumbnail Size") {
        Button("Increase Size") { increaseThumbnailSize() }
            .keyboardShortcut("+", modifiers: .command)
        
        Button("Decrease Size") { decreaseThumbnailSize() }
            .keyboardShortcut("-", modifiers: .command)
        
        Button("Reset Size") { resetThumbnailSize() }
            .keyboardShortcut("0", modifiers: .command)
    }
    
    Section("Display Mode") {
        Button("Toggle Fit/Fill") { toggleDisplayMode() }
            .keyboardShortcut("d", modifiers: .command)
    }
}
```

### Step 7: Connect Everything

1. Make PhotoCollectionViewController observe settings changes
2. Update cells when settings change
3. Update layout when size changes
4. Ensure smooth animations

## Testing Checklist

- [ ] Fit mode shows entire image with letterboxing
- [ ] Fill mode crops image to fill cell
- [ ] Cell size changes update layout smoothly
- [ ] Settings persist across app launches
- [ ] Pinch gesture works smoothly
- [ ] Keyboard shortcuts work (macOS)
- [ ] Performance remains good with small cells
- [ ] Memory usage is reasonable

## Implementation Order

1. **Day 1**: Create settings model and update cells
2. **Day 2**: Add toolbar controls and connect to settings
3. **Day 3**: Implement dynamic layout updates
4. **Day 4**: Add gesture support
5. **Day 5**: Add keyboard shortcuts and polish

## Notes

- Start simple with just fit/fill toggle
- Add size adjustment as second feature
- Ensure backward compatibility with existing code
- Consider adding preview in settings
- Test with various image aspect ratios
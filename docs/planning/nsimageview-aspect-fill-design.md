# NSImageView Aspect Fill Design

## Problem Statement

NSImageView on macOS doesn't have a direct equivalent to UIImageView's `.scaleAspectFill` content mode. The current implementation has issues:
- Even square images (1024x1024) that should fit perfectly in square cells are being zoomed
- Some images work correctly, but behavior is inconsistent
- The scale-to-fill mode is not behaving as expected

## Current Implementation Analysis

```swift
case .scaleToFill:
    // Use CALayer for aspect fill behavior
    imageView.imageScaling = .scaleNone
    imageView.layer?.contentsGravity = .resizeAspectFill
```

### Why It's Not Working

1. **Mixed Approaches**: We're mixing NSImageView's `imageScaling` with CALayer's `contentsGravity`
2. **Image vs Layer Content**: NSImageView might be managing its image separately from the layer's contents
3. **Scale None Issue**: Setting `imageScaling = .scaleNone` might interfere with the layer's scaling

## Expected Behavior

### Scale to Fit
- Image should fit entirely within cell
- Maintain aspect ratio
- Show padding/background if aspect ratios don't match

### Scale to Fill
- Image should fill entire cell
- Maintain aspect ratio
- Crop edges if necessary
- **Square images in square cells should fill perfectly without zoom**

## Root Cause Analysis

### NSImageView Image Scaling Options
- `.scaleProportionallyDown`: Only scales down, never up
- `.scaleProportionallyUpOrDown`: Scales to fit (like aspect fit)
- `.scaleAxesIndependently`: Stretches (distorts aspect ratio)
- `.scaleNone`: Original size (no scaling)

**None of these provide aspect fill behavior!**

### CALayer Contents Gravity
- `.resizeAspect`: Similar to aspect fit
- `.resizeAspectFill`: Should provide aspect fill
- `.resize`: Stretches to fill

## Why Current Approach Fails

1. **NSImageView Controls Drawing**: When we set an image on NSImageView, it controls how that image is drawn, potentially overriding layer settings
2. **Layer Contents vs Image Property**: Setting `contentsGravity` affects the layer's `contents` property, but NSImageView draws its `image` property separately
3. **Timing Issues**: The layer properties might be set before/after the image, causing inconsistent behavior

## Potential Solutions

### Solution 1: Direct CALayer Manipulation
Instead of using NSImageView's image property, set the image directly on the layer:

```swift
imageView.wantsLayer = true
imageView.layer?.contents = nsImage
imageView.layer?.contentsGravity = .resizeAspectFill
imageView.layer?.masksToBounds = true
// Don't set imageView.image
```

**Pros**: 
- Direct control over scaling
- CALayer handles aspect fill correctly

**Cons**: 
- Bypasses NSImageView's image management
- Might lose some NSImageView features

### Solution 2: Custom Drawing
Override NSImageView's draw method with a generic class that supports both modes:

```swift
// Possible class names:
// - ScalableImageView
// - AspectImageView  
// - ContentModeImageView
// - ScaledImageView
// - PhotoImageView

class ScalableImageView: NSImageView {
    enum ScaleMode {
        case scaleToFit
        case scaleToFill
    }
    
    var scaleMode: ScaleMode = .scaleToFit {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let image = self.image else { return }
        
        let drawRect: NSRect
        
        switch scaleMode {
        case .scaleToFit:
            // Calculate aspect fit frame
            drawRect = aspectFitRect(for: image.size, in: bounds)
            
        case .scaleToFill:
            // Calculate aspect fill frame
            drawRect = aspectFillRect(for: image.size, in: bounds)
        }
        
        // Save graphics state for clipping
        NSGraphicsContext.saveGraphicsState()
        
        // Clip to bounds for scale to fill
        if scaleMode == .scaleToFill {
            NSBezierPath(rect: bounds).setClip()
        }
        
        // Draw the image
        image.draw(in: drawRect)
        
        // Restore graphics state
        NSGraphicsContext.restoreGraphicsState()
    }
    
    private func aspectFitRect(for imageSize: NSSize, in bounds: NSRect) -> NSRect {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = bounds.width / bounds.height
        
        var drawRect = bounds
        if imageAspect > viewAspect {
            // Image is wider - fit by width
            drawRect.size.height = bounds.width / imageAspect
            drawRect.origin.y = (bounds.height - drawRect.height) / 2
        } else {
            // Image is taller - fit by height
            drawRect.size.width = bounds.height * imageAspect
            drawRect.origin.x = (bounds.width - drawRect.width) / 2
        }
        
        return drawRect
    }
    
    private func aspectFillRect(for imageSize: NSSize, in bounds: NSRect) -> NSRect {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = bounds.width / bounds.height
        
        var drawRect = bounds
        if imageAspect > viewAspect {
            // Image is wider - scale by height
            let scale = bounds.height / imageSize.height
            drawRect.size.width = imageSize.width * scale
            drawRect.origin.x = (bounds.width - drawRect.width) / 2
        } else {
            // Image is taller - scale by width
            let scale = bounds.width / imageSize.width
            drawRect.size.height = imageSize.height * scale
            drawRect.origin.y = (bounds.height - drawRect.height) / 2
        }
        
        return drawRect
    }
}
```

**Pros**: 
- Complete control
- Predictable behavior

**Cons**: 
- Requires subclassing
- More code to maintain

### Solution 3: NSImageView + Proper Configuration
Research the exact combination of properties:

```swift
imageView.imageScaling = ?
imageView.imageAlignment = ?
imageView.imageFrameStyle = ?
imageView.wantsLayer = true
imageView.layer?.contentsGravity = ?
imageView.layer?.masksToBounds = true
```

### Solution 4: Use NSImage Directly with Transform
Calculate and apply transform to achieve aspect fill:

```swift
// Calculate scale factor for aspect fill
let scaleFactor = max(viewSize.width / imageSize.width, 
                     viewSize.height / imageSize.height)
// Apply transform or adjust frame
```

## Testing Strategy

1. Create test images:
   - Square (1024x1024)
   - Landscape (1920x1080)
   - Portrait (1080x1920)
   - Wide panorama (4096x1024)

2. Test each solution with:
   - Different cell sizes
   - Image aspect ratios
   - Scale to fit vs scale to fill

3. Verify:
   - Square images fill square cells exactly
   - Non-square images crop appropriately
   - No unexpected zoom or padding

## Recommendation

Implement Solution 2 with `ScalableImageView` - a custom NSImageView subclass that provides both scale-to-fit and scale-to-fill modes with proper aspect ratio handling.

## Implementation Plan

### 1. Create ScalableImageView Class
- Location: `/photolala/Views/ScalableImageView.swift`
- Platform: macOS only (iOS already has proper content modes)
- Inherits from: NSImageView

### 2. Integration Steps
1. Create the new ScalableImageView class
2. Update PhotoCollectionViewItem to use ScalableImageView instead of NSImageView
3. Connect the scaleMode to ThumbnailDisplaySettings.displayMode
4. Remove the current CALayer-based approach
5. Test with various image aspect ratios

### 3. Benefits
- **Predictable behavior**: Custom drawing ensures consistent results
- **Reusable**: Can be used elsewhere in the app if needed
- **Maintainable**: All scaling logic in one place
- **Cross-compatible**: Matches iOS behavior closely

## Questions to Investigate

1. Does NSImageView respect layer properties when drawing?
2. What's the relationship between `imageView.image` and `imageView.layer.contents`?
3. Are there any NSImageView properties we're missing?
4. How does Apple's Photos app handle this on macOS?
# Thumbnail Strip Design

Created: June 14, 2025

## Overview

Add a film-strip style thumbnail viewer to PhotoPreviewView that shows the series of photos being previewed. The strip can be toggled by tapping the center area of the preview.

## Design Specifications

### Layout Options
- **Bottom position** (default): Horizontal scrolling, like a film strip
- **Left position** (alternative): Vertical scrolling for portrait orientation
- User preference or automatic based on device orientation

### Visual Design

#### Thumbnail Strip
- **Height**: 80-100 points (bottom) or Width: 100-120 points (left)
- **Background**: Semi-transparent black (0.8 opacity)
- **Thumbnails**:
  - Size: 60x60 points with 8 point spacing
  - Current photo: 3pt white border
  - Others: 1pt gray border
  - Corner radius: 4-6 points

#### Control Bar
- **Position**: Above thumbnail strip (bottom) or beside it (left)
- **Height**: 44 points (standard toolbar height)
- **Content**: Filename (for now), future buttons/info
- **Style**: Matching semi-transparent background

### Interaction

#### Show/Hide Toggle
- **Tap area**: Center 60% of preview area
- **Animation**: Slide in/out with 0.3s duration
- **Initial state**: Hidden, auto-show for 3 seconds
- **Persist state**: Remember user's last choice

#### Thumbnail Selection
- **Tap thumbnail**: Navigate to that photo
- **Scroll**: Center on current photo initially
- **Auto-scroll**: When navigating, scroll to show current

### Implementation Plan

#### Phase 1: Basic Structure
```swift
struct PhotoPreviewView: View {
    @State private var showControls = false
    @State private var thumbnailPosition: ThumbnailPosition = .bottom
    
    var body: some View {
        ZStack {
            // Main image viewer
            imageView
            
            // Overlay controls
            if showControls {
                VStack {
                    Spacer()
                    
                    // Control bar with filename
                    ControlBar(filename: currentPhoto.filename)
                    
                    // Thumbnail strip
                    ThumbnailStrip(
                        photos: photos,
                        currentIndex: $currentIndex,
                        position: thumbnailPosition
                    )
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onTapGesture {
            handleTapGesture()
        }
    }
}
```

#### Components

1. **ThumbnailStrip**
   - ScrollView with LazyHStack/LazyVStack
   - ScrollViewReader to auto-center
   - Tap handlers for navigation

2. **ControlBar**
   - HStack with filename
   - Future: buttons for rotate, info, etc.

3. **Gesture Handling**
   - Detect tap location
   - Toggle only for center area
   - Ignore edges (navigation areas)

### Platform Considerations

#### iOS
- Touch-optimized tap areas
- Smooth scrolling with momentum
- Consider safe area for home indicator

#### macOS  
- Hover effects on thumbnails
- Scroll wheel support
- Click instead of tap

### Future Enhancements
- Drag to reorder (if applicable)
- Long-press for options
- Pinch to change thumbnail size
- Different strip styles (filmstrip, grid, etc.)
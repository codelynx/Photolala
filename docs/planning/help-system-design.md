# Help System Design

## Overview

This document outlines the design for implementing a cross-platform help system in Photolala that works on both macOS and iOS using local HTML content.

## Requirements

1. **Cross-platform**: Single implementation for macOS and iOS
2. **Local content**: HTML files bundled in Resources/Help
3. **Native feel**: Appropriate presentation for each platform
4. **Navigation**: Support for links between help topics
5. **Search**: Future capability for searching help content
6. **Offline**: No internet connection required

## Framework Analysis

### Option 1: WKWebView (Recommended) ✅
- **Pros**:
  - Available on both macOS and iOS
  - Modern WebKit engine
  - SwiftUI integration via WKWebViewRepresentable
  - Supports local file URLs
  - JavaScript support for interactivity
  - Good performance
- **Cons**:
  - Requires wrapper for SwiftUI
  - Some platform differences in behavior

### Option 2: SFSafariViewController ❌
- **Pros**:
  - Full Safari features
  - Reader mode, sharing
- **Cons**:
  - iOS only (not available on macOS)
  - Designed for web URLs, not local content
  - Less customization options

### Option 3: ASWebAuthenticationSession ❌
- **Pros**:
  - Cross-platform
- **Cons**:
  - Designed for authentication flows
  - Not suitable for help content

### Option 4: Native Text/AttributedString ❌
- **Pros**:
  - Pure SwiftUI
  - Maximum control
- **Cons**:
  - Limited HTML support
  - More work for rich content

## Proposed Architecture

### 1. Content Structure
```
Resources/
└── Help/
    ├── index.html          # Main help page
    ├── getting-started.html
    ├── browsing-photos.html
    ├── keyboard-shortcuts.html
    ├── troubleshooting.html
    ├── css/
    │   └── help.css       # Styling
    └── images/
        └── screenshots/   # Help images
```

### 2. SwiftUI Implementation

```swift
// Cross-platform WebView wrapper
struct HelpWebView: XViewRepresentable {
    let htmlFile: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    
    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView
    func updateNSView(_ webView: WKWebView, context: Context)
    #else
    func makeUIView(context: Context) -> WKWebView
    func updateUIView(_ webView: WKWebView, context: Context)
    #endif
}

// Help view container
struct HelpView: View {
    @State private var currentPage = "index"
    @State private var canGoBack = false
    @State private var canGoForward = false
    
    var body: some View {
        VStack {
            // Navigation toolbar
            HelpToolbar(canGoBack: canGoBack, 
                       canGoForward: canGoForward)
            
            // Web content
            HelpWebView(htmlFile: currentPage,
                       canGoBack: $canGoBack,
                       canGoForward: $canGoForward)
        }
    }
}
```

### 3. Platform Presentation

#### macOS
- **Window**: Separate help window (like standard Mac apps)
- **Size**: 800x600 default, resizable
- **Menu**: Help → Photolala Help (⌘?)
- **Toolbar**: Back, Forward, Home, Search (future)

#### iOS
- **Presentation**: Modal sheet or navigation push
- **Navigation**: Standard navigation bar
- **Access**: Help button in settings or toolbar

## HTML Content Structure

### Base Template
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Photolala Help</title>
    <link rel="stylesheet" href="css/help.css">
</head>
<body>
    <div class="help-container">
        <nav class="breadcrumb">
            <a href="index.html">Help</a> › <span>Current Topic</span>
        </nav>
        
        <article>
            <h1>Topic Title</h1>
            <!-- Content -->
        </article>
        
        <nav class="related">
            <h3>Related Topics</h3>
            <ul>
                <li><a href="topic.html">Related Topic</a></li>
            </ul>
        </nav>
    </div>
</body>
</html>
```

### CSS Considerations
```css
/* Adaptive design for both platforms */
:root {
    --system-font: -apple-system, system-ui;
    --link-color: rgb(0, 122, 255);
}

/* Dark mode support */
@media (prefers-color-scheme: dark) {
    :root {
        --bg-color: #1e1e1e;
        --text-color: #ffffff;
    }
}
```

## Sample Help Topics

1. **Welcome/Overview**
   - What is Photolala
   - Key features
   - Getting help

2. **Getting Started**
   - Opening folders
   - Navigation basics
   - Interface overview

3. **Browsing Photos**
   - Thumbnail sizes
   - Display modes
   - Sorting options
   - Selection

4. **Viewing Photos**
   - Preview mode
   - Zoom and pan
   - Navigation
   - Metadata

5. **Keyboard Shortcuts**
   - Navigation
   - Selection
   - View options
   - Platform differences

6. **Context Menu** (macOS)
   - Right-click options
   - Quick Look
   - Open With

7. **Tips & Tricks**
   - Performance tips
   - Workflow suggestions

8. **Troubleshooting**
   - Common issues
   - Cache management
   - Contact support

## Implementation Phases

### Phase 1: Basic Infrastructure (POC)
1. Create HelpWebView wrapper
2. Create HelpView container
3. Add Help menu item (macOS)
4. Create basic HTML structure
5. Load and display help content

### Phase 2: Navigation
1. Implement back/forward
2. Add navigation toolbar
3. Handle internal links
4. Add breadcrumbs

### Phase 3: Polish
1. Dark mode support
2. Dynamic type support
3. Responsive design
4. Platform-specific styling

### Phase 4: Advanced (Future)
1. Search functionality
2. Bookmarks
3. Context-sensitive help
4. Interactive tutorials

## Technical Considerations

1. **Bundle Resources**
   - Copy Help folder as folder reference
   - Preserve directory structure
   - Handle resource URLs properly

2. **Security**
   - Disable JavaScript (or limit)
   - No external resource loading
   - Sandbox compliance

3. **Accessibility**
   - Proper heading structure
   - Alt text for images
   - Keyboard navigation
   - VoiceOver support

4. **Localization** (Future)
   - Separate folders per language
   - Language detection
   - Fallback to English

## Success Criteria

1. Help loads quickly (< 200ms)
2. Navigation works smoothly
3. Content is readable on all devices
4. Links work correctly
5. Looks native on each platform

## Open Questions

1. Should we support printing help pages?
2. Do we need offline search in Phase 1?
3. Should help remember last viewed page?
4. How to handle external links (if any)?
5. Should we track help analytics?

## Implementation Status

**Status**: IMPLEMENTED (POC)

### Completed
- ✅ Created HelpWebView wrapper for cross-platform WKWebView support
- ✅ Created HelpView with navigation controls
- ✅ Implemented HelpWindowController for macOS
- ✅ Added Help menu command (⌘?) - replaces standard Help menu
- ✅ Created complete CSS stylesheet with dark mode support
- ✅ Generated all pseudo help content HTML pages:
  - index.html (main help page)
  - getting-started.html
  - browsing-photos.html
  - organizing.html
  - searching.html
  - keyboard-shortcuts.html
  - troubleshooting.html
- ✅ Integrated help system into PhotoBrowserView (iOS sheet presentation)
- ✅ Resources copied to app bundle
- ✅ External links open in default browser

### Known Issues
- Navigation buttons (Back/Forward/Home) not yet connected to WKWebView
- Search functionality not implemented
- Images are placeholders only

### Next Steps
- Connect navigation controls to WKWebView navigation
- Implement search functionality
- Add actual screenshots/images
- Consider adding print support
- Add help context sensitivity
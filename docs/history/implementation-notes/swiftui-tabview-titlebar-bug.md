# SwiftUI TabView Title Bar Bug on macOS

## Issue Discovered

Date: June 17, 2025

During the implementation of IAP Developer Tools, we discovered a SwiftUI bug/quirk on macOS where using `TabView` with `.tabViewStyle(.automatic)` causes content to be pushed up into the window's title bar area.

## Symptoms

- Segmented control or other top content appears in the title bar
- Window title may be hidden or obscured
- Layout appears correct in some contexts but broken in others
- Commenting out TabView causes the issue to disappear

## Root Cause

`TabView` with automatic style on macOS appears to interfere with NSWindow's content layout, potentially due to how SwiftUI calculates safe areas or content insets when hosted in an NSHostingView.

## Solution

Replace TabView with a manual implementation using switch statement:

```swift
// Problematic code:
TabView(selection: $selectedTab) {
    contentView1.tag(0)
    contentView2.tag(1)
    contentView3.tag(2)
}
.tabViewStyle(.automatic)

// Working solution:
// Use a Picker for tab selection
Picker("", selection: $selectedTab) {
    Text("Tab 1").tag(0)
    Text("Tab 2").tag(1)
    Text("Tab 3").tag(2)
}
.pickerStyle(.segmented)

// Use switch statement to show content
Group {
    switch selectedTab {
    case 0: contentView1
    case 1: contentView2
    case 2: contentView3
    default: EmptyView()
    }
}
```

## Alternative Solutions Considered

1. **Adding padding/spacing**: Tried various padding approaches but they created inconsistent results
2. **Using safeAreaInset**: Did not resolve the core issue
3. **Modifying window properties**: Setting titleVisibility and other window properties didn't help

## Recommendation

When creating tabbed interfaces in macOS windows with SwiftUI:
- Avoid TabView with automatic style
- Use segmented Picker + switch statement for simple tab interfaces
- Consider using manual tab implementations for complex cases
- Test in both Xcode preview and actual window contexts

## References

- Implementation: IAPDeveloperView.swift
- Related PR/Issue: IAP Developer Tools Implementation
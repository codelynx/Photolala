# iOS Security-Scoped Resource Management

## Issue

On iOS/iPadOS, when users select folders through the document picker (e.g., for browsing AirDropped photos), the app receives a security-scoped URL that requires proper lifecycle management.

## Current Status (June 26, 2025)

Currently, the app calls `startAccessingSecurityScopedResource()` when a folder is selected but never calls `stopAccessingSecurityScopedResource()`. This allows the app to work but is not proper resource management.

## Code Location

`WelcomeView.swift` - DocumentPickerView delegate:
```swift
func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    if let url = urls.first {
        _ = url.startAccessingSecurityScopedResource()  // Started but never stopped
        self.parent.onSelectFolder(url)
    }
}
```

## Required Fix Before Release

### 1. Store Security-Scoped URL Reference

The DirectoryPhotoBrowserView should store whether it's using a security-scoped URL:

```swift
struct DirectoryPhotoBrowserView: View {
    let directoryPath: NSString
    let isSecurityScoped: Bool  // Add this
    private let securityScopedURL: URL?  // Add this
    
    init(directoryPath: NSString, securityScopedURL: URL? = nil) {
        self.directoryPath = directoryPath
        self.securityScopedURL = securityScopedURL
        self.isSecurityScoped = securityScopedURL != nil
        // Start access if needed
        _ = securityScopedURL?.startAccessingSecurityScopedResource()
    }
}
```

### 2. Stop Access on View Dismissal

Add cleanup when the view is dismissed:

```swift
.onDisappear {
    if let url = securityScopedURL {
        url.stopAccessingSecurityScopedResource()
    }
}
```

### 3. Handle Navigation

When navigating to subfolders, maintain the security scope from the parent folder.

## Implementation Priority

**HIGH** - This must be fixed before App Store release because:
1. It's a resource leak that could affect system performance
2. Apple may reject apps that don't properly manage security-scoped resources
3. It could cause issues with iOS resource limits

## Testing

1. Select a folder through document picker
2. Browse photos
3. Navigate away or close the view
4. Verify no permission errors on subsequent access
5. Check for any iOS warnings about resource management

## References

- [Apple Documentation: Accessing Files from the Document Picker](https://developer.apple.com/documentation/uikit/view_controllers/providing_access_to_directories)
- [Security-Scoped Resource Access](https://developer.apple.com/documentation/foundation/url/1779698-startaccessingsecurityscopedreso)
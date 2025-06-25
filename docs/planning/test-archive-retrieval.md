# Testing Archive Retrieval UI

## How to Test the Archive Retrieval Flow

Since we don't have actual S3 Deep Archive photos yet, you can test the UI by temporarily adding mock archive info to photos.

### 1. Add Test Archive Info

In `PhotoBrowserView.swift`, modify the `loadArchiveStatus` method temporarily:

```swift
private func loadArchiveStatus(for photos: [PhotoReference]) async {
    // TEMPORARY: Mock some archived photos for testing
    for (index, photo) in photos.enumerated() {
        // Make every 3rd photo archived for testing
        if index % 3 == 0 {
            photo.archiveInfo = ArchivedPhotoInfo(
                md5: "test-\(index)",
                archivedDate: Date().addingTimeInterval(-180 * 86400), // 6 months ago
                storageClass: .deepArchive,
                lastAccessedDate: nil,
                isPinned: false,
                retrieval: nil
            )
        }
    }
}
```

### 2. Test Steps

1. **Open Photolala** and browse to a folder with photos
2. **Look for Archive Badges** - Every 3rd photo should show a ❄️ badge
3. **Notice Dimming** - Archived photos should appear at 70% opacity
4. **Click an Archived Photo** - Should show the retrieval dialog
5. **Test Retrieval Options** - Try different options (single, batch, album)
6. **Test Rush Delivery** - Toggle the rush delivery option
7. **Cancel Dialog** - Ensure cancel works properly

### 3. Expected Behavior

- ❄️ badge appears in top-right corner of archived photos
- Archived photos are dimmed to 70% opacity
- Single click on archived photo shows retrieval dialog
- Double-click on archived photo does NOT navigate (blocked by archive check)
- Regular photos behave normally

### 4. Remove Test Code

After testing, remove the mock archive info code and restore the original implementation that loads from S3.

## Current Implementation Status

✅ Archive badges display on photos
✅ Click detection for archived photos
✅ Retrieval dialog presentation
✅ Cross-platform support (macOS/iOS)
✅ Archive status loading framework

❌ Actual S3 restore API calls
❌ Progress tracking during retrieval
❌ Notifications when retrieval completes
❌ S3 lifecycle rules configuration
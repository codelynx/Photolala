# Apple Photos Library Metadata Extraction

**Date**: 2025-06-21
**Status**: Planning
**Feature**: Extract file size and EXIF metadata from Apple Photos Library

## Overview

Currently, Apple Photos Library items (`PhotoApple`) don't show original file size or detailed EXIF metadata in the inspector. This document outlines approaches to extract this information to achieve feature parity with directory-based photos.

## Current State

### What We Have
- Basic metadata from PHAsset:
  - `creationDate` - When photo was taken
  - `modificationDate` - Last modified date
  - `pixelWidth/pixelHeight` - Image dimensions
  - `location` - GPS coordinates (if available)

### What's Missing
- Original file size
- Camera make/model
- Camera settings (ISO, aperture, shutter speed)
- Lens information
- Other EXIF/TIFF metadata

## Technical Approaches

### Approach 1: Minimal - File Size Only
```swift
func loadFileSize() async throws -> Int64? {
    return try await withCheckedThrowingContinuation { continuation in
        imageManager.requestImageDataAndOrientation(
            for: asset,
            options: nil
        ) { data, _, _, info in
            if let error = info?[PHImageErrorKey] as? Error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: Int64(data?.count ?? 0))
            }
        }
    }
}
```

**Pros:**
- Simple implementation
- Single API call
- Works with optimized iCloud photos

**Cons:**
- Might download full image from iCloud
- No metadata beyond size

### Approach 2: Full Metadata Extraction
```swift
struct PhotoMetadataApple {
    let fileSize: Int64
    let cameraMake: String?
    let cameraModel: String?
    let iso: Int?
    let aperture: Double?
    let shutterSpeed: String?
    let focalLength: Double?
    let lens: String?
    // ... other fields
}

func loadMetadata() async throws -> PhotoMetadataApple? {
    return try await withCheckedThrowingContinuation { continuation in
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImageDataAndOrientation(
            for: asset,
            options: options
        ) { data, dataUTI, orientation, info in
            guard let data = data else {
                continuation.resume(returning: nil)
                return
            }
            
            // Extract metadata using CGImageSource
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                continuation.resume(returning: nil)
                return
            }
            
            // Parse EXIF, TIFF, GPS dictionaries
            let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
            let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
            let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
            
            let metadata = PhotoMetadataApple(
                fileSize: Int64(data.count),
                cameraMake: tiff?[kCGImagePropertyTIFFMake as String] as? String,
                cameraModel: tiff?[kCGImagePropertyTIFFModel as String] as? String,
                iso: (exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first,
                aperture: exif?[kCGImagePropertyExifFNumber as String] as? Double,
                shutterSpeed: exif?[kCGImagePropertyExifExposureTime as String] as? String,
                focalLength: exif?[kCGImagePropertyExifFocalLength as String] as? Double,
                lens: exif?[kCGImagePropertyExifLensModel as String] as? String
            )
            
            continuation.resume(returning: metadata)
        }
    }
}
```

**Pros:**
- Complete metadata access
- Feature parity with directory photos
- Single API call for all data

**Cons:**
- More complex implementation
- Larger memory footprint
- Requires full image data download

### Approach 3: PHAssetResource (Most Efficient)
```swift
func loadFileSizeEfficiently() async -> Int64? {
    await withCheckedContinuation { continuation in
        let resources = PHAssetResource.assetResources(for: asset)
        
        // Find the primary photo resource
        if let resource = resources.first(where: { $0.type == .photo }) {
            // Try to get file size without downloading
            // Note: This is undocumented but works in practice
            if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                continuation.resume(returning: fileSize)
                return
            }
        }
        
        // Fallback to nil if can't get size
        continuation.resume(returning: nil)
    }
}
```

**Pros:**
- No download required
- Very fast
- Works with iCloud optimized photos

**Cons:**
- Uses undocumented API
- Only provides file size, not EXIF
- Might break in future iOS versions

## Implementation Strategy

### Phase 1: File Size Only
1. Add `originalFileSize: Int64?` property to PhotoApple
2. Implement lazy loading when inspector requests it
3. Cache the result to avoid repeated API calls
4. Show "Calculating..." in UI while loading

### Phase 2: Full Metadata (Optional)
1. Create `PhotoMetadataApple` struct
2. Add metadata loading to PhotoApple
3. Update InspectorView to show additional metadata
4. Consider adding metadata to other photo types for consistency

### Code Changes Required

#### 1. Update PhotoApple Model
```swift
class PhotoApple: PhotoItem {
    // Existing properties...
    
    // New cached properties
    private var cachedFileSize: Int64?
    private var cachedMetadata: PhotoMetadataApple?
    private var isLoadingMetadata = false
    
    // Updated fileSize property
    var fileSize: Int64? {
        get async {
            if let cached = cachedFileSize {
                return cached
            }
            
            // Load asynchronously
            cachedFileSize = try? await loadFileSize()
            return cachedFileSize
        }
    }
}
```

#### 2. Update InspectorView
```swift
struct PhotoInfoSection: View {
    @State private var fileSize: Int64?
    @State private var isLoadingSize = false
    
    var body: some View {
        // Existing code...
        
        if let size = fileSize {
            InfoRow(label: "Size", value: formatFileSize(size))
        } else if isLoadingSize {
            InfoRow(label: "Size", value: "Calculating...")
        }
    }
    
    .task {
        if fileSize == nil {
            isLoadingSize = true
            fileSize = await photo.fileSize
            isLoadingSize = false
        }
    }
}
```

## Performance Considerations

1. **Lazy Loading**: Only load metadata when inspector is shown
2. **Caching**: Store results to avoid repeated API calls
3. **Progress Indication**: Show loading state in UI
4. **iCloud Handling**: 
   - Set `isNetworkAccessAllowed = true` for iCloud photos
   - Consider showing download progress for large files
   - Handle timeout/failure gracefully

## iCloud Photo Library Considerations

When photos are stored in iCloud with "Optimize Mac Storage" enabled:
- Thumbnails are always available locally
- Original photos might need to be downloaded
- `requestImageData` will trigger download if needed
- Consider showing different UI for optimized vs local photos

## Testing Requirements

1. Test with local photos
2. Test with iCloud photos (optimized storage)
3. Test with RAW photos
4. Test with HEIC/HEIF formats
5. Test with edited photos (might have multiple resources)
6. Test performance with large libraries

## Future Enhancements

1. **Batch Loading**: Load metadata for multiple selected photos
2. **Export Metadata**: Export EXIF data to text/JSON
3. **Metadata Editing**: Allow editing certain metadata fields
4. **Comparison View**: Compare metadata between photos
5. **Search by Metadata**: Filter photos by camera, lens, settings

## Decision Points

1. **Which approach to use?**
   - Start with Approach 2 (Full Metadata) for feature parity
   - Can optimize later if performance is an issue

2. **When to load metadata?**
   - On-demand when inspector is shown
   - Not during initial photo loading

3. **How to handle iCloud photos?**
   - Always allow network access
   - Show progress if download is needed
   - Cache aggressively once loaded

4. **UI/UX considerations?**
   - Show "Calculating..." while loading
   - Gracefully handle failures
   - Consider progressive disclosure for detailed metadata

## Conclusion

Implementing metadata extraction for Apple Photos Library will provide feature parity with directory-based photos and enhance the user experience. The recommended approach is to implement full metadata extraction (Approach 2) with proper caching and lazy loading to ensure good performance.
# PTM-256 Thumbnail Specification

## Overview
PTM-256 (Photolala Thumbnail Method) defines a standardized 256×256 pixel JPEG thumbnail format for consistent, high-quality image previews across all platforms and storage tiers.

## Core Specifications

### Dimensions
- **Size**: Exactly 256×256 pixels
- **Aspect Ratio**: 1:1 (square)
- **Orientation**: Preserved from original EXIF data

### Image Processing

#### Scaling Method
- **Algorithm**: Lanczos resampling (high quality)
- **Fallback**: Bicubic interpolation if Lanczos unavailable
- **Mode**: Aspect-fill (crop to square)

#### Crop Strategy
1. **Portrait Images**: Center horizontally, bias top 40% vertically (preserves faces)
2. **Landscape Images**: Center both horizontally and vertically
3. **Square Images**: Scale down only, no cropping needed

### JPEG Encoding

#### Quality Settings
- **Quality Level**: 85 (0-100 scale)
- **Subsampling**: 4:2:0 (standard for thumbnails)
- **Progressive**: No (optimized for quick display)
- **Optimize**: Yes (Huffman table optimization)

#### Color Profile
- **Color Space**: sRGB
- **Embedded Profile**: No (reduces file size)
- **Bit Depth**: 8 bits per channel

### File Size Targets
- **Target Size**: 15-30 KB per thumbnail
- **Maximum Size**: 50 KB (re-encode at lower quality if exceeded)
- **Minimum Quality**: 70 (never go below this)

## Implementation Guidelines

### Swift/Core Image Implementation
```swift
func generatePTM256Thumbnail(from imageData: Data) throws -> Data {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ThumbnailError.invalidImageData
    }

    let size: CGFloat = 256
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    let context = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )

    // Configure high-quality interpolation
    context?.interpolationQuality = .high

    // Calculate crop rect for aspect-fill
    let imageWidth = CGFloat(image.width)
    let imageHeight = CGFloat(image.height)
    let scale = max(size / imageWidth, size / imageHeight)

    let scaledWidth = imageWidth * scale
    let scaledHeight = imageHeight * scale
    let x = (size - scaledWidth) / 2
    let y = (size - scaledHeight) / 2

    let drawRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
    context?.draw(image, in: drawRect)

    guard let thumbnail = context?.makeImage() else {
        throw ThumbnailError.generationFailed
    }

    // Encode as JPEG with quality 85
    let options: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: 0.85,
        kCGImageDestinationOptimizeColorForSharing: true
    ]

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data as CFMutableData,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ) else {
        throw ThumbnailError.encodingFailed
    }

    CGImageDestinationAddImage(destination, thumbnail, options as CFDictionary)
    CGImageDestinationFinalize(destination)

    return data as Data
}
```

### Quality Validation
```swift
func validatePTM256Thumbnail(_ data: Data) -> Bool {
    // Check file size
    guard data.count <= 50_000 else { return false }

    // Verify dimensions
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
        return false
    }

    return width == 256 && height == 256
}
```

## Storage & Caching

### File Naming
- **Local Cache**: `{cache-root}/md5/thumbnails/{prefix-2}/{photo-md5}.jpg`
- **S3 Storage**: `thumbnails/{user-uuid}/{photo-md5}.jpg`
- **Temporary**: Use `.ptm256.jpg` suffix during generation

### Cache Headers
- **Cache-Control**: `public, max-age=31536000, immutable` (1 year)
- **Content-Type**: `image/jpeg`
- **ETag**: MD5 of thumbnail data

## Performance Considerations

### Batch Processing
- Process thumbnails in batches of 10-20 for memory efficiency
- Use concurrent queues with QoS `.utility`
- Implement back-pressure when memory pressure detected

### Memory Management
```swift
autoreleasepool {
    // Generate thumbnail
    // Ensures timely memory release in batch operations
}
```

### Fast Path
1. Check if thumbnail already exists in cache (by MD5)
2. If exists, verify dimensions and return
3. If not, generate and cache

## Platform-Specific Notes

### iOS/iPadOS
- Use `UIImage` with `.scaleAspectFill` for preview generation
- Leverage `UIGraphicsImageRenderer` for hardware acceleration
- Consider using PhotoKit's thumbnail API for Apple Photos items

### macOS
- Use `NSImage` with `NSImageScaling.scaleProportionallyUpOrDown`
- Leverage Core Image filters for better quality
- Support Retina displays with @2x consideration (still output 256×256)

### visionOS
- Same as iOS but optimize for stereoscopic display
- Consider generating paired thumbnails for 3D content

## Quality Assurance

### Visual Quality Metrics
- **Sharpness**: No visible blur at 100% zoom
- **Color Accuracy**: Delta-E < 3 compared to original
- **Artifacts**: No visible JPEG blocks at standard viewing distance

### Automated Testing
```swift
func testPTM256Generation() {
    let testImages = ["portrait.jpg", "landscape.png", "square.heic"]

    for imageName in testImages {
        let original = loadTestImage(imageName)
        let thumbnail = generatePTM256Thumbnail(from: original)

        XCTAssertEqual(thumbnail.dimensions, CGSize(width: 256, height: 256))
        XCTAssertLessThanOrEqual(thumbnail.count, 50_000)
        XCTAssertGreaterThanOrEqual(thumbnail.jpegQuality, 70)
    }
}
```

## Migration & Compatibility

### From Existing Thumbnails
- Detect non-PTM-256 thumbnails by checking dimensions
- Re-generate in background during idle time
- Keep old thumbnails until new ones verified

### Format Support
- Input: JPEG, PNG, HEIF, TIFF, RAW formats (via Core Image)
- Output: Always JPEG (for consistency and size)

## Error Handling

### Common Errors
- `ThumbnailError.invalidImageData` - Cannot decode source image
- `ThumbnailError.generationFailed` - Processing failed
- `ThumbnailError.encodingFailed` - JPEG encoding failed
- `ThumbnailError.sizeLimitExceeded` - Result > 50KB after optimization

### Fallback Strategy
1. Try with quality 85
2. If too large, reduce to quality 75
3. If still too large, reduce to quality 70 (minimum)
4. If still exceeds limit, scale to 240×240 and try again
5. Ultimate fallback: Return generic placeholder

## Future Enhancements

### Planned Features
- Smart cropping using ML face/object detection
- AVIF output format support (better compression)
- Adaptive quality based on image complexity
- HDR thumbnail support for capable displays

### Research Areas
- WebP format evaluation (30% smaller files)
- Progressive JPEG for network streaming
- Client-side generation for privacy-sensitive content
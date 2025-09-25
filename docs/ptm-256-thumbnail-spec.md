# PTM-256 Thumbnail Specification

## Overview
PTM-256 (Photolala Thumbnail Method) defines a predictable JPEG thumbnail format used across every Photolala client and service. The format keeps the **short edge locked at 256 px** while allowing the long edge to grow **proportionally up to 512 px**. This preserves more scene context than a strict square crop, but still guarantees a bounded footprint for caching and transport.

## Core Specifications

### Dimensions & Aspect
- **Short edge**: Exactly 256 px (height for portrait, width for landscape).
- **Long edge**: Proportional to the source image but clamped to ≤ 512 px.
- **Aspect ratio**: Always between 1:2 and 2:1; no stretching or letterboxing.
- **Orientation**: Honor EXIF/metadata rotation so thumbnails display upright.

### Image Processing

#### Scaling
1. Inspect the source image size.
2. Compute a scale factor `scale = 256 / min(width, height)`.
3. Multiply both axes by `scale` to make the short edge 256 px.

#### Cropping (only if the long edge > 512 px after scaling)
1. Determine the excess along the long axis (`scaledLongEdge - 512`).
2. Crop the excess evenly from both sides. For portraits, bias the crop upward by ~40 % to keep faces framed.
3. The final canvas is therefore 256 × ≤ 512 (portrait) or ≤ 512 × 256 (landscape).

#### Resampling
- **Preferred**: Lanczos resampling for the initial resize.
- **Fallback**: Bicubic interpolation when Lanczos isn’t available.
- Always render into an RGB buffer with premultiplied alpha removed.

### JPEG Encoding
- **Quality**: 85 (0–100 scale).
- **Subsampling**: 4:2:0.
- **Progressive**: Disabled for faster first paint on the web.
- **Optimize**: Enabled (Huffman table optimization).
- **Color space**: sRGB; do not embed a profile (keeps files small).
- **Bit depth**: 8 bits per channel.

### File Size Targets
- **Typical size**: 15–35 KB.
- **Maximum**: 50 KB (if exceeded, re-encode while lowering quality in small steps, but never below 70).
- **Minimum quality floor**: 70; below this, prefer regenerating from a higher quality source.

## Implementation Guidelines

### Swift / Core Graphics Reference Implementation
```swift
func generatePTM256Thumbnail(from imageData: Data) throws -> Data {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ThumbnailError.invalidImageData
    }

    let shortEdge: CGFloat = 256
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    let scale = shortEdge / min(width, height)

    let scaledWidth = width * scale
    let scaledHeight = height * scale

    let targetWidth = min(scaledWidth, 512)
    let targetHeight = min(scaledHeight, 512)

    guard let context = CGContext(
        data: nil,
        width: Int(targetWidth.rounded()),
        height: Int(targetHeight.rounded()),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw ThumbnailError.contextCreationFailed
    }

    context.interpolationQuality = .high

    var offsetX = (targetWidth - scaledWidth) / 2
    var offsetY = (targetHeight - scaledHeight) / 2

    // When the portrait long edge exceeds 512 px, bias the crop upward ~40 %.
    if scaledHeight > targetHeight {
        let overflow = scaledHeight - targetHeight
        offsetY += overflow * 0.4
        offsetY = min(offsetY, 0) // never push the image outside the top edge
    }

    let drawRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)

    context.draw(cgImage, in: drawRect)

    guard let thumbnail = context.makeImage() else {
        throw ThumbnailError.generationFailed
    }

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

### Validation Helper
```swift
func validatePTM256Thumbnail(_ data: Data) -> Bool {
    guard data.count <= 50_000 else { return false }

    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = props[kCGImagePropertyPixelWidth] as? Int,
          let height = props[kCGImagePropertyPixelHeight] as? Int else {
        return false
    }

    let shortEdge = min(width, height)
    let longEdge = max(width, height)

    return shortEdge == 256 && longEdge <= 512
}
```

## Storage & Caching
- **Local cache**: `{cache-root}/md5/thumbnails/{prefix-2}/{photo-md5}.jpg`
- **S3 storage**: `thumbnails/{user-uuid}/{photo-md5}.jpg`
- **Temporary files**: Use the `.ptm256.jpg` suffix while generating (helpful for cleanup jobs).
- **HTTP headers**: `Cache-Control: public, max-age=31536000, immutable`, `Content-Type: image/jpeg`, `ETag` set to the thumbnail MD5.

## Performance Considerations
- Batch thumbnail generation in groups of 10–20 items and wrap each batch in an `autoreleasepool {}` when using Core Graphics.
- Use a QoS `.utility` queue for background work to avoid starving UI rendering.
- Skip regeneration when a cached thumbnail already passes validation.

## Platform-Specific Notes
- **iOS / iPadOS / visionOS**: `UIGraphicsImageRenderer` offers hardware acceleration; still ensure the final bitmap matches the PTM-256 size constraints.
- **macOS**: `NSImage` + Core Image filters work well; remember to honor Retina/@2× backing but output the canonical dimensions.
- **Apple Photos assets**: Prefer PhotoKit’s image manager for fetching the full-resolution source before generating PTM-256.

## Quality Assurance
- Manual spot checks should confirm crisp detail and faithful color at 100 % zoom.
- Automated tests ought to cover a balanced set of portrait, landscape, and square sources:
```swift
func testPTM256Generation() throws {
    for imageName in ["portrait.jpg", "landscape.png", "square.heic"] {
        let original = try loadFixture(named: imageName)
        let thumbnailData = try generatePTM256Thumbnail(from: original)

        XCTAssertTrue(validatePTM256Thumbnail(thumbnailData))
        XCTAssertLessThanOrEqual(thumbnailData.count, 50_000)
    }
}
```

## Migration & Compatibility
- Legacy 256 × 256 square thumbnails can coexist temporarily but should be regenerated on demand to align with PTM‑256.
- When detecting cache entries, treat any thumbnail whose short edge ≠ 256 px or long edge > 512 px as invalid and regenerate.
- S3 buckets should be audited periodically to ensure thumbnails adhere to the updated spec; any oversized assets can be queued for regeneration via backfill tooling.

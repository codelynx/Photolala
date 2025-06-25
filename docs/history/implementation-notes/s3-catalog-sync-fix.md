# S3 Catalog Sync Fix

Date: June 21, 2025

## Issue

S3 catalog sync was failing with "file exists" error when attempting to perform atomic update of catalog directory.

## Root Cause

The `CacheManager.cloudCatalogURL()` method was automatically creating the `.photolala` directory every time it was called. This interfered with the atomic update process in `S3CatalogSyncService` which needed to:
1. Download to a temporary directory
2. Move the existing catalog out of the way
3. Move the new catalog into place

## Solution

Modified `S3CatalogSyncService` to:

1. **Create temp directory at user level** instead of inside `.photolala`:
   ```swift
   // Before: .../catalogs/{userId}/.photolala/tmp_UUID/
   // After:  .../catalogs/{userId}/tmp_UUID/
   ```

2. **Avoid using CacheManager.cloudCatalogURL()** which auto-creates directories:
   ```swift
   // Use cacheRootURL and build path manually
   let catalogsDir = cacheManager.cacheRootURL
       .appendingPathComponent("cloud/s3/catalogs/\(userId)")
   ```

3. **Improved atomic update process**:
   - Create temp directory at user level: `{userId}/tmp_{UUID}/`
   - Download catalog to: `{userId}/tmp_{UUID}/.photolala/`
   - Back up existing catalog to: `{userId}/backup_{UUID}/`
   - Move new catalog from temp to final location
   - Clean up temp and backup directories

## Key Changes

### S3CatalogSyncService.swift

1. Changed temp directory creation:
   ```swift
   // Create temp directory at the user level, not inside .photolala
   let userDir = catalogCacheDir.deletingLastPathComponent()
   let tempDirName = "tmp_\(UUID().uuidString)"
   let tempDir = userDir.appendingPathComponent(tempDirName)
   ```

2. Fixed atomic update to handle new directory structure:
   ```swift
   // Move the temp catalog directory to the final location
   try FileManager.default.moveItem(at: tempCatalogDir, to: catalogCacheDir)
   ```

3. Added proper cleanup of temp directories in both success and failure cases

### CacheManager.swift

Added public accessor for root cache URL:
```swift
/// Get the root cache URL (needed for S3CatalogSyncService)
var cacheRootURL: URL { rootURL }
```

## Result

- S3 catalog sync now completes successfully
- No more "file exists" errors during atomic updates
- Cloud browser properly displays photos from S3
- Atomic updates ensure catalog consistency even if interrupted
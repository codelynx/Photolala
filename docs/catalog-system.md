# Photolala Directory Catalog System

## 1. Overview
Photolala must browse 100K+ local or remote images with smooth scrolling on Apple platforms. The Photolala Directory Catalog accelerates discovery and rendering by maintaining a minimal CSV-based catalog of photo identities and dates, while storing detailed metadata and thumbnails in a separate cache system.

## 2. Goals
- **Instant Availability** – surface a root-browsing-directory's photo list and thumbnails without re-reading full files.
- **Deterministic Identity** – identify assets via `fast-photo-key` (head MD5 + file size) before the full MD5 is available.
- **Cache Reuse** – rehydrate state from the most recent `.photolala.{md5}.csv` in-place or from `~/Library/Caches`.
- **Minimal Storage** – store only essential identity, date, and format information in the catalog CSV.
- **Format Detection** – detect image format from magic bytes during initial scan for proper export and serving.
- **Scalable Updates** – rescan only files whose `fast-photo-key` changes; avoid re-walking entire directory trees unnecessarily.

## 3. Scope & Assumptions
- Applies to any **root-browsing-directory** (local disk, removable media, mounted network share, S3-backed virtual folder).
- Directory metadata and thumbnail caches live on disk; in-memory caches are optional.
- Remote directories may change between scans; the system targets eventual consistency, not strong locking.

## 4. Data Model

### 4.1 CSV Catalog Structure
The catalog uses a minimal CSV format with only essential fields:

```csv
photo_head_md5,file_size,photo_md5,photo_date,format
{photo-head-md5},{file-size},{photo-md5},{unix-timestamp},{format}
```

**Example CSV:**
```csv
photo_head_md5,file_size,photo_md5,photo_date,format
a1b2c3d4e5f67890,1048576,9f8e7d6c5b4a3210,1699999999,JPEG
b2c3d4e5f6789012,2097152,8e7d6c5b4a32109f,1699999998,HEIF
c3d4e5f678901234,524288,,1699999997,PNG
d4e5f67890123456,4194304,7d6c5b4a32109f8e,1699999996,RAW-CR2
```

**Fields:**
- `photo_head_md5`: MD5 hash of first 4KB of the photo file
- `file_size`: Size of the file in bytes
- `photo_md5`: Full MD5 hash of the entire file (may be empty initially)
- `photo_date`: Unix timestamp in seconds (EXIF date taken preferred, file creation date as fallback)
- `format`: Image format detected from magic bytes during initial scan
  - Common formats: `JPEG`, `PNG`, `HEIF`, `TIFF`, `GIF`, `WEBP`, `BMP`
  - RAW formats: `RAW-CR2`, `RAW-NEF`, `RAW-ARW`, `RAW-DNG`, `RAW-ORF`, `RAW-RAF`
  - Unknown: `UNKNOWN` (when format cannot be determined)

### 4.2 File Locations

| Category | Concept | Description |
| --- | --- | --- |
| Identity | `fast-photo-key` | `"{photo-head-md5}:{file-size}"`. Combines the MD5 of the first 4 KB with byte count. |
| Identity | `photo-md5` | Full file MD5 used for deduplication, thumbnail lookup, and cloud sync. |
| Cache (local) | Thumbnails | `{cache-root}/md5/thumbnails/{prefix-2-chars}/{photo-md5}.jpg` (prefix = first 2 hex chars). |
| Cache (local) | Metadata | `{cache-root}/md5/metadata/{prefix-2-chars}/{photo-md5}.json`. |
| Cache (Apple Photos) | Thumbnails | `{cache-root}/apple/thumbnails/{apple-photo-id}.jpg`. |
| Cache (Apple Photos) | Metadata | `{cache-root}/apple/metadata/{apple-photo-id}.json`. |
| Cache (S3) | Thumbnails | `{cache-root}/md5/thumbnails/{prefix-2-chars}/{photo-md5}.jpg`. |
| Cache (S3) | Metadata | `{cache-root}/md5/metadata/{prefix-2-chars}/{photo-md5}.json`. |
| Catalog (primary) | Snapshot | `{root-browsing-directory}/.photolala.{catalog-md5}.csv` (immutable version). |
| Catalog (primary) | Pointer | `{root-browsing-directory}/.photolala.md5` (first line = latest catalog MD5). |
| Catalog (cache) | Snapshot | `{cache-root}/{root-browsing-directory-md5}/.photolala.{catalog-md5}.csv`. |
| Catalog (cache) | Pointer | `{cache-root}/{root-browsing-directory-md5}/.photolala.md5`. |
| Catalog (working) | Working CSV | `{cache-root}/{root-browsing-directory-md5}/.photolala.csv` (read/write staging CSV prior to publishing snapshots). |
| Catalog (S3) | Snapshot | `s3://{bucket-name}/catalogs/{user-uuid}/.photolala.{catalog-md5}.csv`. |
| Catalog (S3) | Pointer | `s3://{bucket-name}/catalogs/{user-uuid}/.photolala.md5`. |
| Assets (S3) | Thumbnails | `s3://{bucket-name}/thumbnails/{user-uuid}/{photo-md5}.jpg`. |
| Assets (S3) | Photos | `s3://{bucket-name}/photos/{user-uuid}/{photo-md5}.dat` (uniform extension with Format tag). |

> **Note:**
> - **Thumbnails** are always JPEG (256×256px)
> - **S3 photos** use `.dat` extension for perfect deduplication (same MD5 = same S3 key)
> - **Format preservation** via CSV `format` column and S3 object tag (`Format=JPEG`)
> - **Export/serving** uses format to determine proper file extension and MIME type
> - **Pointer files** exist in both root and cache directories; update atomically and keep synchronized

## 5. Workflow
0. **Bootstrap & Working Copy**
   - Resolve the active catalog pointer: look for `.photolala.md5` in the root directory and the mirrored pointer under `{cache-root}/{root-browsing-directory-md5}/.photolala.md5`; prefer the root copy but fall back to the cache pointer if the root is missing.
   - When a pointer is found, confirm the referenced `.photolala.{catalog-md5}.csv` exists and its MD5 matches the pointer before using it.
   - Copy the validated snapshot to the working CSV at `{cache-root}/{root-browsing-directory-md5}/.photolala.csv`. If no pointer exists, create a fresh working CSV with just the header row.

1. **Discovery**
   - Enumerate the root-browsing-directory tree (async, skip hidden/system files).
   - Read first 4KB to compute `photo-head-md5` and detect format via magic bytes.
   - Collect `filename`, `file-size`, `photo-head-md5`, and `format`.
   - Persist `fast-photo-key` (head MD5 + file size) as the primary identity for change detection.

2. **Validation & Digest**
   - Verify candidate files are valid image assets.
   - Compute full `photo-md5` for deduplication.
   - Extract photo date (EXIF DateTimeOriginal preferred, file creation date as fallback).
   - Update CSV row with full MD5, photo date, and format.
   - Generate 256×256 JPEG thumbnail, store in cache shard.
   - Extract and cache detailed metadata (EXIF, dimensions, camera info) in separate JSON files.

3. **Caching**
   - Maintain minimal CSV catalog with identity, date, and format information.
   - Store thumbnails in `{cache-root}/md5/thumbnails/{prefix-2}/{photo-md5}.jpg`.
   - Store metadata in `{cache-root}/md5/metadata/{prefix-2}/{photo-md5}.json`.
   - Keep detailed metadata separate from catalog for simplicity.
   - Use atomic operations to prevent partial updates.

4. **Snapshot Persistence**
   - Write all entries to the working CSV file at `{cache-root}/{root-browsing-directory-md5}/.photolala.csv`.
   - Compute the MD5 hash of the entire CSV file content.
   - Copy the working CSV to both `{root-browsing-directory}/.photolala.{catalog-md5}.csv` and `{cache-root}/{root-browsing-directory-md5}/.photolala.{catalog-md5}.csv` using atomic renames.
   - Update pointer files in both locations with the new MD5 (overwrite, no append-only log).

5. **Reloading**
   - On subsequent visits, run the bootstrap sequence: read pointers (root first, cache fallback), validate the snapshot, and refresh the working copy.
   - If neither pointer yields a valid snapshot, initialize a new working CSV with the header row and treat the scan as a cold start.

6. **Update Detection**
   - Re-scan the root-browsing-directory to produce a new `fast-photo-key` set.
   - Compare with catalog contents, marking added/removed/changed entries.
   - Regenerate thumbnails/metadata for changed items, then produce a new snapshot and pointers.


## 6. Concurrency & Performance
- Run directory enumeration and head-MD5 computation on a cooperative background queue (concurrency tuned via QoS).
- Rate-limit thumbnail and metadata extraction to avoid saturating the file system.
- Use streaming CSV writes to handle large catalogs efficiently.
- Use actors (or serial executors) when exposing APIs to other modules to keep async access consistent.

## 7. Error Handling & Recovery
- **Corrupted Catalog**: If `.photolala.{md5}.csv` fails to parse or validate, fall back to rebuilding from scratch.
- **Missing Cache Entries**: Recompute thumbnails/metadata lazily when the browser requests them.
- **Permission Errors**: If the root-browsing-directory is read-only, continue writing snapshots to the cache mirror while logging the limitation.
- **Partial Updates**: Use temporary filenames and atomic renames for snapshots and pointer files to avoid torn writes.
- **CSV Parse Errors**: Skip malformed rows and log warnings; continue with valid entries.

## 8. Integration Points

### API for Browser Layer:
- `list(directory: URL) -> [CatalogEntry]` - Returns catalog entries with format info
- `thumbnail(for: PhotoID) -> URL?` - Returns cached thumbnail location
- `metadata(for: PhotoID) -> URL?` - Returns cached metadata JSON location
- `export(photoID: PhotoID, to: URL)` - Exports with correct extension based on format

### S3 Upload Strategy:
```
Key: photos/{user-uuid}/{photo-md5}.dat
Tags: Format=JPEG  (single tag, derives MIME type and extension)
Metadata: x-amz-meta-original-format=jpeg (optional)
```

### Format Detection:
- Happens once during initial scan (reading first 4KB for FastPhotoKey)
- Stored in CSV catalog and propagated to S3 tags
- Enables proper MIME type serving and file export

### Change Notifications:
- Emit updates via Combine publishers / async streams
- UI modules receive format info for proper display

## 9. Implementation Details

### Format Detection (ImageFormat.swift):
- Magic byte detection for 13+ formats
- Happens during FastPhotoKey computation (no extra I/O)
- Provides file extension and MIME type mappings
- Supports common formats (JPEG, PNG, HEIF) and RAW formats (CR2, NEF, ARW, etc.)

### CSV Structure:
- 5-column structure: `photo_head_md5,file_size,photo_md5,photo_date,format`
- Format stored as uppercase string matching S3 tags

### S3 Deduplication:
- All photos stored as `.dat` regardless of original format
- Format preserved in S3 tag for proper serving
- Lambda can read tag to set correct Content-Type header
- Apps can export with correct extension from format info

## 10. Change Detection Optimization

### Directory List Files
To avoid full rescans of unchanged directories, we maintain lightweight `.list` files:

**File Location:** `{root-browsing-directory}/.photolala.{catalog-md5}.list`

**CSV Structure:**
```csv
filename,file_size,mod_time
IMG_001.jpg,1048576,1699999990
IMG_002.heic,2097152,1699999990
```

**Fields:**
- `filename`: Base filename only
- `file_size`: Size in bytes
- `mod_time`: Modification time (seconds % 10) for rough change detection

**Workflow:**
1. When scanning a directory, create temporary list of files
2. After completing `.photolala.{catalog-md5}.csv`, save corresponding `.list`
3. On next visit, compare current file list with saved `.list`
4. Only rescan if differences detected (new/removed files, size changes)
5. Store `.list` for each subdirectory to enable partial rescans

> **Note:** Using `seconds % 10` for mod_time handles timestamp inconsistencies across network filesystems (APFS, SMB, etc.)

## 11. Open Questions & Future Work

### Resolved:
- **Catalog snapshots**: Keep only the latest snapshot (MD5 ensures integrity)
- **Format detection fallback**: Use `UNKNOWN` format when magic bytes are ambiguous; could use generic `image/*` MIME type

### TODO/Wishlist:
- Implement cache quota enforcement across md5/apple shards to prevent unbounded disk usage
- Add support for generic image MIME type (`image/*`) when format is unknown

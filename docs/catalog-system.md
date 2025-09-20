# K-Architecture: Directory Catalog System

## 1. Overview
Photolala must browse 100K+ local or remote images with smooth scrolling on Apple platforms. The K-Architecture Directory Catalog accelerates discovery and rendering by standardising metadata collection, sharding caches, and persisting immutable catalog snapshots that can be reused across sessions.

## 2. Goals
- **Instant Availability** – surface a root-browsing-directory’s photo list and thumbnails without re-reading full files.
- **Deterministic Identity** – identify assets via `fast-photo-key` (head MD5 + file size) before the full MD5 is available.
- **Cache Reuse** – rehydrate state from the most recent `.photolala.{md5}.sqlite` in-place or from `~/Library/Caches`.
- **Scalable Updates** – rescan only files whose `fast-photo-key` changes; avoid re-walking entire directory trees unnecessarily.

## 3. Scope & Assumptions
- Applies to any **root-browsing-directory** (local disk, removable media, mounted network share, S3-backed virtual folder).
- Directory metadata and thumbnail caches live on disk; in-memory caches are optional.
- Remote directories may change between scans; the system targets eventual consistency, not strong locking.

## 4. Data Model

| Category | Concept | Description |
| --- | --- | --- |
| Identity | `fast-photo-key` | `"{photo-head-md5}:{file-size}"`. Combines the MD5 of the first 4 KB with byte count. |
| Identity | `photo-md5` | Full file MD5 used for deduplication, thumbnail lookup, and cloud sync. |
| Cache (local) | Thumbnails | `{cache-root}/local/thumbnails/{prefix}/{photo-md5}.jpg` (prefix = first 2 hex chars). |
| Cache (local) | Metadata | `{cache-root}/local/metadata/{prefix}/{photo-md5}.json`. |
| Cache (Apple Photos) | Thumbnails | `{cache-root}/apple/thumbnails/{apple-photo-id}.jpg`. |
| Cache (Apple Photos) | Metadata | `{cache-root}/apple/metadata/{apple-photo-id}.json`. |
| Cache (S3) | Thumbnails | `{cache-root}/s3/thumbnails/{prefix}/{photo-md5}.jpg`. |
| Cache (S3) | Metadata | `{cache-root}/s3/metadata/{prefix}/{photo-md5}.json`. |
| Catalog (primary) | Snapshot | `{root-browsing-directory}/.photolala.{catalog-md5}.sqlite` (immutable version). |
| Catalog (primary) | Pointer | `{root-browsing-directory}/.photolala.md5` (first line = latest catalog MD5). |
| Catalog (cache) | Snapshot | `{cache-root}/{root-browsing-directory-md5}/.photolala.{catalog-md5}.sqlite`. |
| Catalog (cache) | Pointer | `{cache-root}/{root-browsing-directory-md5}/.photolala.md5`. |
| Catalog (S3) | Snapshot | `s3://{bucket-name}/catalogs/{user-uuid}/.photolala.{catalog-md5}.sqlite`. |
| Catalog (S3) | Pointer | `s3://{bucket-name}/catalogs/{user-uuid}/.photolala.md5`. |
| Assets (S3) | Thumbnails | `s3://{bucket-name}/thumbnails/{user-uuid}/{photo-md5}.jpg`. |
| Assets (S3) | Photos | `s3://{bucket-name}/photos/{user-uuid}/{photo-md5}.{photo-ext}`. |

> **Note:** Thumbnails are always JPEG. Original photo objects retain their source extension (`jpg`, `jpeg`, `heic`, `tiff`, etc.). Upload pipelines should ensure S3 keys encode the correct extension so downstream loaders infer MIME type without extra metadata.

## 5. Workflow

1. **Discovery**
   - Enumerate the root-browsing-directory tree (async, skip hidden/system files).
   - Collect `filename`, `file-size`, and `photo-head-md5`.
   - Persist `fast-photo-key` as the primary identity for change detection.

2. **Validation & Digest**
   - Verify candidate files are image assets (read minimal headers only).
   - For valid assets, compute full `photo-md5`, extract metadata (EXIF, timestamps, dimensions), and persist to cache.
   - Generate a 256×256 JPEG thumbnail and write to the thumbnail cache.

3. **Caching**
   - Maintain lookup tables `fast-photo-key → photo-md5` and `photo-md5 → {thumbnailURL, metadataURL}`.
   - Ensure caches are atomically updated so partial failures do not leave stale pointers.

4. **Catalog Persistence**
   - Populate SQLite tables (`entries`, `star_queue`, metadata blobs, version table).
   - Vacuum, compute `catalog-md5`, then write snapshots to both the root-browsing-directory and cache mirror.
   - Update pointer files (`.photolala.md5`) by overwriting with the new MD5 (no append-only log).

5. **Reloading**
   - On subsequent visits, attempt to read the root pointer. If missing or stale, fall back to the cache pointer.
   - Copy the referenced `.photolala.{md5}.sqlite` into a working location and use it to seed the browser.
   - If neither location yields a valid pointer, rebuild from scratch.

6. **Update Detection**
   - Re-scan the root-browsing-directory to produce a new `fast-photo-key` set.
   - Compare with catalog contents, marking added/removed/changed entries.
   - Regenerate thumbnails/metadata for changed items, then produce a new snapshot and pointer.

## 6. Concurrency & Performance
- Run directory enumeration and head-MD5 computation on a cooperative background queue (concurrency tuned via QoS).
- Rate-limit thumbnail and metadata extraction to avoid saturating the file system.
- Perform SQLite writes after all digests succeed; use journaled transactions to guard against crashes.
- Use actors (or serial executors) when exposing APIs to other modules to keep async access consistent.

## 7. Error Handling & Recovery
- **Corrupted Catalog**: If `.photolala.{md5}.sqlite` fails to open, fall back to the previous MD5 in `.photolala.md5`, then rebuild if no valid snapshot remains.
- **Missing Cache Entries**: Recompute thumbnails/metadata lazily when the browser requests them.
- **Permission Errors**: If the root-browsing-directory is read-only, continue writing snapshots to the cache mirror while logging the limitation.
- **Partial Updates**: Use temporary filenames and atomic renames for snapshots and pointer files to avoid torn writes.

## 8. Integration Points
- Provide APIs for the browser layer:
  - `list(directory: URL) -> [CatalogEntry]`
  - `thumbnail(for: PhotoID) -> URL?`
  - `metadata(for: PhotoID) -> URL?`
- Emit change notifications (Combine publishers / async streams) so UI modules update star state, counts, and caches.
- When starring/un-starring, record operations in `star_queue` for downstream cloud synchronisation.

## 9. Open Questions
- Should we keep an archive of the N most recent catalog snapshots to aid rollbacks, or prune aggressively?
- Do we need lightweight heuristics (e.g. timestamp diffs) to skip full rescan of large remote directories?
- How do we enforce cache quotas across local/apple/s3 shards to prevent unbounded disk usage?

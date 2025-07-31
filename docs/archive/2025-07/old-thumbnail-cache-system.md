# Old Thumbnail Cache System (Archived)

**Status**: ⚠️ Obsolete - Replaced by PhotoDigest system in July 2025

## Summary

This document describes the previous three-tier thumbnail caching architecture used in Photolala before the PhotoDigest implementation. The system has been replaced by the new two-level PhotoDigest architecture which provides better performance and cross-source deduplication.

## Key Components (Historical)

### Three-Tier Cache Hierarchy
1. **Memory Cache (NSCache)** - In-process thumbnail storage
2. **Metadata Cache (ThumbnailMetadataCache)** - JSON file mapping paths to MD5
3. **Disk Cache** - Thumbnail images stored by MD5 hash

### Limitations of Old System
- Separate storage of thumbnails and metadata
- No cross-source deduplication
- Limited to 4 concurrent loads
- Complex synchronization between caches

### Migration
The new PhotoDigest system includes automatic migration from the old cache format. Existing thumbnails are preserved and converted to the new structure on first access.

## Replacement
See `docs/current/photodigest-system.md` for the current caching architecture.
# Architecture Updates Summary

Based on [KY] notes and past discussions, the following clarifications have been made to the photo loading architecture documentation:

## 1. Disk Cache Structure

**Previous documentation**: Showed a hypothetical structure  
**Clarification**: Current implementation uses flat directory structure
- Location: `~/Library/Caches/Photolala/thumbnails/`
- Files: `[md5].thumbnail` and `[md5].metadata.plist`
- Future optimization: Subdirectories based on MD5 prefix (00-ff) for better filesystem performance with large collections

## 2. Directory UUID for Network Volumes

**Previous documentation**: Mentioned UUID but not the mechanism  
**Clarification**: UUID-based caching strategy
- When a directory has `.photolala/manifest.plist`, its `directoryUUID` is used as cache key
- This handles cases where same network directory is mounted at different paths
- Cache invalidation occurs when UUID changes (directory modified from another device)
- Falls back to MD5 hash of canonical path if no manifest exists

## 3. Unified Photo Processing

**Previous documentation**: Showed separate operations for thumbnail, MD5, and metadata  
**Clarification**: All three should be processed together for efficiency
- Single file read for all operations
- Parallel processing of thumbnail generation, MD5 computation, and metadata extraction
- Significantly reduces I/O operations (1 read instead of 3)
- Proposed `PhotoProcessor` class handles unified processing with priority queues

## 4. Network Directory Detection

**Previous documentation**: Listed multiple protocols (smb://, afp://, nfs://)  
**Clarification**: V1 implementation only checks `/Volumes/` prefix
- Assumes network volumes are mounted to system
- Simplified detection for initial version
- Future versions may add protocol-specific handling

## Key Architectural Principles

1. **Minimize I/O Operations**: Read each file once, extract all needed data
2. **Cache Aggressively**: Both memory and disk caching with appropriate limits
3. **Lazy Loading**: Defer expensive operations until actually needed
4. **UUID-Based Identity**: Use directory UUID when available for reliable caching across mount points
5. **Progressive Enhancement**: Start with simple implementations (e.g., /Volumes/ detection) and enhance later

These clarifications ensure the architecture documentation accurately reflects both the current implementation and the design decisions made during development.
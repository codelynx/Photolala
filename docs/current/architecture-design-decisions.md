# Architecture Design Decisions

## Key Principles

### 1. Progressive Enhancement
- Start with reasonable defaults (100+ photos for catalog, 5-minute cache)
- Improve based on real usage patterns in future releases
- Feature completeness first, optimization later

### 2. MD5 as Universal Identity
- **Full-file MD5 is critical** - enables eTag comparison for S3 sync
- Prevents re-downloading when file already exists locally
- Same photo in multiple locations = same identity
- Filename changes don't matter, only content

### 3. User-Driven Refresh
- Users control when to refresh/reload catalogs
- Avoids complex change detection in v1
- Clear mental model: "Reload" button = fresh scan

### 4. Pragmatic Caching
- NSCache provides automatic memory management
- 5-minute network cache is "good enough" starting point
- Can be tuned based on user feedback

### 5. Universal Catalog Generation
- Catalogs generated for all directories, regardless of size
- Small overhead for small directories is negligible
- Huge benefit for large directories
- Consistent behavior across all directory sizes

## Design Trade-offs

### Performance vs Completeness
- **Choice**: Full MD5 computation
- **Rationale**: Accurate deduplication and S3 eTag matching
- **Trade-off**: Slower initial processing for large files
- **Benefit**: Reliable sync and no duplicate downloads

### Simplicity vs Features
- **Choice**: Manual refresh instead of auto-detection
- **Rationale**: Simpler implementation, clearer user model
- **Trade-off**: Users must remember to refresh
- **Benefit**: Predictable behavior, no surprise rescans

### Memory vs Complexity
- **Choice**: Load all PhotoFile objects upfront
- **Rationale**: Simple implementation, good for typical use
- **Trade-off**: Higher memory use for 100K+ collections
- **Benefit**: No complex windowing logic, fast navigation

## Future Evolution Strategy

1. **Gather metrics** on typical directory sizes
2. **Profile performance** bottlenecks with real data
3. **Implement optimizations** based on actual usage:
   - Priority loading for visible items
   - Catalog invalidation detection
   - Progressive directory loading
   - Smart prefetching algorithms

## Implementation Philosophy

"Make it work, make it right, make it fast" - in that order.

Current focus: **Make it work** with reasonable performance for typical use cases (up to 10K photos).

The architecture is designed to allow future optimizations without major restructuring:
- Catalog format can evolve (version field)
- Cache durations are configurable
- Loading strategies can be swapped
- Priority systems can be added

## Key Insights

1. **MD5 enables unified identity** across local/network/S3 storage
2. **Universal catalog generation** - consistent behavior, small overhead, huge benefits for large dirs
3. **User control over refresh** prevents unexpected behavior
4. **Memory is cheaper than complexity** for typical photo collections
5. **Real usage data** should drive optimization priorities
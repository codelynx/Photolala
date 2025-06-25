# Log Cleanup Issues

Last Updated: June 22, 2025

## Current Log Issues

### 1. SwiftData Context Warnings (High Priority)
```
Illegal attempt to insert a model in to a different model context...
PersistentIdentifier was remapped to a temporary identifier during save...
```

**Cause**: PhotolalaCatalogServiceV2 might be creating entities on different contexts
**Impact**: Could lead to data corruption or crashes
**Solution**: Ensure all SwiftData operations use the same ModelContext

### 2. Verbose Debug Logs (Low Priority)
- "Stored mapping" messages - Already commented out
- S3 sync progress messages - Useful for debugging

### 3. Duplicate Log Messages
- "Loading photos from Photos Library" appears twice
- Likely called from multiple windows/views

### 4. System Warnings
```
"Error returned from daemon: Error Domain=com.apple.accounts Code=7"
"Unexpected bundle class 16 declaring type com.apple.photos.apple-adjustment-envelope"
```
These are Apple system warnings, not from our code.

## Recommendations

### Immediate Actions
1. Fix SwiftData context issues in PhotolalaCatalogServiceV2
2. Add log levels for different build configurations

### Future Improvements
1. Implement proper logging configuration
2. Add log filtering by category
3. Create debug/release log profiles

## SwiftData Context Fix

The issue is likely in PhotolalaCatalogServiceV2 where entities are created:
- Ensure modelContext.insert() is called on the same context
- Use @MainActor consistently
- Avoid creating entities before inserting them
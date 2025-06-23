# CSV to SwiftData Migration Guide

Last Updated: June 22, 2025

## Overview

This guide documents the migration path from the legacy CSV-based catalog system to the new SwiftData-based implementation. The migration preserves all photo metadata while providing enhanced performance and capabilities.

## Migration Strategy

### Principles

1. **Non-Destructive**: Original CSV files remain untouched during migration
2. **Reversible**: Can fall back to CSV if issues arise
3. **Incremental**: Migrate one catalog at a time
4. **Verified**: Checksums ensure data integrity

### Automatic Migration

The system automatically migrates CSV catalogs when:
- A directory with CSV catalog is opened
- SwiftData catalog doesn't exist or is older
- User has sufficient disk space

### Manual Migration

Users can trigger migration via:
- Settings → Advanced → Migrate Catalogs
- Command-line tool for batch migration

## Technical Implementation

### Migration Flow

```swift
class CatalogMigrationService {
    func migrateCatalog(at directoryURL: URL) async throws {
        // 1. Verify CSV catalog exists
        let csvCatalog = try loadCSVCatalog(at: directoryURL)
        
        // 2. Create SwiftData catalog
        let swiftDataCatalog = try await catalogService.createCatalog(
            for: directoryURL,
            uuid: csvCatalog.directoryUUID
        )
        
        // 3. Migrate each shard
        for shardIndex in 0..<16 {
            try await migrateShardToSwiftData(
                csvShard: csvCatalog.shards[shardIndex],
                targetShard: swiftDataCatalog.shard(at: shardIndex)
            )
        }
        
        // 4. Verify migration
        try await verifyMigration(csv: csvCatalog, swiftData: swiftDataCatalog)
        
        // 5. Mark as migrated (don't delete CSV yet)
        try markAsMigrated(directoryURL)
    }
}
```

### Data Mapping

| CSV Field | SwiftData Property | Notes |
|-----------|-------------------|-------|
| md5 | PhotoEntry.md5 | Primary key |
| filename | PhotoEntry.filename | Unescaped during import |
| size | PhotoEntry.fileSize | Int64 conversion |
| photodate | PhotoEntry.photoDate | Unix timestamp → Date |
| modified | PhotoEntry.fileModifiedDate | Unix timestamp → Date |
| width | PhotoEntry.pixelWidth | Optional Int |
| height | PhotoEntry.pixelHeight | Optional Int |
| applephotoid | PhotoEntry.applePhotoID | v5.1 addition |

### Extended Metadata

During migration, the system attempts to enrich entries with:
- EXIF data from photo files (if accessible)
- Backup status from S3 (if online)
- Cached thumbnail dates

## User Experience

### Progress Indication

```
Migrating catalog for /Photos/2024...
[████████████████████░░░░] 75% - Shard C of F
Migrated 12,345 photos successfully
```

### Error Handling

Common scenarios:
- **Insufficient Space**: Prompt to free up space
- **Corrupted CSV**: Skip bad entries, log errors
- **Network Issues**: Continue with local data only

### Rollback Option

If issues occur post-migration:
1. Settings → Advanced → Use Legacy Catalogs
2. Restart application
3. CSV catalogs resume operation

## Performance Comparison

### Before (CSV)
- Load time: O(n) file reads
- Search: Linear scan through shards
- Updates: Full shard rewrite
- Memory: Entire shard in memory

### After (SwiftData)
- Load time: Indexed database queries
- Search: SQL WHERE clauses
- Updates: Individual row updates
- Memory: Lazy loading with faulting

### Benchmarks

| Operation | CSV (10k photos) | SwiftData (10k photos) |
|-----------|-----------------|----------------------|
| Initial Load | 850ms | 120ms |
| Find by MD5 | 45ms | 2ms |
| Update Entry | 180ms | 5ms |
| Memory Usage | 125MB | 45MB |

## S3 Synchronization

### Compatibility

- S3 continues using CSV format
- SwiftData exports to CSV for upload
- Headers ensure forward compatibility

### Sync Behavior

Post-migration sync:
1. Check S3 for updates (pull-first)
2. Import changes to SwiftData
3. Export modified shards to CSV
4. Upload to S3

## Troubleshooting

### Common Issues

**"Migration seems stuck"**
- Check Activity Monitor for CPU usage
- Large catalogs may take several minutes
- Progress should increment steadily

**"Some photos missing after migration"**
- Check migration log: ~/Library/Logs/Photolala/migration.log
- Verify CSV wasn't corrupted
- Re-run migration for affected directory

**"Can't open directory after migration"**
- Enable legacy mode temporarily
- Check SwiftData file permissions
- Reset catalog if necessary

### Debug Commands

```bash
# Check migration status
defaults read com.electricwoods.photolala MigratedCatalogs

# Force re-migration
defaults delete com.electricwoods.photolala MigratedCatalog_<uuid>

# Enable verbose logging
defaults write com.electricwoods.photolala CatalogMigrationDebug -bool YES
```

## Best Practices

### For Users

1. **Backup First**: Time Machine or manual backup
2. **Start Small**: Test with smaller directories
3. **Monitor Progress**: Watch for errors
4. **Report Issues**: Include migration.log

### For Developers

1. **Test Coverage**: Unit tests for edge cases
2. **Performance Monitoring**: Track migration times
3. **Error Telemetry**: Anonymous error reporting
4. **Gradual Rollout**: Feature flag control

## Future Improvements

### v2.1 Plans
- Background migration option
- Batch migration UI
- Migration scheduling
- Cloud backup before migration

### v3.0 Vision
- Direct SwiftData generation (skip CSV)
- Incremental migration support
- Cross-device sync via CloudKit

## Summary

The CSV to SwiftData migration provides significant performance improvements while maintaining full compatibility with existing S3 infrastructure. The careful migration approach ensures data integrity and provides fallback options for users who encounter issues.
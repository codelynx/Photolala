# Catalog Integration Phase 2: SwiftData Integration and S3 Sync

## Overview

This document outlines the integration of the SwiftData catalog implementation with existing photo providers and the implementation of S3 synchronization.

## Phase 2 Goals

1. Integrate SwiftData catalog with DirectoryPhotoProvider
2. Implement S3 catalog synchronization
3. Add UI controls for catalog management
4. Handle conflict resolution between local and S3

## 1. DirectoryPhotoProvider Integration

### Current State
- DirectoryPhotoProvider uses PhotolalaCatalogService (CSV-based)
- Loads catalog on directory change
- Updates catalog when photos are starred

### Integration Plan

#### 1.1 Service Selection Strategy
```swift
// In DirectoryPhotoProvider
private var catalogService: any CatalogService {
    if FeatureFlags.useSwiftDataCatalog {
        return catalogServiceV2
    } else {
        return legacyCatalogService
    }
}
```

#### 1.2 Protocol Definition
```swift
protocol CatalogService {
    func loadCatalog(for directoryURL: URL) async throws -> Any
    func updateStarStatus(md5: String, isStarred: Bool) async throws
    func findEntry(md5: String) async throws -> CatalogEntryProtocol?
}

protocol CatalogEntryProtocol {
    var md5: String { get }
    var isStarred: Bool { get }
    var backupStatus: BackupStatus { get }
}
```

#### 1.3 Migration Path
1. Add feature flag for SwiftData catalog
2. Create protocol abstraction for catalog operations
3. Update DirectoryPhotoProvider to use protocol
4. Gradual rollout via feature flag

## 2. S3 Catalog Synchronization

### 2.1 Sync Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Local SwiftData │ ←→  │ S3CatalogSync    │ ←→  │ S3 CSV Catalogs │
│    Catalog      │     │    Service       │     │   (16 shards)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         ↓                       ↓                         ↓
   [Dirty Tracking]       [Sync Logic]            [Master Source]
```

### 2.2 S3CatalogSyncServiceV2 Implementation

#### Download Flow
1. Fetch S3 manifest (catalog_manifest.json)
2. Compare checksums with local shards
3. Download only changed shards
4. Parse CSV and update SwiftData
5. Mark shards as clean

#### Upload Flow
1. Check dirty shards in local catalog
2. Export dirty shards to CSV
3. Upload to S3 with checksums
4. Update manifest
5. Mark shards as clean

### 2.3 Conflict Resolution

**Strategy: S3 Always Wins**
- During download: S3 data overwrites local
- Exception: Local starred items are preserved
- Merge logic:
  1. Download S3 shard
  2. Get local starred items
  3. Apply S3 data
  4. Re-apply local stars
  5. Mark for upload if stars added

## 3. UI Integration

### 3.1 Catalog Sync Status Bar
```swift
struct CatalogSyncStatusBar: View {
    @ObservedObject var syncService: S3CatalogSyncServiceV2
    
    var body: some View {
        HStack {
            if syncService.isSyncing {
                ProgressView()
                Text("Syncing catalog...")
            } else if let lastSync = syncService.lastSyncDate {
                Image(systemName: "checkmark.circle")
                Text("Last sync: \(lastSync, style: .relative)")
            }
            
            Button("Sync Now") {
                Task { await syncService.syncCatalog() }
            }
        }
    }
}
```

### 3.2 Integration Points
- Add sync status to DirectoryPhotoBrowserView toolbar
- Show sync progress in BackupStatusBar
- Add manual sync button in preferences
- Display conflict count if any

## 4. Implementation Steps

### Phase 2A: Protocol Abstraction (1-2 days)
1. Define CatalogService protocol
2. Create adapters for both catalog services
3. Update DirectoryPhotoProvider
4. Add feature flag

### Phase 2B: S3 Sync Implementation (3-4 days)
1. Implement S3 manifest operations
2. Add shard download logic
3. Implement CSV parsing to SwiftData
4. Add upload functionality
5. Implement conflict resolution

### Phase 2C: UI Integration (1-2 days)
1. Create CatalogSyncStatusBar
2. Integrate into existing views
3. Add progress indicators
4. Test sync workflows

### Phase 2D: Testing & Rollout (2-3 days)
1. Unit tests for sync logic
2. Integration tests with S3
3. Manual testing of edge cases
4. Gradual feature flag rollout

## 5. Success Criteria

1. DirectoryPhotoProvider works with both catalog services
2. S3 sync completes without data loss
3. Conflict resolution preserves user intent
4. UI clearly shows sync status
5. Performance is equal or better than CSV

## 6. Future Enhancements

1. Incremental sync using delta files
2. Background sync on timer
3. Sync queue for offline changes
4. Multi-device conflict resolution
5. Catalog version migration

## 7. Risks and Mitigations

### Risk: Data Loss During Sync
- Mitigation: Always backup before sync
- Mitigation: Atomic operations with rollback

### Risk: Performance Degradation
- Mitigation: Benchmark before/after
- Mitigation: Optimize SwiftData queries

### Risk: S3 API Limits
- Mitigation: Batch operations
- Mitigation: Implement rate limiting
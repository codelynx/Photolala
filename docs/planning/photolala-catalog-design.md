# Photolala Catalog Final Design

## Overview

This document represents the final, consolidated design for the Photolala catalog system. It combines the best ideas from iterative design discussions and incorporates the latest architectural decisions.

## Core Design Principles

1. **CSV format** - Human readable, easily extensible, debuggable
2. **Hash-based sharding** - 16 shards based on last MD5 hex digit for scalability
3. **Direct shard updates** - Simple read-modify-write operations
4. **Plist manifest** - Binary plist (.photolala) containing shard checksums
5. **Unix timestamps** - Consistent, timezone-agnostic time representation
6. **No status tracking** - Calculate backup status on-demand via MD5 lookup

## File Structure

```
MyPhotos/
├── .photolala                # Binary plist manifest (contains shard MD5s)
├── .photolala#0              # CSV shard for MD5s ending in 0
├── .photolala#1              # CSV shard for MD5s ending in 1
├── .photolala#2              # CSV shard for MD5s ending in 2
...
├── .photolala#e              # CSV shard for MD5s ending in e
├── .photolala#f              # CSV shard for MD5s ending in f
└── [photo files]
```

## Manifest File Format (.photolala)

Binary plist containing:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>version</key>
    <string>4.0</string>
    <key>sharding</key>
    <string>hash:16</string>
    <key>shards</key>
    <dict>
        <key>0</key>
        <string>a1b2c3d4e5f6g7h8i9j0...</string>  <!-- MD5 of .photolala#0 -->
        <key>1</key>
        <string>b2c3d4e5f6g7h8i9j0k1...</string>  <!-- MD5 of .photolala#1 -->
        ...
        <key>f</key>
        <string>f6g7h8i9j0k1l2m3n4o5...</string>  <!-- MD5 of .photolala#f -->
    </dict>
    <key>updated</key>
    <integer>1718445000</integer>  <!-- Unix timestamp -->
</dict>
</plist>
```

## CSV Shard Format

Each shard file (.photolala#0 through .photolala#f):
```csv
# photolala v4.0
filename,size,modified,md5,width,height,photodate
IMG_0129.jpg,2048576,1718445000,d41d8cd98f00b204e9800998ecf8427e,4032,3024,1718445000
IMG_0130.jpg,1843200,1718445060,10f7a3b2c1d4e6f8a9b0c1d2e3f4a5b6,4032,3024,1718445060
```

Notes:
- All timestamps are Unix time (seconds since epoch)
- MD5 is hex string (32 characters)
- Photos are distributed to shards based on last hex digit of MD5
- No backup status or storage class fields (calculated on-demand)
- Direct shard updates for simplicity

## Update Strategy

For the first release, updates are handled by rewriting the affected shard:

1. **Add Photo**: Load shard → Add entry → Write shard → Update manifest
2. **Remove Photo**: Load shard → Remove entry → Write shard → Update manifest  
3. **Update Photo**: Load shard → Update entry → Write shard → Update manifest

This is simple and sufficient for most use cases.

## Sharding Algorithm

Photos are distributed across 16 shards based on the last hexadecimal digit of their MD5 hash:

```swift
func getShardForPhoto(md5: String) -> String {
    let lastChar = String(md5.suffix(1))
    return ".photolala#\(lastChar)"
}

// Example:
// MD5: d41d8cd98f00b204e9800998ecf8427e
// Last digit: 'e'
// Shard file: .photolala#e
```

## Read Algorithm

```swift
func loadCatalog() -> [PhotoEntry] {
    // 1. Read manifest
    guard let manifest = readPlist(".photolala") else { return [] }
    
    // 2. Verify version
    guard manifest["version"] == "4.0" else { 
        // Handle migration from older versions
        return migrateAndLoad()
    }
    
    var allEntries: [PhotoEntry] = []
    
    // 3. Read all shards
    for hex in "0123456789abcdef" {
        let shardPath = ".photolala#\(hex)"
        
        // Skip missing shards (normal for small collections)
        guard fileExists(shardPath) else { continue }
        
        // Verify shard checksum (optional, for integrity)
        if let expectedMD5 = manifest.shards[String(hex)] {
            let actualMD5 = calculateMD5(shardPath)
            if actualMD5 != expectedMD5 {
                // Log warning, shard may have been modified
            }
        }
        
        // Load shard entries
        let entries = parseCSV(shardPath)
        allEntries.append(contentsOf: entries)
    }
    
    return allEntries
}
```

## Write Algorithm

```swift
func addPhoto(_ entry: PhotoEntry) {
    // 1. Determine shard
    let shard = String(entry.md5.suffix(1))
    let shardPath = ".photolala#\(shard)"
    
    // 2. Load existing entries (or create empty array)
    var entries: [PhotoEntry] = []
    if fileExists(shardPath) {
        entries = parseCSV(shardPath)
    }
    
    // 3. Add new entry
    entries.append(entry)
    
    // 4. Write back to shard
    writeCSV(shardPath, entries: entries)
    
    // 5. Update manifest with new checksum
    let newMD5 = calculateMD5(shardPath)
    updateManifest(shard: shard, md5: newMD5)
}

func removePhoto(md5: String) {
    // 1. Determine shard
    let shard = String(md5.suffix(1))
    let shardPath = ".photolala#\(shard)"
    
    // 2. Load existing entries
    guard fileExists(shardPath) else { return }
    var entries = parseCSV(shardPath)
    
    // 3. Remove entry
    entries.removeAll { $0.md5 == md5 }
    
    // 4. Write back or delete if empty
    if entries.isEmpty {
        deleteFile(shardPath)
        updateManifest(shard: shard, md5: nil) // Remove from manifest
    } else {
        writeCSV(shardPath, entries: entries)
        let newMD5 = calculateMD5(shardPath)
        updateManifest(shard: shard, md5: newMD5)
    }
}

func updatePhoto(_ entry: PhotoEntry) {
    // 1. Determine shard
    let shard = String(entry.md5.suffix(1))
    let shardPath = ".photolala#\(shard)"
    
    // 2. Load existing entries
    guard fileExists(shardPath) else { 
        // If shard doesn't exist, just add the photo
        addPhoto(entry)
        return
    }
    var entries = parseCSV(shardPath)
    
    // 3. Update entry
    if let index = entries.firstIndex(where: { $0.md5 == entry.md5 }) {
        entries[index] = entry
    } else {
        // Entry not found, add it
        entries.append(entry)
    }
    
    // 4. Write back to shard
    writeCSV(shardPath, entries: entries)
    
    // 5. Update manifest with new checksum
    let newMD5 = calculateMD5(shardPath)
    updateManifest(shard: shard, md5: newMD5)
}
```

## S3 Master Catalog

For S3 backup service, maintain a separate master catalog:

```
s3://photolala/catalog/{userId}/master.photolala.json
```

JSON format (indexed by MD5 for deduplication):
```json
{
  "version": "4.0",
  "created": 1705493600,
  "photos": {
    "d41d8cd98f00b204e9800998ecf8427e": {
      "size": 2048576,
      "photoDate": 1718445000,
      "uploadDate": 1718531400,
      "storageClass": "DEEP_ARCHIVE"
    },
    "e5f7a3b2c1d4e6f8a9b0c1d2e3f4a5b6": {
      "size": 1843200,
      "photoDate": 1718445060,
      "uploadDate": 1718531400,
      "storageClass": "STANDARD"
    }
  }
}
```

Note: Storage class is only tracked in S3, not in local catalogs.

## Backup Status Check

Instead of tracking backup status in local catalogs:

```swift
struct S3Catalog {
    let photosByMD5: Set<String>  // Just MD5s for quick lookup
    
    init(from json: Data) {
        // Parse JSON and extract MD5 keys
        let catalog = try JSONDecoder().decode(S3MasterCatalog.self, from: json)
        self.photosByMD5 = Set(catalog.photos.keys)
    }
}

extension PhotoEntry {
    func isBackedUp(using s3Catalog: S3Catalog) -> Bool {
        return s3Catalog.photosByMD5.contains(self.md5)
    }
}
```

## Migration Strategies

### From Single CSV File

```swift
func migrateFromSingleFile() {
    // 1. Read old .photolala
    let entries = parseCSV(".photolala")
    
    // 2. Group by MD5 last digit
    var shards: [String: [PhotoEntry]] = [:]
    for entry in entries {
        let shard = String(entry.md5.suffix(1))
        shards[shard, default: []].append(entry)
    }
    
    // 3. Write shards
    var shardChecksums: [String: String] = [:]
    for (shard, entries) in shards {
        let path = ".photolala#\(shard)"
        writeCSV(path, entries: entries)
        shardChecksums[shard] = calculateMD5(path)
    }
    
    // 4. Create manifest
    let manifest = [
        "version": "4.0",
        "sharding": "hash:16",
        "shards": shardChecksums,
        "updated": Int(Date().timeIntervalSince1970)
    ]
    writePlist(".photolala", manifest)
    
    // 5. Backup and remove old file
    renameFile(".photolala", to: ".photolala.backup")
}
```

### From Version-Based System

Similar approach, read all shards first before redistributing.

## Performance Characteristics

| Photos | Single File | 16 Shards | Benefit |
|--------|-------------|-----------|---------|
| 1K     | 100KB       | 16×6KB    | Minimal overhead |
| 10K    | 1MB         | 16×62KB   | Faster partial updates |
| 100K   | 10MB        | 16×625KB  | Parallel operations |
| 1M     | 100MB       | 16×6.25MB | Manageable parse size |

Each shard handles ~6% of photos, ensuring:
- Fast parsing even for large collections
- Isolated updates (only affected shard)
- Parallel read/write capability
- Predictable memory usage

## Edge Cases and Error Handling

1. **Missing Shard**: Normal for small collections, create on first write
2. **Corrupt Shard**: Log error, skip shard, optionally rebuild from photos
3. **Manifest Checksum Mismatch**: Log warning, shard was modified outside app
4. **Concurrent Access**: Use file locking or accept last-writer-wins

## Implementation Checklist

- [ ] Plist manifest reading/writing
- [ ] CSV shard parser with 16-shard support
- [ ] Shard operations (add, remove, update)
- [ ] MD5-based sharding function
- [ ] Migration from single file
- [ ] Migration from version-based system
- [ ] S3 catalog integration
- [ ] Backup status checking via MD5 lookup
- [ ] Unit tests for all operations
- [ ] Performance tests with 100K+ photos

## Future Enhancements

1. **Compression**: Gzip shards for network/backup storage
2. **Incremental Sync**: Track manifest update time for efficient S3 sync
3. **Parallel Operations**: Read/write different shards concurrently
4. **Integrity Verification**: Optional checksum verification on read
5. **Album Support**: Multiple catalogs per directory (future consideration)

This design provides a robust, scalable catalog system that handles both small personal collections and large professional libraries efficiently.
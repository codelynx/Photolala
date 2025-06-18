# Catalog Hash-Based Sharding Design

## Core Concept

The catalog is split into 16 shards based on the last hexadecimal digit of each photo's MD5 hash. This provides perfect distribution and predictable performance as collections grow.

## File Structure

```
.photolala          # Master pointer file (contains: "hash:16")
.photolala#0        # Base catalog for MD5s ending in 0
.photolala#0.1      # Delta 1
.photolala#0.2      # Delta 2
.photolala#1        # Base catalog for MD5s ending in 1
.photolala#1.1      # Delta 1
...
.photolala#f        # Base catalog for MD5s ending in f
.photolala#f.1      # Delta 1
```

## Master Catalog File

The `.photolala` file indicates hash-based sharding:
```
hash:16
```

This tells the system to look for `.photolala#0` through `.photolala#f`.

## Naming Convention

- Base: `.photolala#{hex_digit}`
- Deltas: `.photolala#{hex_digit}.{delta_number}`
- Hex digits: 0-9, a-f (16 shards)
- Delta numbers: 1 through 10 (max 10 deltas per shard)
- Merge: When reaching 10 deltas, merge back to base

## Read Algorithm

```swift
func readAllCatalogs() -> [PhotoEntry] {
    var allEntries: [PhotoEntry] = []

    // Read all 16 shards
    for hex in "0123456789abcdef" {
        let shardEntries = readShard(hex: String(hex))
        allEntries.append(contentsOf: shardEntries)
    }

    return allEntries
}

func readShard(hex: String) -> [PhotoEntry] {
    let basePath = ".photolala#\(hex)"
    guard fileExists(basePath) else { return [] }

    // Load base catalog
    var entries = parseCSV(basePath)

    // Apply deltas in order
    for i in 1...10 {
        let deltaPath = "\(basePath).\(i)"
        if fileExists(deltaPath) {
            let deltaOps = parseCSV(deltaPath)
            entries = applyDelta(entries, deltaOps)
        } else {
            break
        }
    }

    return entries
}
```

## Write Algorithm

```swift
func addPhotoEntry(entry: PhotoEntry) {
    // Determine shard based on MD5
    let hex = String(entry.md5.suffix(1))
    let basePath = ".photolala#\(hex)"

    // Initialize shard if needed
    if !fileExists(basePath) {
        writeCSV(basePath, entries: [entry])
        return
    }

    // Find next available delta slot
    for i in 1...10 {
        let deltaPath = "\(basePath).\(i)"
        if !fileExists(deltaPath) {
            // Write to this delta
            appendCSV(deltaPath, operation: "+", entry: entry)
            return
        }
    }

    // All delta slots used, merge required
    mergeShard(hex: hex)
    // Then add to newly merged base
    appendCSV("\(basePath).1", operation: "+", entry: entry)
}
```

## Merge Algorithm

```swift
func mergeShard(hex: String) {
    let basePath = ".photolala#\(hex)"

    // 1. Load current state (base + all deltas)
    let mergedEntries = readShard(hex: hex)

    // 2. Write to temporary file
    let tempPath = "\(basePath).tmp"
    writeCSV(tempPath, entries: mergedEntries)

    // 3. Clean up deltas
    for i in 1...10 {
        deleteFileIfExists("\(basePath).\(i)")
    }

    // 4. Atomically replace base
    renameFile(tempPath, to: basePath)
}
```

## Delta Operation Format

Each delta file uses the same CSV structure with an operation prefix:

```csv
op,filename,size,modified,md5,width,height,photodate
+,NEW.jpg,2048576,1718445000,a1b2c3...,4032,3024,1718445000
-,DELETED.jpg
=,UPDATED.jpg,2048576,1718445100,b2c3d4...,4032,3024,1718445000
```

Operations:
- `+` : Add new entry
- `-` : Remove entry (only filename needed)
- `=` : Update entry (replace existing)

## Apply Delta Logic

```swift
func applyDelta(entries: [PhotoEntry], operations: [DeltaOp]) -> [PhotoEntry] {
    var result = entries

    for op in operations {
        switch op.operation {
        case "+":
            result.append(op.entry)
        case "-":
            result.removeAll { $0.filename == op.filename }
        case "=":
            if let index = result.firstIndex(where: { $0.filename == op.filename }) {
                result[index] = op.entry
            }
        }
    }

    return result
}
```

## Advantages

1. **Perfect Distribution**: MD5 hash ensures even spread across shards
2. **Predictable Performance**: Each shard stays small (~6K entries for 100K photos)
3. **Parallel Operations**: Can read/write different shards concurrently
4. **Limited Deltas**: Max 10 per shard prevents unbounded growth
5. **Crash Safe**: Operations isolated to single shard

## Edge Cases

### Crash During Merge
- Only affects single shard
- Retry merge on next access to that shard
- Temporary `.photolala#x.tmp` ignored

### Missing Delta
- Skip missing numbers (if '.1' missing, still apply '.2')
- Log warning for debugging

### Missing Shard
- Normal for new/small collections
- Create shard on first write

### Concurrent Access
- Different shards can be accessed concurrently
- Use file locking per shard for safety
- Or accept last-writer-wins for deltas

## File Size Considerations

With 100K photos across 16 shards:
- Per shard: ~6,250 photos
- Base catalog: ~625KB per shard
- Total: 16 × 625KB = ~10MB (same as single file)
- But much better performance due to smaller parse units

## Migration Path

### From Single Catalog
1. Read existing `.photolala` catalog
2. For each entry, calculate MD5 last digit
3. Write to appropriate `.photolala#x` shard
4. Update `.photolala` to contain "hash:16"
5. Delete old catalog after verification

### From Version-Based
1. Read current version from `.photolala`
2. Load full catalog (base + deltas)
3. Redistribute to hash-based shards
4. Update `.photolala` pointer

## Performance Comparison

| Photos | Single File | 16 Shards | Benefit |
|--------|-------------|-----------|---------|
| 10K    | 1MB         | 16×62KB   | Faster partial loads |
| 100K   | 10MB        | 16×625KB  | Parallel operations |
| 1M     | 100MB       | 16×6.25MB | Much faster parsing |cl

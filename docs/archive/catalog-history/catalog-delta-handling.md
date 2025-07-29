# Catalog Delta Handling Design

## Version-Based Delta System

### File Structure
```
.photolala          # Version pointer (contains: ".photolala.001")
.photolala.001      # Current base catalog
.photolala.001.a    # First delta
.photolala.001.b    # Second delta
.photolala.001.c    # Third delta
```

### Reading Process
```swift
func loadCatalog() -> PhotoCatalog {
    // 1. Read version from .photolala
    let version = readFile(".photolala").trim() // ".photolala.001"
    
    // 2. Load base catalog
    var catalog = parseCSV(version)
    
    // 3. Apply deltas in order
    for suffix in ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"] {
        let deltaFile = "\(version).\(suffix)"
        if fileExists(deltaFile) {
            applyDelta(catalog, parseCSV(deltaFile))
        } else {
            break
        }
    }
    
    return catalog
}
```

### Writing Process
```swift
func addPhoto(photo: PhotoInfo) {
    let version = readFile(".photolala").trim()
    
    // Find next available delta slot
    var deltaFile: String?
    for suffix in ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"] {
        let candidate = "\(version).\(suffix)"
        if !fileExists(candidate) {
            deltaFile = candidate
            break
        }
    }
    
    // Write delta or trigger merge
    if let deltaFile = deltaFile {
        appendToCSV(deltaFile, "+,\(photo.toCSV())")
    } else {
        mergeAndCreateNewVersion()
    }
}
```

### Merge Process
```swift
func mergeAndCreateNewVersion() {
    let currentVersion = readFile(".photolala").trim() // ".photolala.001"
    let versionNum = Int(currentVersion.suffix(3))!
    let nextVersion = String(format: ".photolala.%03d", versionNum + 1)
    
    // Load and merge all
    let merged = loadCatalog() // This applies all deltas
    
    // Write new base
    writeCSV(nextVersion, merged)
    
    // Update version pointer
    writeFile(".photolala", nextVersion)
    
    // Clean up old files (keep previous version for safety)
    // Delete .001.a, .001.b, etc. but keep .001
}
```

## Delta CSV Format

### Option 1: Operation Column
```csv
op,filename,size,modified,md5,width,height,photodate
+,NEW.jpg,2048576,1718445000,a1b2c3...,4032,3024,1718445000
-,OLD.jpg
u,CHANGED.jpg,2048576,1718445100,b2c3d4...,4032,3024,1718445000
```

### Option 2: Separate Sections
```csv
# ADD
NEW.jpg,2048576,1718445000,a1b2c3...,4032,3024,1718445000
ANOTHER.jpg,1048576,1718445100,b2c3d4...,3024,4032,1718445100
# DELETE  
OLD.jpg
REMOVED.jpg
# UPDATE
CHANGED.jpg,2048576,1718445200,c3d4e5...,4032,3024,1718445000
```

## Merge Triggers

Merge when:
1. More than 10 delta files (a-j used)
2. Total delta size > 20% of base
3. App launch (if deltas exist)
4. User idle for 5+ minutes

## Benefits

1. **Simple versioning** - Just increment number
2. **Atomic updates** - Write new version, then update pointer
3. **Crash recovery** - Previous version always available
4. **Limited deltas** - Max 10 before forced merge
5. **Clean format** - Standard CSV throughout

## Edge Cases

1. **Crash during merge**: Version pointer unchanged, retry on next launch
2. **Missing delta**: Skip and continue (a, c, d is OK)
3. **Corrupt base**: Fall back to previous version
4. **Version 999**: Reset to 001 (very unlikely)

This approach is simpler than timestamp-based deltas and provides clear version history.
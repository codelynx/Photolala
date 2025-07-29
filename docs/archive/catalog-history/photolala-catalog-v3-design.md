# .photolala Catalog Design V3 (KY Refined)

## Core Principles

1. **CSV for catalogs** - Human readable, extensible columns
2. **Binary plist for metadata** - Compact, flexible per-photo data
3. **MD5 as Data type** - Use binary where possible
4. **Smart delta handling** - Version-based incremental updates

## Catalog Organization

### Multiple Catalogs per Directory
```
MyPhotos/
├── .catalogs/
│   ├── vacation-2024.photolala    # Album-specific catalog
│   ├── graduation-2023.photolala  # Another album
│   └── master.photolala           # All photos in directory
├── IMG_0129.jpg
├── IMG_0130.jpg
└── Vacation2024/
    └── DSC_0001.jpg
```

### CSV Format (lowercase field names)
```csv
# .photolala v3.0
filename,size,modified,md5,width,height,photodate
IMG_0129.jpg,2048576,1718445000,d41d8cd98f00b204e9800998ecf8427e,4032,3024,1718445000
IMG_0130.jpg,1843200,1718445060,e5f7a3b2c1d4e6f8a9b0c1d2e3f4a5b6,4032,3024,1718445060
```

## Delta File Strategy

### Version-Based Approach
```
.photolala          # Contains: ".photolala.001"
.photolala.001      # Base catalog (current version)
.photolala.001.a    # Delta A
.photolala.001.b    # Delta B
```

### Merge Process
1. Read current version from `.photolala`
2. Apply deltas: `.001` + `.001.a` + `.001.b` → `.002`
3. Write `.photolala.002`
4. Update `.photolala` to contain ".photolala.002"
5. Clean up old files

### Delta Format with Operations
```csv
# .photolala.001.a
op,filename,size,modified,md5,width,height,photodate
+,NEW_IMG.jpg,2048576,1718445000,a1b2c3d4e5f6...,4032,3024,1718445000
-,OLD_IMG.jpg,,,,,,,
u,UPDATED.jpg,2048576,1718445100,b2c3d4e5f6g7...,4032,3024,1718445000
```

Operations:
- `+` : Add new photo
- `-` : Remove photo
- `u` : Update existing (changed MD5)

[KY] howabout update for `=` (symbol not alphabet)


## S3 Integration

### S3 Catalog (CSV, no status tracking)
```
s3://photolala/catalog/{userId}/master.photolala
```

Contains only backed-up photos with minimal fields:
```csv
md5,size,photodate,uploaddate
d41d8cd98f00b204e9800998ecf8427e,2048576,1718445000,1718531400
```

### Binary MD5 Usage
```swift
struct PhotoCatalog {
    // MD5 as Data (16 bytes) instead of String (32 chars)
    let photos: Set<Data>  // For existence check

    func contains(md5: Data) -> Bool {
        return photos.contains(md5)
    }
}

extension PhotoReference {
    var md5Data: Data {
        // Return 16-byte MD5 as Data
    }

    func isBackedUp(using catalog: PhotoCatalog) -> Bool {
        return catalog.photos.contains(self.md5Data)
    }
}
```

## Metadata Storage (Binary Plist)

For rich metadata, use separate plist files:
```
MyPhotos/
├── .metadata/
│   ├── d41d8cd98f00b204e9800998ecf8427e.plist
│   └── e5f7a3b2c1d4e6f8a9b0c1d2e3f4a5b6.plist
```

Binary plist contents:
- EXIF data
- Face recognition
- Keywords/tags
- User notes
- Location data

## Benefits of This Design

1. **CSV simplicity** - Easy to debug, extend, process
2. **Binary efficiency** - MD5 as Data saves 50% space
3. **Clean deltas** - Version-based, not timestamp-based
4. **Flexible metadata** - Plist for complex data
5. **Album support** - Multiple catalogs per directory

## Implementation Priority

1. Basic CSV catalog with lowercase fields
2. Binary MD5 for memory/storage efficiency
3. Version-based delta system
4. Separate metadata plists (future)
5. Album catalog support (future)

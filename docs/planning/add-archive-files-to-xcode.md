# Adding Archive UX Files to Xcode

## Files to Add

Please add the following new files to the Xcode project:

### Models Group
1. **ArchiveStatus.swift** - Archive status enum and related types
   - Path: `Photolala/Models/ArchiveStatus.swift`

### Views Group  
2. **PhotoArchiveBadge.swift** - Badge overlay for archived photos
   - Path: `Photolala/Views/PhotoArchiveBadge.swift`
   
3. **PhotoRetrievalView.swift** - Modal dialog for photo retrieval
   - Path: `Photolala/Views/PhotoRetrievalView.swift`

### Services Group
4. **S3RetrievalManager.swift** - Manages photo retrieval requests
   - Path: `Photolala/Services/S3RetrievalManager.swift`

## How to Add Files in Xcode

1. Open the Photolala project in Xcode
2. Right-click on the appropriate group (Models, Views, or Services)
3. Select "Add Files to 'Photolala'..."
4. Navigate to the file and select it
5. Ensure "Copy items if needed" is unchecked (files are already in place)
6. Ensure the Photolala target is selected
7. Click "Add"

## Verify Build

After adding all files, build the project to ensure everything compiles correctly:
- Command+B to build
- Fix any import issues if they arise

The project should build successfully as we've already verified compilation.
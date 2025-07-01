# Xcode Manual Steps Required

## Summary

After restructuring the project, the Xcode project file needs manual updates that can only be done within Xcode itself. The verification script shows the project structure is correct, but file references need updating.

## Required Manual Steps

### 1. Open Xcode Project
```bash
cd /path/to/Photolala/apple
open Photolala.xcodeproj
```

### 2. Fix Red (Missing) References
You will likely see red files for:
- TestPhotos (moved to ../shared/TestPhotos)
- Possibly some source files if paths changed

For each red file:
1. Select it in the navigator
2. Delete (Remove Reference only)
3. Re-add from new location

### 3. Re-add TestPhotos
1. Right-click project → Add Files to "Photolala"
2. Navigate to ../shared/TestPhotos
3. Add with "Create groups" selected

### 4. Verify Build
1. Clean Build Folder (⇧⌘K)
2. Build for macOS (⌘B)
3. If successful, test iOS and tvOS builds

## Why Manual Steps?

The Xcode project file (.pbxproj) uses unique identifiers for each file reference. When files move, these references break and must be updated through Xcode's UI to maintain the proper relationships and identifiers.

## Verification

After completing the manual steps:
```bash
./scripts/apple/verify-xcode-project.sh
```

All checks should pass, including the build configuration tests.

## Commit the Fixed Project

Once everything is working:
```bash
cd apple
git add Photolala.xcodeproj/project.pbxproj
git commit -m "fix: Update Xcode project references after restructuring"
```

This is a one-time fix that needs to be done after the restructuring.
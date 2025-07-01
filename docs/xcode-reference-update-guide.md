# Xcode Project Reference Update Guide

## Overview

After restructuring the project to move Apple code to the `apple/` directory, Xcode project references need to be updated. This guide provides step-by-step instructions to fix all references.

## Prerequisites

- Xcode installed (version 15.0+)
- Git repository with restructuring changes committed
- Backup of the project (in case something goes wrong)

## Step 1: Open the Project

```bash
cd /path/to/Photolala/apple
open Photolala.xcodeproj
```

## Step 2: Fix Missing File References

### 2.1 Identify Missing Files

Missing files will appear in RED in the Xcode navigator. Common issues:
- TestPhotos folder (moved to shared/)
- Any files that were moved during restructuring

### 2.2 Remove Red References

1. Select each red file/folder in the navigator
2. Press Delete key
3. Choose "Remove Reference" (not "Move to Trash")

## Step 3: Re-add Shared Resources

### 3.1 Add TestPhotos Folder

1. Right-click on the project in navigator
2. Select "Add Files to Photolala..."
3. Navigate to `../shared/TestPhotos`
4. Select the TestPhotos folder
5. Options:
   - ✅ Create groups
   - ✅ Add to targets: Photolala (all platforms)
6. Click "Add"

### 3.2 Update Help Files References

If Help files show as missing:
1. Navigate to Photolala → Help in the navigator
2. If red, remove and re-add from correct location

## Step 4: Update Build Settings

### 4.1 Update Info.plist Path

1. Select the project in navigator
2. Select "Photolala" target
3. Go to "Build Settings" tab
4. Search for "Info.plist"
5. Update path if needed (should be relative to project)

### 4.2 Update Entitlements Path

1. Search for "entitlements" in Build Settings
2. Verify path is correct: `Photolala/photolala.entitlements`

## Step 5: Update Resource References

### 5.1 Verify Assets.xcassets

1. Navigate to Photolala → Assets.xcassets
2. Ensure it's not showing as missing
3. Check that app icons are properly loaded

### 5.2 Update Bundle Resources

1. Select project → Target → Build Phases
2. Expand "Copy Bundle Resources"
3. Remove any red/missing items
4. Add back if needed using "+" button

## Step 6: Fix Source File References

### 6.1 Verify All Swift Files

1. Check each group in the navigator
2. Ensure no Swift files are showing as red
3. If any are missing, remove and re-add

### 6.2 Update File Locations

For any files showing wrong location:
1. Select the file
2. Open File Inspector (right panel)
3. Click folder icon next to "Location"
4. Navigate to correct location
5. Choose "Relative to Group"

## Step 7: Update Schemes

### 7.1 Check Scheme Settings

1. Click scheme selector → Edit Scheme
2. Verify executable is set correctly
3. Check that build targets are correct

### 7.2 Update Test Targets

1. Select Test section in scheme
2. Verify test bundles are found
3. Re-add if showing as missing

## Step 8: Test the Build

### 8.1 Clean Build Folder

```bash
# In Xcode
Product → Clean Build Folder (⇧⌘K)

# Or from command line
cd apple
xcodebuild clean
```

### 8.2 Build for Each Platform

Test that builds work for all platforms:

```bash
# macOS
xcodebuild -scheme Photolala -destination 'platform=macOS' build

# iOS Simulator
xcodebuild -scheme Photolala -destination 'platform=iOS Simulator,name=iPhone 15' build

# tvOS Simulator
xcodebuild -scheme Photolala -destination 'platform=tvOS Simulator,name=Apple TV' build
```

## Step 9: Verify Tests

### 9.1 Run Unit Tests

```bash
xcodebuild -scheme Photolala test
```

### 9.2 Fix Test Bundle References

If tests fail to run:
1. Select test target in navigator
2. Build Phases → Link Binary With Libraries
3. Ensure app target is linked

## Common Issues and Solutions

### Issue: "Missing file" warnings

**Solution**: Remove reference and re-add from new location

### Issue: Build fails with "file not found"

**Solution**: Check Build Phases → Compile Sources, remove and re-add

### Issue: Resources not found at runtime

**Solution**: Verify Copy Bundle Resources phase includes all needed files

### Issue: Module import errors

**Solution**: Check that all frameworks are properly linked

## Verification Script

Create and run this script to verify the setup:

```bash
#!/bin/bash
# verify-xcode-setup.sh

echo "Verifying Xcode project setup..."

cd apple

# Check if project file exists
if [ ! -f "Photolala.xcodeproj/project.pbxproj" ]; then
    echo "❌ Project file not found"
    exit 1
fi

# Try to list schemes
echo "Available schemes:"
xcodebuild -list -project Photolala.xcodeproj

# Try a test build
echo "Testing macOS build..."
if xcodebuild -scheme Photolala -destination 'platform=macOS' -configuration Debug build > /dev/null 2>&1; then
    echo "✅ macOS build successful"
else
    echo "❌ macOS build failed"
fi

echo "Verification complete"
```

## Manual Verification Checklist

- [ ] Project opens without errors
- [ ] No red (missing) files in navigator  
- [ ] TestPhotos folder is accessible
- [ ] All Swift files compile
- [ ] Assets.xcassets loads properly
- [ ] App builds for macOS
- [ ] App builds for iOS
- [ ] App builds for tvOS
- [ ] Tests run successfully
- [ ] App runs in simulator/device

## Tips

1. **Use Relative Paths**: Always use "Relative to Group" for file locations
2. **Commit After Fixing**: Commit the project file after fixing references
3. **Test on Clean Clone**: Clone the repo in a new location to verify everything works

## Next Steps

After updating references:
1. Commit the updated project file
2. Test on a fresh clone
3. Update CI/CD scripts if needed
4. Notify team members to pull latest changes

## Troubleshooting

If you encounter issues not covered here:
1. Check Xcode's Issue Navigator for specific errors
2. Verify file permissions in Finder
3. Try resetting Xcode's derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
# Android Backup Service Testing Guide

## Current Status
- Emulator running: emulator-5554 (Pixel Tablet)
- Build has errors due to missing Timber and MD5Utils dependencies

## Quick Test Setup

Since the full app won't build, you can test the backup service with these steps:

### 1. Manual Testing via ADB Shell

```bash
# Check if backup is enabled on emulator
adb -s emulator-5554 shell bmgr enabled

# If not enabled, enable it
adb -s emulator-5554 shell bmgr enable true

# Check backup transport (should show Google)
adb -s emulator-5554 shell bmgr list transports
```

### 2. Test SharedPreferences Directly

```bash
# Create test preferences file
adb -s emulator-5554 shell "echo '<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\" ?><map><string name=\"md5#test123\">1,3,5</string><string name=\"md5#test456\">2,4</string></map>' > /data/data/com.electricwoods.photolala/shared_prefs/photo_tags_backup.xml"

# Trigger backup
adb -s emulator-5554 shell bmgr backup com.electricwoods.photolala
adb -s emulator-5554 shell bmgr run

# Check backup status
adb -s emulator-5554 shell dumpsys backup | grep -A 10 photolala
```

### 3. For Full Testing

We need to fix these build issues first:
1. Add Timber dependency
2. Add MD5Utils class
3. Fix other compilation errors

Or create a minimal test app with just the backup functionality.

## Next Steps
1. Fix build errors
2. Install app on emulator
3. Test tag backup/restore functionality
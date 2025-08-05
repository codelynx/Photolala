#!/bin/bash

# Script to push sample photos to Android emulator/device

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "Error: adb command not found. Please ensure Android SDK is installed and in PATH."
    exit 1
fi

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "Error: No Android device/emulator found. Please start an emulator or connect a device."
    exit 1
fi

echo "Pushing sample photos to Android device..."

# Create Pictures directory if it doesn't exist
adb shell mkdir -p /sdcard/Pictures/Photolala

# Push all photos
PHOTOS_DIR="/Users/kyoshikawa/Projects/Photolala/shared/TestPhotos"
for photo in "$PHOTOS_DIR"/*.jpg; do
    if [ -f "$photo" ]; then
        echo "Pushing $(basename "$photo")..."
        adb push "$photo" /sdcard/Pictures/Photolala/
    fi
done

# Also push the sunflower image
SUNFLOWER="/Users/kyoshikawa/Projects/Photolala/shared/assets/sunflower_image.png"
if [ -f "$SUNFLOWER" ]; then
    echo "Pushing sunflower_image.png..."
    adb push "$SUNFLOWER" /sdcard/Pictures/Photolala/
fi

# Trigger media scan to make photos visible immediately
echo "Triggering media scan..."
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/Photolala/

echo "Done! Photos should now be visible in the Photolala app."
echo "You may need to grant storage permissions and refresh the app."
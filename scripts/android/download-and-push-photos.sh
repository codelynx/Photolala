#!/bin/bash

# Download sample photos and automatically push to Android emulator
# One-step solution for getting test photos into the emulator

COUNT="${1:-20}"
TEMP_DIR="./temp-photos"

echo "=== Photo Loader for Android Emulator ==="
echo "This script will:"
echo "1. Download $COUNT sample photos from Unsplash"
echo "2. Push them to your Android emulator"
echo "3. Trigger media scan so they appear in apps"
echo ""

# Check if emulator is running
if ! adb devices | grep -q "emulator"; then
    echo "❌ Error: No Android emulator detected!"
    echo "Please start an emulator first."
    exit 1
fi

echo "✅ Emulator detected"
echo ""

# Step 1: Download photos
echo "📥 Downloading $COUNT photos..."
mkdir -p "$TEMP_DIR"

CATEGORIES=("nature" "people" "technology" "architecture" "food" "animals" "travel" "city" "abstract")

for i in $(seq 1 $COUNT); do
    CATEGORY=${CATEGORIES[$RANDOM % ${#CATEGORIES[@]}]}
    SIZE="1024x768"  # Larger size for better quality
    
    FILENAME="photo_${CATEGORY}_$(date +%Y%m%d)_$(printf "%03d" $i).jpg"
    
    echo -n "  Downloading $i/$COUNT ($CATEGORY)... "
    if curl -L -s "https://source.unsplash.com/${SIZE}/?${CATEGORY}" -o "$TEMP_DIR/$FILENAME"; then
        echo "✓"
    else
        echo "✗"
    fi
    
    # Small delay to be nice to Unsplash
    sleep 0.5
done

echo ""
echo "📤 Pushing photos to emulator..."

# Step 2: Push to multiple directories for better compatibility
for dir in "Pictures" "Download" "DCIM"; do
    echo -n "  Pushing to /sdcard/$dir/... "
    if adb push "$TEMP_DIR"/* "/sdcard/$dir/" >/dev/null 2>&1; then
        echo "✓"
    else
        echo "✗"
    fi
done

# Step 3: Trigger media scan
echo ""
echo "🔄 Triggering media scan..."
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file:///sdcard/Pictures/" >/dev/null 2>&1
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file:///sdcard/Download/" >/dev/null 2>&1
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file:///sdcard/DCIM/" >/dev/null 2>&1

# Step 4: Clean up
echo ""
echo "🧹 Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Done! $COUNT photos have been added to your emulator."
echo ""
echo "📱 To see them in Photolala:"
echo "   1. Open or restart the Photolala app"
echo "   2. Pull down to refresh if needed"
echo "   3. Grant photo permissions if prompted"
echo ""
echo "💡 Tip: Photos were added to multiple directories:"
echo "   - /sdcard/Pictures/"
echo "   - /sdcard/Download/"
echo "   - /sdcard/DCIM/"
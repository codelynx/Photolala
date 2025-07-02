#!/bin/bash

# Development script to delete photos from emulator
# This is a workaround for Android 11+ restrictions

echo "🗑️  Delete Photos from Emulator (Development Only)"
echo "================================================"

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "❌ adb command not found. Please install Android SDK."
    exit 1
fi

# Function to delete photos by pattern
delete_photos() {
    local pattern=$1
    echo "Deleting photos matching: $pattern"
    
    # Delete from Pictures directory
    adb shell "rm -f /sdcard/Pictures/$pattern"
    adb shell "rm -f /sdcard/DCIM/$pattern"
    adb shell "rm -f /sdcard/Download/$pattern"
    
    # Force MediaStore rescan
    adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/
}

# Main menu
echo ""
echo "Choose delete option:"
echo "1) Delete all test photos (unsplash_*.jpg)"
echo "2) Delete ALL photos (⚠️  DANGEROUS)"
echo "3) Delete photos by pattern"
echo "4) Exit"
echo ""
read -p "Select option (1-4): " choice

case $choice in
    1)
        delete_photos "unsplash_*.jpg"
        echo "✅ Test photos deleted"
        ;;
    2)
        read -p "⚠️  This will delete ALL photos! Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            delete_photos "*.jpg"
            delete_photos "*.jpeg"
            delete_photos "*.png"
            echo "✅ All photos deleted"
        else
            echo "❌ Cancelled"
        fi
        ;;
    3)
        read -p "Enter pattern (e.g., *.jpg, photo_*.png): " pattern
        delete_photos "$pattern"
        echo "✅ Photos matching '$pattern' deleted"
        ;;
    4)
        echo "👋 Exiting"
        exit 0
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "📱 Refreshing MediaStore..."
adb shell am broadcast -a android.intent.action.MEDIA_MOUNTED -d file:///sdcard

echo "✅ Done! Open the app to see changes."
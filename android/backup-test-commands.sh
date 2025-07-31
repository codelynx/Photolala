#!/bin/bash

# Backup Testing Commands for Photolala Android

echo "=== Photolala Tag Backup Testing ==="
echo ""
echo "Since the app has build errors, you can test backup functionality using ADB directly:"
echo ""

# Function to show current tags in SharedPreferences
show_tags() {
    echo "Current tags in SharedPreferences:"
    adb -s emulator-5554 shell run-as com.electricwoods.photolala cat /data/data/com.electricwoods.photolala/shared_prefs/photo_tags_backup.xml
}

# Function to manually add test tags
add_test_tags() {
    echo "Adding test tags..."
    adb -s emulator-5554 shell "run-as com.electricwoods.photolala sh -c 'echo \"<?xml version=\\\"1.0\\\" encoding=\\\"utf-8\\\" standalone=\\\"yes\\\" ?><map><string name=\\\"md5#test123\\\">1,3,5</string><string name=\\\"md5#test456\\\">2,4</string><string name=\\\"md5#test789\\\">1,2,3,4,5,6,7</string></map>\" > /data/data/com.electricwoods.photolala/shared_prefs/photo_tags_backup.xml'"
    echo "Added 3 test photos with tags"
}

# Function to trigger backup
trigger_backup() {
    echo "Triggering backup..."
    adb -s emulator-5554 shell bmgr backup com.electricwoods.photolala
    adb -s emulator-5554 shell bmgr run
    echo "Backup triggered"
}

# Function to check backup status
check_backup() {
    echo "Checking backup status..."
    adb -s emulator-5554 shell dumpsys backup | grep -A 5 photolala
}

# Menu
echo "Choose an option:"
echo "1. Show current tags"
echo "2. Add test tags"
echo "3. Trigger backup"
echo "4. Check backup status"
echo "5. Run full test (add tags, backup, check)"
echo ""

read -p "Enter choice (1-5): " choice

case $choice in
    1) show_tags ;;
    2) add_test_tags ;;
    3) trigger_backup ;;
    4) check_backup ;;
    5) 
        add_test_tags
        echo ""
        show_tags
        echo ""
        trigger_backup
        echo ""
        check_backup
        ;;
    *) echo "Invalid choice" ;;
esac
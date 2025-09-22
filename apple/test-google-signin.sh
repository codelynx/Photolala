#!/bin/bash

echo "Starting Photolala and monitoring logs..."
echo "==========================================="
echo "Click 'Sign in with Google' in the app"
echo "==========================================="

# Run the app and capture output
APP_PATH="/Users/kyoshikawa/Library/Developer/Xcode/DerivedData/Photolala-coeotqsgxyecglahdaevifhxiajm/Build/Products/Debug/Photolala.app"

# Kill any existing instance
pkill -f Photolala.app || true

# Run the app with output to console
"$APP_PATH/Contents/MacOS/Photolala" 2>&1 | while IFS= read -r line; do
    echo "[$(date '+%H:%M:%S')] $line"
done
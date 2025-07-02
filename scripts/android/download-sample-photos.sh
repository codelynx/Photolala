#!/bin/bash

# Download sample photos from Unsplash for testing
# Uses Unsplash Source API for random photos

OUTPUT_DIR="${1:-./sample-photos}"
COUNT="${2:-20}"

echo "Downloading $COUNT sample photos from Unsplash..."
mkdir -p "$OUTPUT_DIR"

# Categories for variety
CATEGORIES=("nature" "people" "technology" "architecture" "food" "animals" "travel" "business")

for i in $(seq 1 $COUNT); do
    CATEGORY=${CATEGORIES[$RANDOM % ${#CATEGORIES[@]}]}
    SIZE="800x600"
    
    # Generate filename
    FILENAME="unsplash_${CATEGORY}_$(printf "%03d" $i).jpg"
    
    # Download from Unsplash
    echo "Downloading $FILENAME ($CATEGORY)..."
    curl -L -s "https://source.unsplash.com/${SIZE}/?${CATEGORY}" -o "$OUTPUT_DIR/$FILENAME"
    
    # Small delay to avoid rate limiting
    sleep 1
done

echo "Downloaded $COUNT photos to $OUTPUT_DIR"
echo ""
echo "To push to Android emulator:"
echo "  adb push $OUTPUT_DIR/* /sdcard/Pictures/"
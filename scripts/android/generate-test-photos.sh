#!/bin/bash

# Generate test photos for Android emulator
# Creates colorful test images with different sizes and metadata

OUTPUT_DIR="${1:-./test-photos}"
COUNT="${2:-20}"

echo "Generating $COUNT test photos in $OUTPUT_DIR..."
mkdir -p "$OUTPUT_DIR"

# Array of colors for variety
COLORS=("red" "blue" "green" "yellow" "purple" "orange" "pink" "cyan" "magenta" "brown")
SIZES=("800x600" "1024x768" "1920x1080" "3840x2160" "600x800" "768x1024")

for i in $(seq 1 $COUNT); do
    # Random color and size
    COLOR=${COLORS[$RANDOM % ${#COLORS[@]}]}
    SIZE=${SIZES[$RANDOM % ${#SIZES[@]}]}
    
    # Generate filename with date pattern
    YEAR=$((2020 + $RANDOM % 5))
    MONTH=$(printf "%02d" $((1 + $RANDOM % 12)))
    DAY=$(printf "%02d" $((1 + $RANDOM % 28)))
    
    FILENAME="IMG_${YEAR}${MONTH}${DAY}_$(printf "%03d" $i).jpg"
    
    # Create image using ImageMagick (if available) or use placeholder
    if command -v convert &> /dev/null; then
        # Create image with text overlay
        convert -size $SIZE xc:$COLOR \
            -gravity center \
            -pointsize 48 \
            -fill white \
            -annotate +0+0 "Photo $i\n$SIZE\n$YEAR-$MONTH-$DAY" \
            "$OUTPUT_DIR/$FILENAME"
    else
        # Create placeholder if ImageMagick not available
        echo "Photo $i ($SIZE) - $COLOR - $YEAR-$MONTH-$DAY" > "$OUTPUT_DIR/$FILENAME.txt"
    fi
    
    echo "Created: $FILENAME"
done

echo "Generated $COUNT test photos in $OUTPUT_DIR"
echo ""
echo "To push to Android emulator:"
echo "  adb push $OUTPUT_DIR/* /sdcard/Pictures/"
echo "  adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/"
#!/bin/bash

# Script to generate Android app icons from a new sunflower image

# Check if source image path is provided as argument
if [ -z "$1" ]; then
    # Use default path if no argument provided
    SOURCE_IMAGE="../android/artwork/sunflower.png"
    echo "Using default image: $SOURCE_IMAGE"
else
    SOURCE_IMAGE="$1"
fi
ANDROID_RES_DIR="../android/app/src/main/res"

# Change to scripts directory
cd "$(dirname "$0")"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: Source image not found at $SOURCE_IMAGE"
    exit 1
fi

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is not installed. Please install it first:"
    echo "  brew install imagemagick"
    exit 1
fi

echo "Generating Android app icons from new geometric sunflower image..."

# Create temporary directory for work
TEMP_DIR=$(mktemp -d)
echo "Working in $TEMP_DIR"

# Copy source image to temp
cp "$SOURCE_IMAGE" "$TEMP_DIR/source.png"

# Generate square icons for standard launcher
echo "Generating standard launcher icons..."
convert "$TEMP_DIR/source.png" -resize 48x48 "$ANDROID_RES_DIR/mipmap-mdpi/ic_launcher.png"
convert "$TEMP_DIR/source.png" -resize 72x72 "$ANDROID_RES_DIR/mipmap-hdpi/ic_launcher.png"
convert "$TEMP_DIR/source.png" -resize 96x96 "$ANDROID_RES_DIR/mipmap-xhdpi/ic_launcher.png"
convert "$TEMP_DIR/source.png" -resize 144x144 "$ANDROID_RES_DIR/mipmap-xxhdpi/ic_launcher.png"
convert "$TEMP_DIR/source.png" -resize 192x192 "$ANDROID_RES_DIR/mipmap-xxxhdpi/ic_launcher.png"

# Generate round icons (with circular mask)
echo "Generating round launcher icons..."
for size in 48:mdpi 72:hdpi 96:xhdpi 144:xxhdpi 192:xxxhdpi; do
    dimensions="${size%:*}"
    density="${size#*:}"
    
    # Create circular mask
    convert -size ${dimensions}x${dimensions} xc:none -fill white -draw "circle $((dimensions/2)),$((dimensions/2)) $((dimensions/2)),0" "$TEMP_DIR/mask.png"
    
    # Apply circular mask to resized image
    convert "$TEMP_DIR/source.png" -resize ${dimensions}x${dimensions} "$TEMP_DIR/mask.png" -alpha off -compose copy_opacity -composite "$ANDROID_RES_DIR/mipmap-$density/ic_launcher_round.png"
done

# Generate adaptive icon layers (for Android 8.0+)
echo "Generating adaptive icon layers..."

# Create foreground with padding
# The geometric sunflower already has good composition, so we'll use 72% to keep it prominent
for size in 108:mdpi 162:hdpi 216:xhdpi 324:xxhdpi 432:xxxhdpi; do
    dimensions="${size%:*}"
    density="${size#*:}"
    # Use 72% for this geometric design as it doesn't have protruding petals
    inner_size=$((dimensions * 72 / 100))
    
    # Create foreground with transparent padding
    convert "$TEMP_DIR/source.png" -resize ${inner_size}x${inner_size} -gravity center -background none -extent ${dimensions}x${dimensions} "$ANDROID_RES_DIR/mipmap-$density/ic_launcher_foreground.png"
done

# Generate web icon for Play Store (512x512)
echo "Generating Play Store icon..."
mkdir -p "$ANDROID_RES_DIR/../../../ic_launcher-playstore"
convert "$TEMP_DIR/source.png" -resize 512x512 "$ANDROID_RES_DIR/../../../ic_launcher-playstore.png"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Remove old .webp files
echo "Removing old .webp icons..."
find "$ANDROID_RES_DIR" -name "ic_launcher*.webp" -delete

# Update adaptive icon XML files to use PNG foreground
echo "Updating adaptive icon XML files..."

# Update ic_launcher.xml
cat > "$ANDROID_RES_DIR/mipmap-anydpi/ic_launcher.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
EOF

# Update ic_launcher_round.xml
cat > "$ANDROID_RES_DIR/mipmap-anydpi/ic_launcher_round.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
EOF

# Create a background that matches the image's blue color
# The geometric sunflower has a nice blue background (#4A90E2 approximate)
cat > "$ANDROID_RES_DIR/drawable/ic_launcher_background.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#4A90E2"
        android:pathData="M0,0h108v108h-108z" />
</vector>
EOF

echo "Done! Android app icons have been generated with the geometric sunflower design."
echo ""
echo "Icons generated:"
echo "- Standard square icons (ic_launcher.png) in all densities"
echo "- Round icons (ic_launcher_round.png) in all densities"
echo "- Adaptive icon foreground layers (ic_launcher_foreground.png)"
echo "- Play Store icon (512x512)"
echo "- Blue background matching the geometric design"
echo ""
echo "Please rebuild your Android app to see the new icons."
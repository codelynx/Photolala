#!/bin/bash
# Create test photos with different creation dates for testing grouping feature

cd TestPhotos

# Create some placeholder images using sips (macOS built-in tool)
# We'll create small colored squares as test images

# Photos from 2023
echo "Creating 2023 photos..."
for i in {1..3}; do
    # Create a colored image
    convert -size 100x100 xc:"#$(openssl rand -hex 3)" "photo_2023_$i.jpg" 2>/dev/null || \
    sips -z 100 100 -s format jpeg /System/Library/Desktop\ Pictures/Solid\ Colors/Blue\ Violet.png --out "photo_2023_$i.jpg" 2>/dev/null || \
    echo "Placeholder for photo_2023_$i.jpg" > "photo_2023_$i.txt"
    
    # Set creation date to sometime in 2023
    touch -t 202306$(printf "%02d" $((10 + $i)))1200 "photo_2023_$i."*
done

# Photos from January 2024
echo "Creating January 2024 photos..."
for i in {1..3}; do
    convert -size 100x100 xc:"#$(openssl rand -hex 3)" "photo_2024_jan_$i.jpg" 2>/dev/null || \
    sips -z 100 100 -s format jpeg /System/Library/Desktop\ Pictures/Solid\ Colors/Teal.png --out "photo_2024_jan_$i.jpg" 2>/dev/null || \
    echo "Placeholder for photo_2024_jan_$i.jpg" > "photo_2024_jan_$i.txt"
    
    # Set creation date to January 2024
    touch -t 202401$(printf "%02d" $((10 + $i)))1200 "photo_2024_jan_$i."*
done

# Photos from March 2024
echo "Creating March 2024 photos..."
for i in {1..4}; do
    convert -size 100x100 xc:"#$(openssl rand -hex 3)" "photo_2024_mar_$i.jpg" 2>/dev/null || \
    sips -z 100 100 -s format jpeg /System/Library/Desktop\ Pictures/Solid\ Colors/Turquoise\ Green.png --out "photo_2024_mar_$i.jpg" 2>/dev/null || \
    echo "Placeholder for photo_2024_mar_$i.jpg" > "photo_2024_mar_$i.txt"
    
    # Set creation date to March 2024
    touch -t 202403$(printf "%02d" $((10 + $i)))1200 "photo_2024_mar_$i."*
done

# Photos from June 2025 (recent)
echo "Creating June 2025 photos..."
for i in {1..2}; do
    convert -size 100x100 xc:"#$(openssl rand -hex 3)" "photo_2025_jun_$i.jpg" 2>/dev/null || \
    sips -z 100 100 -s format jpeg /System/Library/Desktop\ Pictures/Solid\ Colors/Silver.png --out "photo_2025_jun_$i.jpg" 2>/dev/null || \
    echo "Placeholder for photo_2025_jun_$i.jpg" > "photo_2025_jun_$i.txt"
    
    # Set creation date to June 2025
    touch -t 202506$(printf "%02d" $((10 + $i)))1200 "photo_2025_jun_$i."*
done

echo "Test photos created!"
ls -la
#!/bin/bash

# Script to add XPlatform import to Swift files that use XPlatform types
# This helps make the dependency explicit after switching to the XPlatform package

# Files that use XPlatform types
files=(
    "Photolala/Views/UnifiedPhotoCollectionViewController.swift"
    "Photolala/Views/AuthenticationChoiceView.swift"
    "Photolala/Views/SignInPromptView.swift"
    "Photolala/Views/DirectoryPhotoBrowserView.swift"
    "Photolala/Views/UnifiedPhotoCell.swift"
    "Photolala/Views/UnifiedPhotoCollectionViewRepresentable.swift"
    "Photolala/Views/ThumbnailStrip/ThumbnailStripViewController.swift"
    "Photolala/Views/ThumbnailStrip/ThumbnailStripView.swift"
    "Photolala/Views/S3PhotoThumbnailView.swift"
    "Photolala/Views/S3PhotoDetailView.swift"
    "Photolala/Views/PhotoRetrievalView.swift"
    "Photolala/Views/PhotoPreviewView.swift"
    "Photolala/Views/PhotoCollectionViewController.swift"
    "Photolala/Views/InspectorView.swift"
    "Photolala/Views/ComingSoonBadge.swift"
    "Photolala/Views/BackupStatusBar.swift"
    "Photolala/Services/S3DownloadService.swift"
    "Photolala/Services/PhotoProcessor.swift"
    "Photolala/Services/PhotoManager.swift"
    "Photolala/Models/PhotoItem.swift"
    "Photolala/Models/PhotoFile.swift"
    "Photolala/Models/PhotoApple.swift"
)

echo "Adding XPlatform imports to Swift files..."

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        # Check if import XPlatform already exists
        if ! grep -q "^import XPlatform" "$file"; then
            echo "Processing $file..."
            
            # Find the last import statement and add XPlatform after it
            # This preserves the import ordering
            awk '
                /^import/ { imports = imports $0 "\n"; last_import = NR; next }
                { 
                    if (NR == last_import + 1 && imports != "") {
                        print imports "import XPlatform"
                        imports = ""
                    }
                    print
                }
                END {
                    if (imports != "") {
                        print imports "import XPlatform"
                    }
                }
            ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
            
            echo "✓ Added import to $file"
        else
            echo "⏭️  Skipping $file (already has import)"
        fi
    else
        echo "⚠️  Warning: $file not found"
    fi
done

echo "Done! Remember to:"
echo "1. Add the XPlatform package dependency in Xcode"
echo "2. Build the project to verify everything works"
echo "3. Delete Photolala/Utilities/XPlatform.swift"
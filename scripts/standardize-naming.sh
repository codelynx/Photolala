#!/bin/bash

# Standardize naming to "Photolala" (capital P) where safe
# DO NOT change bundle identifiers as that would break existing installations

echo "🔧 Standardizing naming to 'Photolala' (capital P)..."
echo ""

# Define project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# 1. Rename scheme file if needed
echo "📋 Checking scheme naming..."
if [ -f "Photolala.xcodeproj/xcshareddata/xcschemes/photolala.xcscheme" ]; then
    echo "  Renaming scheme from 'photolala' to 'Photolala'..."
    mv "Photolala.xcodeproj/xcshareddata/xcschemes/photolala.xcscheme" \
       "Photolala.xcodeproj/xcshareddata/xcschemes/Photolala.xcscheme"
    
    # Update scheme name inside the file
    sed -i '' 's/BuildableName = "photolala.app"/BuildableName = "Photolala.app"/g' \
        "Photolala.xcodeproj/xcshareddata/xcschemes/Photolala.xcscheme"
    sed -i '' 's/BlueprintName = "photolala"/BlueprintName = "Photolala"/g' \
        "Photolala.xcodeproj/xcshareddata/xcschemes/Photolala.xcscheme"
fi

# 2. Update project file references (careful not to break anything)
echo "📁 Updating project file references..."
# Update PRODUCT_NAME where it's lowercase
sed -i '' 's/PRODUCT_NAME = photolala;/PRODUCT_NAME = Photolala;/g' \
    "Photolala.xcodeproj/project.pbxproj"

# 3. Find and update string literals in Swift files
echo "📝 Updating string literals in Swift files..."

# Update cache/storage paths
find . -name "*.swift" -type f -not -path "./build*" -not -path "./.build/*" | while read file; do
    # Update paths that use "photolala" to "Photolala"
    sed -i '' 's|/photolala/|/Photolala/|g' "$file"
    sed -i '' 's|"photolala"|"Photolala"|g' "$file"
    
    # But preserve bundle identifier
    sed -i '' 's|com.electricwoods.Photolala|com.electricwoods.photolala|g' "$file"
done

# 4. Update bucket names and service identifiers
echo "☁️  Updating S3 bucket references..."
find . -name "*.swift" -type f -not -path "./build*" -not -path "./.build/*" | while read file; do
    # This is lowercase by convention for S3
    sed -i '' 's|Photolala-photos|photolala-photos|g' "$file"
done

# 5. Update documentation
echo "📚 Updating documentation..."
find ./docs -name "*.md" -type f | while read file; do
    # Standardize to Photolala in docs, but keep technical identifiers lowercase
    sed -i '' 's|photolala.app|Photolala.app|g' "$file"
    sed -i '' 's|photolala.xcscheme|Photolala.xcscheme|g' "$file"
    # Keep bundle ID lowercase
    sed -i '' 's|com.electricwoods.Photolala|com.electricwoods.photolala|g' "$file"
done

# 6. Report what should NOT be changed
echo ""
echo "⚠️  The following should remain unchanged:"
echo "  • Bundle ID: com.electricwoods.photolala (lowercase)"
echo "  • S3 bucket: photolala-photos (lowercase)" 
echo "  • iCloud container: iCloud.com.electricwoods.photolala (lowercase)"
echo ""

# 7. Show what was found
echo "📊 Summary of naming usage:"
echo ""
echo "Lowercase 'photolala' found in:"
grep -r "photolala" . --include="*.swift" --include="*.md" --exclude-dir=".build" --exclude-dir="build*" | grep -v "com.electricwoods.photolala" | grep -v "photolala-photos" | head -10

echo ""
echo "✅ Done! Please review changes and test the build."
echo ""
echo "💡 Recommended next steps:"
echo "1. Open Xcode and check the scheme still works"
echo "2. Clean build folder (Shift+Cmd+K)"
echo "3. Build and run to verify"
echo "4. Commit these changes"
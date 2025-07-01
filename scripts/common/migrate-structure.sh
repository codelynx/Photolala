#!/bin/bash

# Photolala Project Restructuring Script
# This script helps migrate the project to the new multi-platform structure

set -e

echo "Photolala Project Restructuring"
echo "==============================="
echo ""

# Check if we're in the right directory
if [ ! -f "Photolala.xcodeproj/project.pbxproj" ]; then
    echo "Error: This script must be run from the Photolala project root directory"
    exit 1
fi

# Function to confirm action
confirm() {
    read -p "$1 [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
    return 0
}

echo "This script will reorganize the project structure for multi-platform support."
echo "It will move files using 'git mv' to preserve history."
echo ""
echo "Current structure:"
echo "  - Swift code, tests, and Xcode project in root"
echo "  - Photos in root directory"
echo ""
echo "New structure:"
echo "  - Apple code → apple/"
echo "  - Android code → android/"
echo "  - Shared resources → shared/"
echo ""

if ! confirm "Do you want to proceed?"; then
    echo "Migration cancelled."
    exit 0
fi

echo ""
echo "Phase 1: Creating directory structure..."
echo "----------------------------------------"

# This should already exist from our previous commands
echo "✓ Directory structure already created"

echo ""
echo "Phase 2: Moving Apple-specific files..."
echo "----------------------------------------"

if confirm "Move Apple platform files to apple/ directory?"; then
    echo "Moving Swift sources..."
    git mv Photolala apple/
    
    echo "Moving test targets..."
    git mv PhotolalaTests apple/
    git mv PhotolalaUITests apple/
    
    echo "Moving Xcode project..."
    git mv Photolala.xcodeproj apple/
    
    echo "✓ Apple files moved successfully"
else
    echo "⚠️  Skipped moving Apple files"
fi

echo ""
echo "Phase 3: Moving shared resources..."
echo "------------------------------------"

if confirm "Move TestPhotos to shared/ directory?"; then
    echo "Moving TestPhotos folder..."
    git mv TestPhotos shared/
    
    echo "✓ Shared resources moved successfully"
else
    echo "⚠️  Skipped moving shared resources"
fi

echo ""
echo "Phase 4: Moving scripts..."
echo "--------------------------"

if confirm "Reorganize scripts by platform?"; then
    if [ -f "scripts/fix-tabs.sh" ]; then
        echo "Moving fix-tabs.sh to apple scripts..."
        git mv scripts/fix-tabs.sh scripts/apple/
    fi
    
    echo "✓ Scripts reorganized successfully"
else
    echo "⚠️  Skipped script reorganization"
fi

echo ""
echo "Phase 5: Updating configuration..."
echo "-----------------------------------"

echo "Creating updated .gitignore..."
cat > .gitignore.new << 'EOF'
# macOS
.DS_Store

# Xcode
apple/build/
apple/DerivedData/
apple/*.xcodeproj/xcuserdata/
apple/*.xcodeproj/project.xcworkspace/xcuserdata/
apple/*.xcworkspace/xcuserdata/
apple/*.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist

# Swift Package Manager
apple/.build/
apple/Packages/
apple/*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/

# Android
android/.gradle/
android/build/
android/local.properties
android/captures/
android/.idea/
android/*.iml
android/app/build/
android/app/release/
android/app/debug/

# Shared
*.log
.env
.env.local

# IDE
.vscode/
!.vscode/settings.json
!.vscode/extensions.json
EOF

if confirm "Update .gitignore file?"; then
    mv .gitignore.new .gitignore
    echo "✓ Updated .gitignore"
else
    rm .gitignore.new
    echo "⚠️  Skipped .gitignore update"
fi

echo ""
echo "Migration Status"
echo "================"
echo ""
echo "✓ Directory structure created"
echo "✓ Platform README files created"

# Check what was actually moved
if [ -d "apple/Photolala" ]; then
    echo "✓ Apple code moved to apple/"
else
    echo "⚠️  Apple code still in root (run script again to complete)"
fi

if [ -d "shared/TestPhotos" ]; then
    echo "✓ Shared resources moved"
else
    echo "⚠️  Shared resources still in root"
fi

echo ""
echo "Next Steps:"
echo "1. Open apple/Photolala.xcodeproj in Xcode"
echo "2. Update file references for moved resources"
echo "3. Build and test to ensure everything works"
echo "4. Commit the changes"
echo ""
echo "To update Xcode references, you may need to:"
echo "- Remove red (missing) file references"
echo "- Re-add files from their new locations"
echo "- Update any hardcoded paths in build scripts"

echo ""
echo "Migration script complete!"
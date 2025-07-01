#!/bin/bash

# Verify Xcode Project After Restructuring
# This script checks that the Xcode project is properly configured after moving to apple/

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/../.."
APPLE_DIR="$PROJECT_ROOT/apple"

echo "==================================="
echo "Xcode Project Verification Script"
echo "==================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        ERRORS=$((ERRORS + 1))
    fi
}

ERRORS=0

# Check if we're in the right directory
if [ ! -d "$APPLE_DIR" ]; then
    echo -e "${RED}Error: apple/ directory not found${NC}"
    echo "Expected location: $APPLE_DIR"
    exit 1
fi

cd "$APPLE_DIR"

echo "Checking project structure..."
echo "-----------------------------"

# Check if project file exists
if [ -f "Photolala.xcodeproj/project.pbxproj" ]; then
    print_status 0 "Xcode project file found"
else
    print_status 1 "Xcode project file NOT found"
fi

# Check if source files exist
if [ -d "Photolala" ]; then
    print_status 0 "Source directory found"
    
    # Count Swift files
    SWIFT_COUNT=$(find Photolala -name "*.swift" | wc -l | tr -d ' ')
    echo "   Found $SWIFT_COUNT Swift files"
else
    print_status 1 "Source directory NOT found"
fi

# Check if test directories exist
if [ -d "photolalaTests" ]; then
    print_status 0 "Unit tests directory found"
else
    print_status 1 "Unit tests directory NOT found"
fi

if [ -d "photolalaUITests" ]; then
    print_status 0 "UI tests directory found"
else
    print_status 1 "UI tests directory NOT found"
fi

# Check shared resources
echo ""
echo "Checking shared resources..."
echo "----------------------------"

if [ -d "../shared/TestPhotos" ]; then
    print_status 0 "TestPhotos found in shared/"
    PHOTO_COUNT=$(find ../shared/TestPhotos -name "*.jpg" -o -name "*.png" | wc -l | tr -d ' ')
    echo "   Found $PHOTO_COUNT test photos"
else
    print_status 1 "TestPhotos NOT found in shared/"
fi

if [ -d "../shared/icons" ]; then
    print_status 0 "Icons found in shared/"
else
    print_status 1 "Icons NOT found in shared/"
fi

# Check if we can list Xcode schemes
echo ""
echo "Checking Xcode configuration..."
echo "--------------------------------"

if xcodebuild -list -project Photolala.xcodeproj > /dev/null 2>&1; then
    print_status 0 "Can read Xcode project"
    
    # List schemes
    echo ""
    echo "Available schemes:"
    xcodebuild -list -project Photolala.xcodeproj 2>/dev/null | grep -A10 "Schemes:" | grep -v "Schemes:" | sed 's/^/   /'
else
    print_status 1 "Cannot read Xcode project"
fi

# Try to build (dry run)
echo ""
echo "Testing build configuration..."
echo "-------------------------------"

# Test macOS build configuration
echo -n "Testing macOS build config... "
if xcodebuild -scheme Photolala -destination 'platform=macOS' -configuration Debug -dry-run > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Test iOS build configuration
echo -n "Testing iOS build config... "
if xcodebuild -scheme Photolala -destination 'platform=iOS Simulator,name=iPhone 15' -configuration Debug -dry-run > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}FAILED (might need to download simulator)${NC}"
fi

# Check for common issues in project file
echo ""
echo "Checking for common issues..."
echo "-----------------------------"

# Check for absolute paths (which should be avoided)
if grep -q "/Users/" Photolala.xcodeproj/project.pbxproj; then
    print_status 1 "Found absolute paths in project file (should use relative paths)"
    echo "   Run: grep '/Users/' Photolala.xcodeproj/project.pbxproj"
else
    print_status 0 "No absolute paths found"
fi

# Check for references to old structure
if grep -q "TestPhotos" Photolala.xcodeproj/project.pbxproj; then
    if grep -q "../shared/TestPhotos" Photolala.xcodeproj/project.pbxproj; then
        print_status 0 "TestPhotos references updated correctly"
    else
        print_status 1 "TestPhotos references may need updating"
    fi
fi

# Summary
echo ""
echo "==================================="
echo "Summary"
echo "==================================="

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All checks passed! ✅${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open apple/Photolala.xcodeproj in Xcode"
    echo "2. Build the project (⌘B)"
    echo "3. If you see red files, follow the guide in docs/xcode-reference-update-guide.md"
else
    echo -e "${RED}Found $ERRORS issues ❌${NC}"
    echo ""
    echo "Please:"
    echo "1. Open apple/Photolala.xcodeproj in Xcode"
    echo "2. Follow the guide in docs/xcode-reference-update-guide.md"
    echo "3. Fix any red (missing) file references"
    echo "4. Run this script again to verify"
fi

echo ""
echo "For detailed instructions, see: docs/xcode-reference-update-guide.md"

exit $ERRORS
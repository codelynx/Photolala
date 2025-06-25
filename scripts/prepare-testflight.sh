#!/bin/bash

# Prepare Photolala for TestFlight deployment
# This script helps check and prepare the build for TestFlight

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================="
echo "Photolala TestFlight Preparation"
echo "================================================="
echo ""

# Function to check status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
        return 0
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

# Check Xcode is available
echo "Checking build environment..."
which xcodebuild >/dev/null 2>&1
check_status $? "Xcode command line tools installed"

# Check for required files
echo -e "\nChecking project structure..."
[ -f "Photolala.xcodeproj/project.pbxproj" ] && check_status 0 "Xcode project found" || check_status 1 "Xcode project found"
[ -f "Photolala/PhotolalaProducts.storekit" ] && check_status 0 "StoreKit configuration found" || check_status 1 "StoreKit configuration found"
[ -f "Photolala/Services/IAPManager.swift" ] && check_status 0 "IAP Manager found" || check_status 1 "IAP Manager found"

# Check current version and build number
echo -e "\nCurrent version info:"
MARKETING_VERSION=$(xcodebuild -showBuildSettings -project Photolala.xcodeproj -scheme photolala | grep MARKETING_VERSION | head -1 | awk '{print $3}')
CURRENT_BUILD=$(xcodebuild -showBuildSettings -project Photolala.xcodeproj -scheme photolala | grep CURRENT_PROJECT_VERSION | head -1 | awk '{print $3}')
echo -e "${BLUE}Version:${NC} ${MARKETING_VERSION:-Not set}"
echo -e "${BLUE}Build:${NC} ${CURRENT_BUILD:-Not set}"

# Suggest next build number
if [ -n "$CURRENT_BUILD" ]; then
    NEXT_BUILD=$((CURRENT_BUILD + 1))
    echo -e "${YELLOW}Suggested next build:${NC} $NEXT_BUILD"
fi

# Check for required capabilities
echo -e "\nChecking entitlements..."
if [ -f "Photolala/photolala.entitlements" ]; then
    grep -q "com.apple.developer.in-app-payments" Photolala/photolala.entitlements && \
        check_status 0 "In-App Purchase capability" || \
        check_status 1 "In-App Purchase capability"
fi

# Check for AWS configuration
echo -e "\nChecking S3 configuration..."
grep -q "PHOTOLALA_BUCKET" Photolala/Services/S3BackupService.swift && \
    check_status 0 "S3 bucket configured" || \
    check_status 1 "S3 bucket configured"

# Provide TestFlight build instructions
echo -e "\n${YELLOW}=================================================${NC}"
echo -e "${YELLOW}TestFlight Build Instructions:${NC}"
echo -e "${YELLOW}=================================================${NC}"
echo ""
echo "1. Open Xcode and select the Photolala project"
echo ""
echo "2. Update version and build number:"
echo "   - Select Photolala target → General"
echo "   - Version: ${MARKETING_VERSION:-1.0.0}"
echo "   - Build: ${NEXT_BUILD:-1}"
echo ""
echo "3. Add Info.plist entries (in target settings):"
echo "   - ITSAppUsesNonExemptEncryption = NO"
echo "   - NSPhotoLibraryUsageDescription = \"Photolala needs access...\""
echo ""
echo "4. Configure signing:"
echo "   - Team: Your Apple Developer Team"
echo "   - Bundle ID: com.electricwoods.Photolala"
echo ""
echo "5. Create archive:"
echo "   - Select \"Any iOS Device (arm64)\""
echo "   - Product → Archive"
echo ""
echo "6. Upload to App Store Connect:"
echo "   - Window → Organizer"
echo "   - Select archive → Distribute App"
echo "   - App Store Connect → Upload"
echo ""

# Create TestFlight notes template
cat > testflight-notes.txt << 'EOF'
What's New in This Build:
- In-App Purchase subscriptions for backup service
- Photo backup to secure cloud storage
- Archive retrieval for older photos
- Storage quota management

Test Focus Areas:
1. Subscribe to different tiers (Starter, Essential, Plus, Family)
2. Test upgrade/downgrade between tiers
3. Upload photos and monitor storage usage
4. Test archive retrieval UI (if you have archived photos)
5. Verify subscription restoration after reinstall

Known Issues:
- Receipt validation is local only (server-side coming soon)
- Push notifications for retrieval completion not yet implemented
- Background uploads will be enabled in next build

How to Test Subscriptions:
1. Open Settings → Subscriptions
2. Choose your plan
3. Complete purchase with sandbox account
4. Verify features unlock

Please report any issues through TestFlight feedback.
EOF

echo -e "${GREEN}Created testflight-notes.txt${NC} - Use this for your build notes"
echo ""

# Warnings and reminders
echo -e "${RED}Important Reminders:${NC}"
echo "- Sign out of production App Store on test devices"
echo "- Use sandbox test accounts for purchases"
echo "- AWS credentials needed for S3 features (or disable for now)"
echo "- Family sharing requires additional configuration"
echo ""

echo -e "${BLUE}Optional: Quick Fixes Before Upload${NC}"
echo "1. Add loading indicators for long operations"
echo "2. Ensure all error messages are user-friendly"
echo "3. Add empty state messages where needed"
echo "4. Test airplane mode handling"
echo ""

echo "Ready to build? (y/n)"
read -p "" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${GREEN}Good luck with your TestFlight submission!${NC}"
    echo "Opening Xcode..."
    open Photolala.xcodeproj
else
    echo "Build preparation cancelled."
fi
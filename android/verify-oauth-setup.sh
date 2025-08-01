#!/bin/bash

echo "Verifying OAuth Setup for Photolala Android Debug Build"
echo "======================================================="
echo ""

# Check if google-services.json exists
if [ -f "app/google-services.json" ]; then
    echo "✓ google-services.json found"
    
    # Extract project info
    PROJECT_ID=$(grep '"project_id"' app/google-services.json | awk -F'"' '{print $4}')
    echo "  Project ID: $PROJECT_ID"
    
    # Check for oauth_client entries
    OAUTH_COUNT=$(grep -c '"client_id"' app/google-services.json)
    echo "  OAuth clients found: $OAUTH_COUNT"
    
    # Look for debug package name
    if grep -q "com.electricwoods.photolala.debug" app/google-services.json; then
        echo "✓ Debug package name found in configuration"
    else
        echo "✗ Debug package name NOT found - you may need to regenerate google-services.json"
    fi
else
    echo "✗ google-services.json NOT found in app/ directory"
    echo "  Please download it from Firebase Console or Google Cloud Console"
fi

echo ""
echo "Debug Build Configuration:"
echo "  Package name: com.electricwoods.photolala.debug"
echo "  SHA-1: 9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89"

echo ""
echo "Next steps:"
echo "1. Create OAuth client in Google Cloud Console"
echo "2. Download updated google-services.json"
echo "3. Place it in android/app/"
echo "4. Run './gradlew clean assembleDebug' to test"
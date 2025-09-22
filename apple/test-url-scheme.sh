#!/bin/bash

echo "Testing URL scheme handler..."
echo "Make sure Photolala is running first!"
echo ""

# Test URL with the exact scheme from Info.plist
URL="com.googleusercontent.apps.75309194504-g1a4hr3pc68301vuh21tibauh9ar1nkv://oauth2redirect?state=test123&code=testcode"

echo "Opening URL: $URL"
open "$URL"

echo ""
echo "Check the Photolala console for:"
echo "  [App] Received URL: ..."
echo "  [GoogleSignIn] Handling OAuth callback: ..."
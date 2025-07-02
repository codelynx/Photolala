#!/bin/bash

# Script to generate encrypted credentials for iOS and Android
# Usage: ./scripts/generate-credentials.sh

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

echo "🔐 Generating encrypted credentials for iOS and Android..."
echo ""

# Check if credential-code tool exists
if [ ! -f "$PROJECT_ROOT/.credential-code-tool/.build/release/credential-code" ]; then
    echo "❌ credential-code tool not found!"
    echo "   Building credential-code tool..."
    cd "$PROJECT_ROOT/.credential-code-tool"
    swift build -c release
    cd "$PROJECT_ROOT"
fi

# Check if credentials.json exists
if [ ! -f "$PROJECT_ROOT/.credential-code/credentials.json" ]; then
    echo "❌ Error: .credential-code/credentials.json not found!"
    echo "   Please create this file with your AWS credentials:"
    echo "   {"
    echo '     "credentials": {'
    echo '       "AWS_ACCESS_KEY_ID": "your-access-key",'
    echo '       "AWS_SECRET_ACCESS_KEY": "your-secret-key",'
    echo '       "AWS_DEFAULT_REGION": "us-east-1"'
    echo "     }"
    echo "   }"
    exit 1
fi

# Copy credentials to tool directory (required by credential-code)
echo "📋 Copying credentials to tool directory..."
cp "$PROJECT_ROOT/.credential-code/credentials.json" "$PROJECT_ROOT/.credential-code-tool/.credential-code/credentials.json"

# Change to project root for generation
cd "$PROJECT_ROOT"

# Generate Swift credentials
echo ""
echo "🍎 Generating Swift credentials..."
.credential-code-tool/.build/release/credential-code generate --language swift

if [ -f "Generated/Credentials.swift" ]; then
    echo "✅ Swift credentials generated"
    
    # Copy to iOS project
    echo "📦 Copying to iOS project..."
    cp "Generated/Credentials.swift" "apple/Photolala/Utilities/Credentials.swift"
    echo "✅ iOS credentials updated at: apple/Photolala/Utilities/Credentials.swift"
else
    echo "❌ Failed to generate Swift credentials"
    exit 1
fi

# Generate Kotlin credentials
echo ""
echo "🤖 Generating Kotlin credentials..."
.credential-code-tool/.build/release/credential-code generate --language kotlin

if [ -f "Generated/Credentials.kt" ]; then
    echo "✅ Kotlin credentials generated"
    
    # Copy to Android project
    echo "📦 Copying to Android project..."
    mkdir -p "android/app/src/main/java/com/electricwoods/photolala/utils"
    cp "Generated/Credentials.kt" "android/app/src/main/java/com/electricwoods/photolala/utils/Credentials.kt"
    
    # Fix package name
    echo "🔧 Fixing Android package name..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's/package com.example.credentials/package com.electricwoods.photolala.utils/g' \
            "android/app/src/main/java/com/electricwoods/photolala/utils/Credentials.kt"
    else
        # Linux
        sed -i 's/package com.example.credentials/package com.electricwoods.photolala.utils/g' \
            "android/app/src/main/java/com/electricwoods/photolala/utils/Credentials.kt"
    fi
    
    echo "✅ Android credentials updated at: android/app/src/main/java/com/electricwoods/photolala/utils/Credentials.kt"
else
    echo "❌ Failed to generate Kotlin credentials"
    exit 1
fi

# Clean up generated files
echo ""
echo "🧹 Cleaning up temporary files..."
rm -f "Generated/Credentials.swift" "Generated/Credentials.kt"

echo ""
echo "✨ Credential generation complete!"
echo ""
echo "📝 Summary:"
echo "   - iOS credentials:     apple/Photolala/Utilities/Credentials.swift"
echo "   - Android credentials: android/app/src/main/java/com/electricwoods/photolala/utils/Credentials.kt"
echo ""
echo "🔒 These encrypted files are safe to commit to your repository."
echo "⚠️  Remember: Never commit .credential-code/credentials.json!"
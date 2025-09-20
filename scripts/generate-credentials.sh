#!/bin/bash

# Generate encrypted credential files for all platforms

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "🔐 Generating encrypted credentials..."

cd "$PROJECT_ROOT/.credential-tool"

# Generate Swift credentials for Apple platforms
echo "📱 Generating Swift credentials..."
./.build/release/credential-code generate \
    --language swift \
    --output ../apple/Photolala/Credentials/Credentials.swift

if [ $? -eq 0 ]; then
    echo "✅ Swift credentials generated successfully"
else
    echo "❌ Failed to generate Swift credentials"
    exit 1
fi

# Generate Kotlin credentials for Android
echo "🤖 Generating Kotlin credentials..."
./.build/release/credential-code generate \
    --language kotlin \
    --output ../android/app/src/main/java/com/electricwoods/photolala/credentials/Credentials.kt

if [ $? -eq 0 ]; then
    echo "✅ Kotlin credentials generated successfully"
else
    echo "❌ Failed to generate Kotlin credentials"
    exit 1
fi

echo ""
echo "✨ All credentials generated successfully!"
echo ""
echo "Generated files:"
echo "  - apple/Photolala/Credentials/Credentials.swift"
echo "  - android/.../credentials/Credentials.kt"
#!/bin/bash

# Validate that all required credentials are present

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
CRED_DIR="$PROJECT_ROOT/.credentials"

echo "🔍 Validating credentials setup..."
echo ""

ERRORS=0
WARNINGS=0

# Function to check file exists
check_file() {
    local file=$1
    local desc=$2

    if [ -f "$file" ]; then
        echo "  ✅ $desc"
        return 0
    else
        echo "  ❌ $desc (missing)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check file not empty
check_not_empty() {
    local file=$1
    local desc=$2

    if [ -f "$file" ] && [ -s "$file" ]; then
        echo "  ✅ $desc"
        return 0
    else
        echo "  ⚠️  $desc (empty or missing)"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

echo "📁 Checking directory structure..."
if [ -d "$CRED_DIR" ]; then
    echo "  ✅ .credentials directory exists"
else
    echo "  ❌ .credentials directory missing"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "⚙️  Note: Environment configuration is handled in-app via UserDefaults"

echo ""
echo "☁️  Checking AWS credentials (all environments in one file)..."
echo "  Note: All environments (dev/stage/prod) are encrypted together"
for env in dev stage prod; do
    echo "  Environment: $env"
    check_not_empty "$CRED_DIR/aws/$env/access-key.txt" "    Access Key"
    check_not_empty "$CRED_DIR/aws/$env/secret-key.txt" "    Secret Key"
done

echo ""
echo "🍎 Checking Apple Sign-In..."
check_file "$CRED_DIR/apple/config.json" "Apple config"
check_file "$CRED_DIR/apple/private-key.p8" "Apple private key"

echo ""
echo "🌐 Checking Google OAuth (optional)..."
if [ -f "$CRED_DIR/google/oauth-config.json" ]; then
    echo "  ✅ Google OAuth config"
else
    echo "  ⚠️  Google OAuth config (optional, not configured)"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "🔑 Checking JWT secret (optional)..."
if [ -f "$CRED_DIR/jwt/secret.txt" ]; then
    echo "  ✅ JWT secret"
else
    echo "  ⚠️  JWT secret (optional, not configured)"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "🔧 Checking credential-code tool..."
if [ -f "$PROJECT_ROOT/.credential-tool/.build/release/credential-code" ]; then
    echo "  ✅ credential-code binary"
else
    echo "  ❌ credential-code binary missing"
    echo "     Run: cd .credential-tool && swift build -c release"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "📱 Checking generated files (contains ALL environments)..."
check_file "$PROJECT_ROOT/apple/Photolala/Credentials/Credentials.swift" "Swift credentials (all envs)"
check_file "$PROJECT_ROOT/android/app/src/main/java/com/electricwoods/photolala/credentials/Credentials.kt" "Kotlin credentials (all envs)"

echo ""
echo "🔐 Security note:"
echo "  All credentials (dev/stage/prod) are encrypted in a single source file."
echo "  The app selects the appropriate credentials at runtime based on config."
echo "  This is secure because credential-code encrypts the values."

echo ""
echo "=" * 50
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✨ All credentials are properly configured!"
elif [ $ERRORS -eq 0 ]; then
    echo "✅ Core credentials configured ($WARNINGS optional items missing)"
else
    echo "❌ Found $ERRORS errors and $WARNINGS warnings"
    echo ""
    echo "To fix missing credentials:"
    echo "  1. Add missing credential files to .credentials/"
    echo "  2. Run: ./scripts/generate-credentials.sh"
    exit 1
fi
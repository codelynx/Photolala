#!/bin/bash

# Fix S3 bucket name to be lowercase "photolala"
# S3 bucket names must be lowercase

echo "🔧 Fixing S3 bucket name to 'photolala' (lowercase)..."
echo ""

# Define project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Fix in Swift files
echo "📝 Updating Swift files..."
find . -name "*.swift" -type f -not -path "./build*" -not -path "./.build/*" | while read file; do
    # Fix bucket name declarations
    sed -i '' 's/private let bucketName = "Photolala"/private let bucketName = "photolala"/g' "$file"
    sed -i '' 's/let bucketName = "Photolala"/let bucketName = "photolala"/g' "$file"
    
    # Fix any hardcoded references
    sed -i '' 's/"photolala-photos"/"photolala"/g' "$file"
done

# Fix in documentation
echo "📚 Updating documentation..."
find ./docs -name "*.md" -type f | while read file; do
    # Fix incorrect bucket name
    sed -i '' 's/photolala-photos/photolala/g' "$file"
    sed -i '' 's/s3:\/\/Photolala\//s3:\/\/photolala\//g' "$file"
done

echo ""
echo "✅ Done! S3 bucket name is now consistently 'photolala' (lowercase)"
echo ""
echo "💡 Remember: S3 bucket names must always be lowercase"
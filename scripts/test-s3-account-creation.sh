#!/bin/bash

# Test script to verify S3 account creation
# Usage: ./test-s3-account-creation.sh

echo "=== S3 Account Creation Test ==="
echo "Checking S3 bucket contents..."
echo ""

# Check for identity mappings
echo "1. Identity Mappings (identities/):"
aws s3 ls s3://photolala/identities/ --recursive --region us-east-1 2>&1 | head -10
echo ""

# Check for photos/thumbnails/metadata directories
echo "2. Content Directories:"
echo "   Photos:"
aws s3 ls s3://photolala/photos/ --recursive --region us-east-1 2>&1 | head -5
echo "   Thumbnails:"
aws s3 ls s3://photolala/thumbnails/ --recursive --region us-east-1 2>&1 | head -5
echo "   Metadata:"
aws s3 ls s3://photolala/metadata/ --recursive --region us-east-1 2>&1 | head -5
echo ""

# Check for email mappings
echo "3. Email Mappings (emails/):"
aws s3 ls s3://photolala/emails/ --recursive --region us-east-1 2>&1 | head -10
echo ""

# Count total objects
echo "4. Summary:"
IDENTITY_COUNT=$(aws s3 ls s3://photolala/identities/ --recursive --region us-east-1 2>&1 | wc -l)
PHOTO_COUNT=$(aws s3 ls s3://photolala/photos/ --recursive --region us-east-1 2>&1 | wc -l)
THUMBNAIL_COUNT=$(aws s3 ls s3://photolala/thumbnails/ --recursive --region us-east-1 2>&1 | wc -l)
METADATA_COUNT=$(aws s3 ls s3://photolala/metadata/ --recursive --region us-east-1 2>&1 | wc -l)
EMAIL_COUNT=$(aws s3 ls s3://photolala/emails/ --recursive --region us-east-1 2>&1 | wc -l)

echo "  - Identity mappings: $IDENTITY_COUNT"
echo "  - Photos: $PHOTO_COUNT"
echo "  - Thumbnails: $THUMBNAIL_COUNT"
echo "  - Metadata: $METADATA_COUNT"
echo "  - Email mappings: $EMAIL_COUNT"
echo ""

# Check if any accounts exist
if [ "$IDENTITY_COUNT" -gt 0 ]; then
    echo "✅ Accounts found in S3"
    
    # Show example of identity mapping content
    echo ""
    echo "5. Sample Identity Mapping Content:"
    FIRST_IDENTITY=$(aws s3 ls s3://photolala/identities/ --recursive --region us-east-1 2>&1 | head -1 | awk '{print $4}')
    if [ ! -z "$FIRST_IDENTITY" ]; then
        echo "  File: $FIRST_IDENTITY"
        echo -n "  Content (UUID): "
        aws s3 cp s3://photolala/$FIRST_IDENTITY - --region us-east-1 2>&1
        echo ""
    fi
else
    echo "❌ No accounts found in S3"
    echo "   Please create an account in the app first"
fi
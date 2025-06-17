#!/bin/bash

# Simple S3 Lifecycle Configuration for Photolala
# This applies a basic rule to archive all user content after 180 days

BUCKET_NAME="${PHOTOLALA_BUCKET:-photolala}"
REGION="${AWS_REGION:-us-east-1}"

echo "Configuring simple S3 lifecycle rules for bucket: $BUCKET_NAME"
echo "============================================================"
echo ""
echo "⚠️  WARNING: This configuration will archive ALL content under users/"
echo "including photos, thumbnails, and metadata after 180 days."
echo ""
echo "Current Photolala S3 structure:"
echo "  users/{userId}/photos/*.dat    - Original photos"
echo "  users/{userId}/thumbs/*.dat    - Thumbnails"  
echo "  users/{userId}/metadata/*.plist - Metadata files"
echo ""
echo "All will be moved to DEEP_ARCHIVE after 180 days."
echo ""

read -p "Do you want to proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

# Create lifecycle configuration JSON
cat > lifecycle-rules.json <<EOF
{
    "Rules": [
        {
            "ID": "archive-all-user-content",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "users/"
            },
            "Transitions": [
                {
                    "Days": 180,
                    "StorageClass": "DEEP_ARCHIVE"
                }
            ]
        },
        {
            "ID": "cleanup-incomplete-uploads",
            "Status": "Enabled",
            "Filter": {},
            "AbortIncompleteMultipartUpload": {
                "DaysAfterInitiation": 7
            }
        }
    ]
}
EOF

# Apply lifecycle configuration
echo -e "\nApplying lifecycle configuration..."
aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration file://lifecycle-rules.json

if [ $? -eq 0 ]; then
    echo "✅ Lifecycle rules configured successfully!"
    
    # Verify the configuration
    echo -e "\nCurrent lifecycle configuration:"
    aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" --output json | jq '.'
else
    echo "❌ Failed to configure lifecycle rules"
    exit 1
fi

# Clean up
rm lifecycle-rules.json

echo -e "\n📝 Important considerations:"
echo "1. This will archive thumbnails and metadata too (not ideal)"
echo "2. Retrieved files remain accessible for 30 days before re-archiving"
echo "3. Retrieval costs: \$0.025/GB (standard) or \$0.10/GB (expedited)"
echo ""
echo "🎯 Recommended improvements:"
echo "1. Update S3BackupService.swift to use different top-level prefixes:"
echo "   - photos/{userId}/{md5}.dat"
echo "   - thumbnails/{userId}/{md5}.dat"
echo "   - metadata/{userId}/{md5}.plist"
echo ""
echo "2. Or implement object tagging in the upload process"
echo "3. Or use the Lambda-based approach for selective archiving"
echo ""
echo "✅ Configuration complete!"
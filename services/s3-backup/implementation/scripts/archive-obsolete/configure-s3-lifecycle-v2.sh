#!/bin/bash

# Configure S3 Lifecycle Rules for Photolala
# This script sets up lifecycle rules using AWS CLI
# Version 2: Handles actual S3 structure where everything is under users/

BUCKET_NAME="${PHOTOLALA_BUCKET:-photolala}"
REGION="${AWS_REGION:-us-east-1}"

echo "Configuring S3 lifecycle rules for bucket: $BUCKET_NAME"
echo "This will set up rules for the actual Photolala S3 structure:"
echo "  - users/*/photos/*.dat -> Deep Archive after 180 days"
echo "  - users/*/thumbs/*.dat -> Intelligent Tiering immediately"
echo "  - users/*/metadata/*.plist -> Remains in Standard storage"

# Since we can't use wildcards in prefixes, we'll use a tag-based approach
# or create rules that apply to the entire users/ prefix with specific logic

# Create lifecycle configuration JSON
cat > lifecycle-rules.json <<EOF
{
    "Rules": [
        {
            "ID": "archive-user-photos",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "users/"
            },
            "Transitions": [
                {
                    "Days": 180,
                    "StorageClass": "DEEP_ARCHIVE"
                }
            ],
            "NoncurrentVersionTransitions": [
                {
                    "NoncurrentDays": 1,
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

echo -e "\n⚠️  WARNING: The above configuration will archive ALL objects under users/ after 180 days"
echo "This includes photos, thumbnails, and metadata."
echo ""
echo "For more granular control, you have three options:"
echo ""
echo "Option 1: Use object tagging when uploading (recommended)"
echo "  - Tag photos with Type=photo"
echo "  - Tag thumbnails with Type=thumbnail"
echo "  - Tag metadata with Type=metadata"
echo "  - Then use tag-based lifecycle rules"
echo ""
echo "Option 2: Use separate prefixes"
echo "  - Store photos at: photos/{userId}/{md5}.dat"
echo "  - Store thumbnails at: thumbnails/{userId}/{md5}.dat"
echo "  - Store metadata at: metadata/{userId}/{md5}.plist"
echo ""
echo "Option 3: Use Lambda function to selectively apply transitions"
echo "  - Create a Lambda that runs daily"
echo "  - Checks object keys and applies appropriate storage class"
echo ""

read -p "Do you want to proceed with the basic configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled. Cleaning up..."
    rm lifecycle-rules.json
    exit 1
fi

# Apply lifecycle configuration
echo "Applying lifecycle configuration..."
aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration file://lifecycle-rules.json

if [ $? -eq 0 ]; then
    echo "✅ Lifecycle rules configured successfully!"
    
    # Verify the configuration
    echo -e "\nVerifying configuration..."
    aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" --output table
else
    echo "❌ Failed to configure lifecycle rules"
    exit 1
fi

# Clean up
rm lifecycle-rules.json

# Create a script to add tags during upload (for future use)
cat > tag-objects.sh <<'EOF'
#!/bin/bash
# Example of how to upload objects with tags for lifecycle management

BUCKET="${1:-photolala}"
USER_ID="$2"
FILE="$3"
TYPE="$4" # photo, thumbnail, or metadata

if [ -z "$USER_ID" ] || [ -z "$FILE" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 <bucket> <user_id> <file> <type>"
    echo "Example: $0 photolala u_123456 image.jpg photo"
    exit 1
fi

MD5=$(md5sum "$FILE" | cut -d' ' -f1)

case "$TYPE" in
    photo)
        KEY="users/$USER_ID/photos/$MD5.dat"
        TAGS="Type=photo"
        ;;
    thumbnail)
        KEY="users/$USER_ID/thumbs/$MD5.dat"
        TAGS="Type=thumbnail"
        ;;
    metadata)
        KEY="users/$USER_ID/metadata/$MD5.plist"
        TAGS="Type=metadata"
        ;;
    *)
        echo "Invalid type: $TYPE"
        exit 1
        ;;
esac

echo "Uploading $FILE to s3://$BUCKET/$KEY with tags: $TAGS"
aws s3 cp "$FILE" "s3://$BUCKET/$KEY" --tagging "$TAGS"
EOF

chmod +x tag-objects.sh

echo -e "\n📝 Created tag-objects.sh script for tagged uploads"

# Create monitoring script specific to Photolala structure
cat > monitor-photolala-lifecycle.sh <<'EOF'
#!/bin/bash
# Monitor S3 storage for Photolala structure

BUCKET="${1:-photolala}"

echo "Analyzing Photolala bucket: $BUCKET"
echo "========================================"

# Count objects by type (based on path structure)
echo -e "\nObject counts by type:"
echo "----------------------"

# Photos
PHOTO_COUNT=$(aws s3 ls "s3://$BUCKET/users/" --recursive | grep "/photos/" | wc -l)
echo "Photos: $PHOTO_COUNT"

# Thumbnails
THUMB_COUNT=$(aws s3 ls "s3://$BUCKET/users/" --recursive | grep "/thumbs/" | wc -l)
echo "Thumbnails: $THUMB_COUNT"

# Metadata
META_COUNT=$(aws s3 ls "s3://$BUCKET/users/" --recursive | grep "/metadata/" | wc -l)
echo "Metadata: $META_COUNT"

# Get sample of storage classes
echo -e "\nStorage class distribution (sample of 10 photos):"
echo "-------------------------------------------------"
aws s3api list-objects-v2 \
    --bucket "$BUCKET" \
    --prefix "users/" \
    --max-items 10 \
    --query 'Contents[?contains(Key, `/photos/`)].{Key:Key,StorageClass:StorageClass}' \
    --output table

# Calculate approximate costs
echo -e "\nApproximate monthly storage costs:"
echo "----------------------------------"
# This is simplified - would need actual size data for accurate costs
echo "Note: These are estimates based on object count, not actual size"
echo "Standard: ~\$0.023 per GB/month"
echo "Intelligent-Tiering: ~\$0.0125 per GB/month"
echo "Deep Archive: ~\$0.00099 per GB/month"
EOF

chmod +x monitor-photolala-lifecycle.sh

echo -e "\n📊 Created monitor-photolala-lifecycle.sh script"

echo -e "\n⚠️  IMPORTANT: Update the S3BackupService to add tags when uploading:"
echo "This would enable more precise lifecycle rules based on object type."
echo ""
echo "Example modification needed in S3BackupService.swift:"
echo "  let putObjectInput = PutObjectInput("
echo "      body: .data(photoData),"
echo "      bucket: bucketName,"
echo "      key: key,"
echo "      tagging: \"Type=photo\"  // Add this line"
echo "  )"

echo -e "\n✅ S3 lifecycle configuration complete!"
echo -e "\nNext steps:"
echo "1. Consider implementing object tagging in the app"
echo "2. Monitor transitions using ./monitor-photolala-lifecycle.sh"
echo "3. Set up CloudWatch alarms for Deep Archive growth"
echo "4. Document the 180-day archive policy for users"
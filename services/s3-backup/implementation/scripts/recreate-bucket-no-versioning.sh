#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BUCKET_NAME="photolala"
REGION="us-east-1"

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install with: brew install jq"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is required but not installed.${NC}"
    exit 1
fi

echo -e "${YELLOW}=== S3 Bucket Recreation Script ===${NC}"
echo -e "${YELLOW}This will DELETE and RECREATE the bucket: ${RED}$BUCKET_NAME${NC}"
echo -e "${RED}⚠️  WARNING: This will permanently delete ALL data in the bucket!${NC}"
echo ""

# Confirmation
read -p "Are you absolutely sure you want to continue? Type 'yes' to proceed: " confirmation
if [ "$confirmation" != "yes" ]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}Step 1: Checking current bucket status...${NC}"
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Bucket exists: $BUCKET_NAME"
    
    # Check versioning status
    VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --region "$REGION" --query 'Status' --output text 2>/dev/null)
    if [ "$VERSIONING" == "Enabled" ]; then
        echo -e "${YELLOW}⚠️  Versioning is currently ENABLED${NC}"
    else
        echo -e "${GREEN}✓${NC} Versioning is not enabled"
    fi
else
    echo -e "${RED}✗${NC} Bucket does not exist: $BUCKET_NAME"
    exit 1
fi

echo -e "\n${YELLOW}Step 2: Listing bucket contents...${NC}"
OBJECT_COUNT=$(aws s3 ls s3://$BUCKET_NAME --recursive | wc -l)
echo "Found $OBJECT_COUNT objects"

if [ "$OBJECT_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}Step 3: Deleting all objects...${NC}"
    aws s3 rm s3://$BUCKET_NAME --recursive
    echo -e "${GREEN}✓${NC} All objects deleted"
fi

# If versioning was enabled, delete all versions
if [ "$VERSIONING" == "Enabled" ]; then
    echo -e "\n${YELLOW}Step 3a: Deleting all object versions...${NC}"
    
    # Function to delete versions with pagination
    delete_all_versions() {
        local key_marker=""
        local version_marker=""
        local total_deleted=0
        
        while true; do
            # Build command with optional continuation tokens
            local cmd="aws s3api list-object-versions --bucket $BUCKET_NAME --region $REGION --max-keys 1000"
            if [ -n "$key_marker" ]; then
                cmd="$cmd --key-marker \"$key_marker\""
                if [ -n "$version_marker" ]; then
                    cmd="$cmd --version-id-marker \"$version_marker\""
                fi
            fi
            
            # Get batch of versions
            local response=$(eval $cmd)
            
            # Count items in this batch
            local version_count=$(echo "$response" | jq -r '.Versions[]? | .Key' | wc -l)
            local marker_count=$(echo "$response" | jq -r '.DeleteMarkers[]? | .Key' | wc -l)
            
            # Delete versions
            echo "$response" | jq -r '.Versions[]? | @base64' | while read -r version; do
                if [ -n "$version" ]; then
                    KEY=$(echo "$version" | base64 -d | jq -r '.Key')
                    VERSION_ID=$(echo "$version" | base64 -d | jq -r '.VersionId')
                    aws s3api delete-object --bucket "$BUCKET_NAME" --region "$REGION" --key "$KEY" --version-id "$VERSION_ID" &>/dev/null
                fi
            done
            
            # Delete delete markers
            echo "$response" | jq -r '.DeleteMarkers[]? | @base64' | while read -r marker; do
                if [ -n "$marker" ]; then
                    KEY=$(echo "$marker" | base64 -d | jq -r '.Key')
                    VERSION_ID=$(echo "$marker" | base64 -d | jq -r '.VersionId')
                    aws s3api delete-object --bucket "$BUCKET_NAME" --region "$REGION" --key "$KEY" --version-id "$VERSION_ID" &>/dev/null
                fi
            done
            
            # Update total count
            total_deleted=$((total_deleted + version_count + marker_count))
            echo -ne "\rDeleted $total_deleted items..."
            
            # Check for more pages
            key_marker=$(echo "$response" | jq -r '.NextKeyMarker // empty')
            version_marker=$(echo "$response" | jq -r '.NextVersionIdMarker // empty')
            if [ -z "$key_marker" ]; then
                break
            fi
        done
        
        echo ""  # New line after progress
    }
    
    delete_all_versions
    echo -e "${GREEN}✓${NC} All versions and delete markers removed"
fi

echo -e "\n${YELLOW}Step 4: Deleting the bucket...${NC}"
aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION"
echo -e "${GREEN}✓${NC} Bucket deleted"

# Wait a moment to ensure bucket name is released
sleep 2

echo -e "\n${YELLOW}Step 5: Recreating bucket WITHOUT versioning...${NC}"
if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME"
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
fi
echo -e "${GREEN}✓${NC} Bucket created: $BUCKET_NAME"

echo -e "\n${YELLOW}Step 6: Configuring bucket settings...${NC}"

# Block public access
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo -e "${GREEN}✓${NC} Public access blocked"

# Verify versioning is NOT enabled
VERSIONING_NEW=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --region "$REGION" --query 'Status' --output text 2>/dev/null)
if [ -z "$VERSIONING_NEW" ] || [ "$VERSIONING_NEW" == "None" ]; then
    echo -e "${GREEN}✓${NC} Versioning is OFF (as intended)"
else
    echo -e "${RED}✗${NC} WARNING: Versioning status is: $VERSIONING_NEW"
fi

echo -e "\n${YELLOW}Step 7: Setting up lifecycle rules...${NC}"

# Create lifecycle configuration
cat > /tmp/lifecycle-rules.json <<EOF
{
    "Rules": [
        {
            "ID": "archive-user-photos",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "photos/"
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

aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --lifecycle-configuration file:///tmp/lifecycle-rules.json

echo -e "${GREEN}✓${NC} Lifecycle rules configured"

# Clean up temp file
rm -f /tmp/lifecycle-rules.json

echo -e "\n${GREEN}✅ Bucket recreation complete!${NC}"
echo -e "Bucket: ${GREEN}$BUCKET_NAME${NC}"
echo -e "Region: ${GREEN}$REGION${NC}"
echo -e "Versioning: ${GREEN}OFF${NC}"
echo -e "Public Access: ${GREEN}BLOCKED${NC}"
echo -e "Lifecycle Rules: ${GREEN}CONFIGURED${NC}"
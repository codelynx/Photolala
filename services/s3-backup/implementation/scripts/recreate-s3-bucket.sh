#!/bin/bash

# Script to recreate the photolala S3 bucket without versioning
# This script will:
# 1. List all objects (including versions)
# 2. Delete all objects and versions
# 3. Delete the bucket
# 4. Recreate the bucket without versioning
# 5. Apply correct policies and lifecycle rules

set -euo pipefail

# Configuration
BUCKET_NAME="photolala"
REGION="us-east-1"
PROFILE="photolala-admin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to confirm action
confirm() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$prompt [y/N]: " response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                return 0
                ;;
            [nN][oO]|[nN]|"")
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Function to list objects and versions
list_objects() {
    print_info "Listing all objects in bucket $BUCKET_NAME..."
    
    # List regular objects
    echo -e "\n${YELLOW}Regular objects:${NC}"
    aws s3api list-objects-v2 \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --query 'Contents[].{Key: Key, Size: Size, LastModified: LastModified}' \
        --output table 2>/dev/null || echo "No objects found"
    
    # List object versions
    echo -e "\n${YELLOW}Object versions:${NC}"
    aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --query 'Versions[].{Key: Key, VersionId: VersionId, IsLatest: IsLatest, LastModified: LastModified}' \
        --output table 2>/dev/null || echo "No versions found"
    
    # List delete markers
    echo -e "\n${YELLOW}Delete markers:${NC}"
    aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --query 'DeleteMarkers[].{Key: Key, VersionId: VersionId, LastModified: LastModified}' \
        --output table 2>/dev/null || echo "No delete markers found"
}

# Function to delete all objects and versions
delete_all_objects() {
    print_info "Preparing to delete all objects and versions..."
    
    # Create a temporary file for batch delete
    local temp_file=$(mktemp)
    
    # Get all versions and delete markers
    aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}' \
        --output json > "$temp_file" 2>/dev/null || echo '{"Objects": []}' > "$temp_file"
    
    local version_count=$(jq '.Objects | length' "$temp_file")
    
    # Get delete markers
    local temp_file2=$(mktemp)
    aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --query '{Objects: DeleteMarkers[].{Key: Key, VersionId: VersionId}}' \
        --output json > "$temp_file2" 2>/dev/null || echo '{"Objects": []}' > "$temp_file2"
    
    local marker_count=$(jq '.Objects | length' "$temp_file2")
    
    print_warning "Found $version_count object versions and $marker_count delete markers"
    
    if [[ $version_count -gt 0 || $marker_count -gt 0 ]]; then
        if confirm "Delete all objects and versions?"; then
            # Delete versions
            if [[ $version_count -gt 0 ]]; then
                print_info "Deleting object versions..."
                aws s3api delete-objects \
                    --bucket "$BUCKET_NAME" \
                    --profile "$PROFILE" \
                    --delete file://"$temp_file"
            fi
            
            # Delete markers
            if [[ $marker_count -gt 0 ]]; then
                print_info "Deleting delete markers..."
                aws s3api delete-objects \
                    --bucket "$BUCKET_NAME" \
                    --profile "$PROFILE" \
                    --delete file://"$temp_file2"
            fi
            
            print_info "All objects and versions deleted"
        else
            print_info "Object deletion cancelled"
            rm -f "$temp_file" "$temp_file2"
            return 1
        fi
    else
        print_info "No objects to delete"
    fi
    
    rm -f "$temp_file" "$temp_file2"
    return 0
}

# Function to delete bucket
delete_bucket() {
    print_warning "Preparing to delete bucket $BUCKET_NAME"
    
    if confirm "Delete the bucket?"; then
        print_info "Deleting bucket..."
        aws s3api delete-bucket \
            --bucket "$BUCKET_NAME" \
            --profile "$PROFILE" \
            --region "$REGION"
        
        print_info "Bucket deleted successfully"
        return 0
    else
        print_info "Bucket deletion cancelled"
        return 1
    fi
}

# Function to create bucket without versioning
create_bucket() {
    print_info "Creating bucket $BUCKET_NAME without versioning..."
    
    # Create bucket
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --region "$REGION"
    
    print_info "Bucket created successfully"
    
    # Ensure versioning is suspended (should be off by default for new buckets)
    print_info "Ensuring versioning is suspended..."
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --versioning-configuration Status=Suspended
}

# Function to apply bucket policy
apply_bucket_policy() {
    print_info "Applying bucket policy..."
    
    # Create policy JSON
    local policy_file=$(mktemp)
    cat > "$policy_file" <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSTSAssumedRoleAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::533267185808:root"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::photolala",
                "arn:aws:s3:::photolala/*"
            ],
            "Condition": {
                "StringLike": {
                    "aws:userid": "AROAXZL3OHLDV2JQHGMX4:*"
                }
            }
        }
    ]
}
EOF
    
    aws s3api put-bucket-policy \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --policy file://"$policy_file"
    
    rm -f "$policy_file"
    print_info "Bucket policy applied"
}

# Function to apply lifecycle rules
apply_lifecycle_rules() {
    print_info "Applying lifecycle rules..."
    
    # Create lifecycle JSON
    local lifecycle_file=$(mktemp)
    cat > "$lifecycle_file" <<EOF
{
    "Rules": [
        {
            "ID": "TransitionToDeepArchive",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "users/"
            },
            "Transitions": [
                {
                    "Days": 0,
                    "StorageClass": "DEEP_ARCHIVE"
                }
            ]
        },
        {
            "ID": "AbortIncompleteMultipartUploads",
            "Status": "Enabled",
            "Filter": {
                "Prefix": ""
            },
            "AbortIncompleteMultipartUpload": {
                "DaysAfterInitiation": 1
            }
        }
    ]
}
EOF
    
    aws s3api put-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --lifecycle-configuration file://"$lifecycle_file"
    
    rm -f "$lifecycle_file"
    print_info "Lifecycle rules applied"
}

# Main execution
main() {
    print_info "S3 Bucket Recreation Script"
    print_info "Bucket: $BUCKET_NAME"
    print_info "Region: $REGION"
    print_info "Profile: $PROFILE"
    echo
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$PROFILE" 2>/dev/null; then
        print_error "Bucket $BUCKET_NAME does not exist"
        if confirm "Create new bucket?"; then
            create_bucket
            apply_bucket_policy
            apply_lifecycle_rules
            print_info "Bucket created and configured successfully"
        fi
        exit 0
    fi
    
    print_warning "This script will DELETE ALL DATA in the bucket $BUCKET_NAME"
    print_warning "This action CANNOT be undone!"
    echo
    
    if ! confirm "Do you want to proceed?"; then
        print_info "Operation cancelled"
        exit 0
    fi
    
    # Step 1: List objects
    list_objects
    echo
    
    # Step 2: Delete all objects and versions
    if ! delete_all_objects; then
        print_error "Failed to delete objects. Aborting."
        exit 1
    fi
    echo
    
    # Step 3: Delete bucket
    if ! delete_bucket; then
        print_error "Failed to delete bucket. Aborting."
        exit 1
    fi
    echo
    
    # Step 4: Recreate bucket
    create_bucket
    echo
    
    # Step 5: Apply policies and lifecycle rules
    apply_bucket_policy
    apply_lifecycle_rules
    echo
    
    print_info "Bucket recreation completed successfully!"
    print_info "The bucket $BUCKET_NAME has been recreated without versioning"
    print_info "All policies and lifecycle rules have been applied"
}

# Run main function
main "$@"
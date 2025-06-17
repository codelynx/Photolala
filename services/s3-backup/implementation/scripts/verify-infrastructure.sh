#!/bin/bash

# Photolala Infrastructure Verification Script
# This script verifies that all AWS infrastructure is correctly set up

set -e

# Configuration
BUCKET_NAME="${PHOTOLALA_BUCKET:-photolala}"
REGION="${AWS_REGION:-us-east-1}"
ROLE_NAME="PhotolalaUserRole"
BACKEND_USER="photolala-backend"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================="
echo "Photolala Infrastructure Verification"
echo "================================================="
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# Track overall status
ALL_GOOD=true

# Function to check status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        ALL_GOOD=false
    fi
}

# 1. Check S3 Bucket
echo "Checking S3 Bucket..."
aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null
check_status $? "Bucket exists: $BUCKET_NAME"


# Check public access block
PUBLIC_BLOCK=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" 2>/dev/null)
if echo "$PUBLIC_BLOCK" | grep -q '"BlockPublicAcls": true' && \
   echo "$PUBLIC_BLOCK" | grep -q '"BlockPublicPolicy": true' && \
   echo "$PUBLIC_BLOCK" | grep -q '"IgnorePublicAcls": true' && \
   echo "$PUBLIC_BLOCK" | grep -q '"RestrictPublicBuckets": true'; then
    check_status 0 "Public access blocked"
else
    check_status 1 "Public access blocked"
fi

# Check lifecycle rules
LIFECYCLE=$(aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" 2>/dev/null)
if [ $? -eq 0 ]; then
    if echo "$LIFECYCLE" | grep -q "archive-photos-180-days" && \
       echo "$LIFECYCLE" | grep -q "optimize-thumbnails"; then
        check_status 0 "Lifecycle rules configured"
    else
        check_status 1 "Lifecycle rules configured (incomplete)"
    fi
else
    check_status 1 "Lifecycle rules configured"
fi

echo ""

# 2. Check IAM Role
echo "Checking IAM Role..."
aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1
check_status $? "Role exists: $ROLE_NAME"

# Check role policy
POLICY=$(aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name PhotolalaUserPolicy 2>/dev/null)
if [ $? -eq 0 ]; then
    if echo "$POLICY" | grep -q "s3:GetObject" && \
       echo "$POLICY" | grep -q "s3:PutObject" && \
       echo "$POLICY" | grep -q "s3:RestoreObject"; then
        check_status 0 "Role permissions configured"
    else
        check_status 1 "Role permissions configured (incomplete)"
    fi
else
    check_status 1 "Role permissions configured"
fi

echo ""

# 3. Check Backend User
echo "Checking Backend User..."
aws iam get-user --user-name "$BACKEND_USER" >/dev/null 2>&1
check_status $? "User exists: $BACKEND_USER"

# Check user policy
BACKEND_POLICY=$(aws iam get-user-policy --user-name "$BACKEND_USER" --policy-name PhotolalaBackendPolicy 2>/dev/null)
if [ $? -eq 0 ]; then
    if echo "$BACKEND_POLICY" | grep -q "sts:AssumeRole"; then
        check_status 0 "Backend permissions configured"
    else
        check_status 1 "Backend permissions configured (incomplete)"
    fi
else
    check_status 1 "Backend permissions configured"
fi

# Check access keys
ACCESS_KEYS=$(aws iam list-access-keys --user-name "$BACKEND_USER" --query 'AccessKeyMetadata[?Status==`Active`]' --output json 2>/dev/null)
if [ $? -eq 0 ] && [ "$(echo "$ACCESS_KEYS" | jq length)" -gt 0 ]; then
    check_status 0 "Access keys exist"
else
    check_status 1 "Access keys exist"
fi

echo ""

# 4. Test STS Assume Role
echo "Testing STS Token Generation..."
TEST_RESULT=$(aws sts assume-role \
    --role-arn "arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME" \
    --role-session-name "verification-test" \
    --duration-seconds 900 \
    2>&1)

if [ $? -eq 0 ]; then
    check_status 0 "STS assume role successful"
    
    # Test with session policy
    SESSION_POLICY='{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'",
            "Condition": {
                "StringLike": {
                    "s3:prefix": "photos/test-user/*"
                }
            }
        }]
    }'
    
    TEST_WITH_POLICY=$(aws sts assume-role \
        --role-arn "arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME" \
        --role-session-name "verification-test-policy" \
        --duration-seconds 900 \
        --policy "$SESSION_POLICY" \
        2>&1)
    
    if [ $? -eq 0 ]; then
        check_status 0 "STS with session policy successful"
    else
        check_status 1 "STS with session policy successful"
    fi
else
    check_status 1 "STS assume role successful"
    echo "  Error: $TEST_RESULT"
fi

echo ""

# Summary
echo "================================================="
if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}✅ All infrastructure checks passed!${NC}"
    echo ""
    echo "Your infrastructure is ready. Next steps:"
    echo "1. Deploy your backend service"
    echo "2. Configure environment variables:"
    echo "   - AWS_REGION=$REGION"
    echo "   - PHOTOLALA_ROLE_ARN=arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
    echo "3. Test end-to-end upload flow"
else
    echo -e "${RED}❌ Some infrastructure checks failed${NC}"
    echo ""
    echo "Please run the setup script to fix missing components:"
    echo "  ./setup-aws-infrastructure.sh"
fi
echo "================================================="

# Optional: Test S3 operations with temporary credentials
if [ "$ALL_GOOD" = true ]; then
    echo ""
    read -p "Would you like to test S3 operations with temporary credentials? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}Testing S3 operations...${NC}"
        
        # Get temporary credentials
        TEMP_CREDS=$(aws sts assume-role \
            --role-arn "arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME" \
            --role-session-name "test-user-123" \
            --duration-seconds 3600 \
            --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
            --output text)
        
        # Parse credentials
        TEMP_ACCESS_KEY=$(echo "$TEMP_CREDS" | awk '{print $1}')
        TEMP_SECRET_KEY=$(echo "$TEMP_CREDS" | awk '{print $2}')
        TEMP_SESSION_TOKEN=$(echo "$TEMP_CREDS" | awk '{print $3}')
        
        # Test upload
        echo "Testing upload to photos/test-user-123/test.txt..."
        echo "Test photo data" | AWS_ACCESS_KEY_ID="$TEMP_ACCESS_KEY" \
            AWS_SECRET_ACCESS_KEY="$TEMP_SECRET_KEY" \
            AWS_SESSION_TOKEN="$TEMP_SESSION_TOKEN" \
            aws s3 cp - "s3://$BUCKET_NAME/photos/test-user-123/test.txt" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            check_status 0 "Upload with temporary credentials"
            
            # Clean up test file
            aws s3 rm "s3://$BUCKET_NAME/photos/test-user-123/test.txt" 2>/dev/null
        else
            check_status 1 "Upload with temporary credentials"
        fi
        
        # Test unauthorized access
        echo "Testing unauthorized access (should fail)..."
        echo "Test data" | AWS_ACCESS_KEY_ID="$TEMP_ACCESS_KEY" \
            AWS_SECRET_ACCESS_KEY="$TEMP_SECRET_KEY" \
            AWS_SESSION_TOKEN="$TEMP_SESSION_TOKEN" \
            aws s3 cp - "s3://$BUCKET_NAME/photos/other-user/test.txt" 2>/dev/null
        
        if [ $? -ne 0 ]; then
            check_status 0 "Access control working (unauthorized access blocked)"
        else
            check_status 1 "Access control working (unauthorized access allowed!)"
        fi
    fi
fi

exit 0
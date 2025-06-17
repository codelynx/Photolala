#!/bin/bash

# Photolala AWS Infrastructure Setup Script
# This script sets up the core AWS infrastructure for the S3 backup service

set -e  # Exit on error

# Configuration
BUCKET_NAME="${PHOTOLALA_BUCKET:-photolala}"
REGION="${AWS_REGION:-us-east-1}"
ROLE_NAME="PhotolalaUserRole"
BACKEND_USER="photolala-backend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================="
echo "Photolala AWS Infrastructure Setup"
echo "================================================="
echo ""
echo "This script will create:"
echo "• S3 bucket: $BUCKET_NAME (no versioning)"
echo "• IAM role: $ROLE_NAME"
echo "• IAM user: $BACKEND_USER"
echo "• Region: $REGION"
echo ""
echo -e "${YELLOW}⚠️  This requires AWS administrative access${NC}"
echo "================================================="
echo ""

read -p "Continue with setup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "\n${GREEN}✓${NC} Using AWS Account: $ACCOUNT_ID"

# Step 1: Create S3 Bucket
echo -e "\n${YELLOW}Step 1: Creating S3 bucket...${NC}"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Bucket already exists: $BUCKET_NAME"
else
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    echo -e "${GREEN}✓${NC} Created bucket: $BUCKET_NAME"
fi


# Block public access
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo -e "${GREEN}✓${NC} Blocked public access"

# Step 2: Create IAM Role
echo -e "\n${YELLOW}Step 2: Creating IAM role...${NC}"

# Create trust policy
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::$ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create or update role
if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}!${NC} Role already exists, updating trust policy..."
    aws iam update-assume-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-document file:///tmp/trust-policy.json
else
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json
fi
echo -e "${GREEN}✓${NC} Created/updated role: $ROLE_NAME"

# Create permissions policy
cat > /tmp/permissions-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:RestoreObject"
      ],
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME/photos/\${aws:userid}/*",
        "arn:aws:s3:::$BUCKET_NAME/thumbnails/\${aws:userid}/*",
        "arn:aws:s3:::$BUCKET_NAME/metadata/\${aws:userid}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::$BUCKET_NAME",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "photos/\${aws:userid}/*",
            "thumbnails/\${aws:userid}/*",
            "metadata/\${aws:userid}/*"
          ]
        }
      }
    }
  ]
}
EOF

# Attach policy to role
aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name PhotolalaUserPolicy \
    --policy-document file:///tmp/permissions-policy.json
echo -e "${GREEN}✓${NC} Attached permissions policy"

# Step 3: Create Backend User
echo -e "\n${YELLOW}Step 3: Creating backend service user...${NC}"

# Create user
if aws iam get-user --user-name "$BACKEND_USER" 2>/dev/null; then
    echo -e "${YELLOW}!${NC} User already exists: $BACKEND_USER"
else
    aws iam create-user --user-name "$BACKEND_USER"
    echo -e "${GREEN}✓${NC} Created user: $BACKEND_USER"
fi

# Create backend policy
cat > /tmp/backend-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:TagSession"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy to user
aws iam put-user-policy \
    --user-name "$BACKEND_USER" \
    --policy-name PhotolalaBackendPolicy \
    --policy-document file:///tmp/backend-policy.json
echo -e "${GREEN}✓${NC} Attached backend policy"

# Step 4: Generate credentials
echo -e "\n${YELLOW}Step 4: Generating backend credentials...${NC}"

# Check if access key already exists
EXISTING_KEYS=$(aws iam list-access-keys --user-name "$BACKEND_USER" --query 'AccessKeyMetadata[?Status==`Active`].AccessKeyId' --output text)
if [ -n "$EXISTING_KEYS" ]; then
    echo -e "${YELLOW}!${NC} Active access keys already exist for $BACKEND_USER"
    echo "   Existing key IDs: $EXISTING_KEYS"
    echo "   To create new keys, first delete existing ones with:"
    echo "   aws iam delete-access-key --user-name $BACKEND_USER --access-key-id <KEY_ID>"
else
    # Create access key
    aws iam create-access-key --user-name "$BACKEND_USER" > backend-credentials.json
    echo -e "${GREEN}✓${NC} Created access key (saved to backend-credentials.json)"
    echo -e "${RED}⚠️  IMPORTANT: Save backend-credentials.json securely!${NC}"
fi

# Clean up temp files
rm -f /tmp/trust-policy.json /tmp/permissions-policy.json /tmp/backend-policy.json

# Step 5: Configure lifecycle rules
echo -e "\n${YELLOW}Step 5: Configuring S3 lifecycle rules...${NC}"

# Run the lifecycle configuration script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "$SCRIPT_DIR/configure-s3-lifecycle-final.sh" ]; then
    echo "Running lifecycle configuration..."
    export PHOTOLALA_BUCKET="$BUCKET_NAME"
    export AWS_REGION="$REGION"
    bash "$SCRIPT_DIR/configure-s3-lifecycle-final.sh" <<< "y"
else
    echo -e "${YELLOW}!${NC} Lifecycle script not found, skipping..."
fi

# Summary
echo -e "\n${GREEN}=================================================${NC}"
echo -e "${GREEN}✅ Infrastructure Setup Complete!${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo "Resources created:"
echo "• S3 Bucket: $BUCKET_NAME"
echo "• IAM Role: $ROLE_NAME"
echo "• IAM User: $BACKEND_USER"
echo "• Role ARN: arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
echo ""
echo "Next steps:"
echo "1. Save backend-credentials.json securely"
echo "2. Set up your backend service with the credentials"
echo "3. Configure monitoring and alarms"
echo "4. Test STS token generation"
echo ""
echo "Backend environment variables:"
echo "AWS_ACCESS_KEY_ID=<from backend-credentials.json>"
echo "AWS_SECRET_ACCESS_KEY=<from backend-credentials.json>"
echo "AWS_REGION=$REGION"
echo "PHOTOLALA_ROLE_ARN=arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
echo ""

# Test STS token generation
echo -e "${YELLOW}Would you like to test STS token generation? (y/n)${NC}"
read -p "" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Testing STS assume role..."
    
    TEST_SESSION="test-user-$(date +%s)"
    RESULT=$(aws sts assume-role \
        --role-arn "arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME" \
        --role-session-name "$TEST_SESSION" \
        --duration-seconds 3600 \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} STS token generation successful!"
        echo "   Session: $TEST_SESSION"
        echo "   Temporary credentials generated (not shown for security)"
    else
        echo -e "${RED}✗${NC} STS token generation failed"
    fi
fi

echo -e "\n${GREEN}Setup complete!${NC}"
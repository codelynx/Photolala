#!/bin/bash

# Setup script for Photolala account deletion infrastructure
# Uses S3 Batch Operations (not AWS Batch with Docker)

set -e

ENVIRONMENT=${1:-development}
REGION=${AWS_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up Photolala deletion infrastructure"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"

# Set bucket name based on environment
case $ENVIRONMENT in
  development)
    BUCKET_NAME="photolala-dev"
    SCHEDULE="rate(5 minutes)"
    ;;
  staging)
    BUCKET_NAME="photolala-stage"
    SCHEDULE="cron(0 2 * * ? *)"
    ;;
  production)
    BUCKET_NAME="photolala-prod"
    SCHEDULE="cron(0 2 * * ? *)"
    ;;
  *)
    echo "Invalid environment. Use: development, staging, or production"
    exit 1
    ;;
esac

echo "Bucket: $BUCKET_NAME"

# Step 1: Create S3 Batch Operations IAM Role
echo "Creating S3 Batch Operations role..."
aws iam create-role \
  --role-name S3BatchOperationsRole \
  --assume-role-policy-document file://iam/s3-batch-operations-role.json \
  --description "Role for S3 Batch Operations to delete user data" \
  2>/dev/null || echo "Role already exists"

aws iam put-role-policy \
  --role-name S3BatchOperationsRole \
  --policy-name S3BatchOperationsDeletePolicy \
  --policy-document "$(cat iam/s3-batch-operations-role.json | jq -r '.Policies[0].PolicyDocument')"

# Step 2: Create Lambda Execution Role
echo "Creating Lambda execution role..."
aws iam create-role \
  --role-name PhotolalaDeletionLambdaRole-$ENVIRONMENT \
  --assume-role-policy-document "$(cat iam/lambda-deletion-role.json | jq -r '.TrustPolicy')" \
  --description "Role for Lambda function to manage account deletions" \
  2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
  --role-name PhotolalaDeletionLambdaRole-$ENVIRONMENT \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam put-role-policy \
  --role-name PhotolalaDeletionLambdaRole-$ENVIRONMENT \
  --policy-name PhotolalaDeletionPolicy \
  --policy-document "$(cat iam/lambda-deletion-role.json | jq -r '.Policies[0].PolicyDocument')"

# Wait for role to propagate
echo "Waiting for IAM roles to propagate..."
sleep 10

# Step 3: Create Lambda Function
echo "Creating Lambda function..."
cd lambda/deletion
zip -q function.zip handler.py

aws lambda create-function \
  --function-name photolala-deletion-$ENVIRONMENT \
  --runtime python3.11 \
  --role arn:aws:iam::$ACCOUNT_ID:role/PhotolalaDeletionLambdaRole-$ENVIRONMENT \
  --handler handler.handler \
  --zip-file fileb://function.zip \
  --timeout 900 \
  --memory-size 1024 \
  --environment Variables="{ENVIRONMENT=$ENVIRONMENT,BUCKET_NAME=$BUCKET_NAME}" \
  --description "Account deletion handler using S3 Batch Operations" \
  2>/dev/null || {
    echo "Function exists, updating code..."
    aws lambda update-function-code \
      --function-name photolala-deletion-$ENVIRONMENT \
      --zip-file fileb://function.zip

    aws lambda update-function-configuration \
      --function-name photolala-deletion-$ENVIRONMENT \
      --environment Variables="{ENVIRONMENT=$ENVIRONMENT,BUCKET_NAME=$BUCKET_NAME}" \
      --timeout 900 \
      --memory-size 1024
  }

rm function.zip
cd ../..

# Step 4: Create EventBridge Rule for Scheduled Deletions
echo "Creating EventBridge schedule rule..."
aws events put-rule \
  --name photolala-deletion-schedule-$ENVIRONMENT \
  --schedule-expression "$SCHEDULE" \
  --description "Trigger account deletion processing" \
  --state ENABLED

# Add Lambda as target
aws events put-targets \
  --rule photolala-deletion-schedule-$ENVIRONMENT \
  --targets "Id"="1","Arn"="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:photolala-deletion-$ENVIRONMENT","Input"='{"type":"scheduled"}'

# Grant EventBridge permission to invoke Lambda
aws lambda add-permission \
  --function-name photolala-deletion-$ENVIRONMENT \
  --statement-id EventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:$REGION:$ACCOUNT_ID:rule/photolala-deletion-schedule-$ENVIRONMENT \
  2>/dev/null || echo "Permission already exists"

# Step 5: Create S3 directories for batch jobs
echo "Creating S3 batch job directories..."
aws s3api put-object --bucket $BUCKET_NAME --key batch-jobs/manifests/ --content-length 0 2>/dev/null || true
aws s3api put-object --bucket $BUCKET_NAME --key batch-jobs/reports/ --content-length 0 2>/dev/null || true
aws s3api put-object --bucket $BUCKET_NAME --key batch-jobs/metadata/ --content-length 0 2>/dev/null || true

echo ""
echo "✅ Setup complete!"
echo ""
echo "Lambda Function: photolala-deletion-$ENVIRONMENT"
echo "EventBridge Rule: photolala-deletion-schedule-$ENVIRONMENT"
echo "Schedule: $SCHEDULE"
echo ""
echo "Test commands:"
echo "  # Test scheduled deletion processing (dry run)"
echo "  aws lambda invoke \\"
echo "    --function-name photolala-deletion-$ENVIRONMENT \\"
echo "    --payload '{\"type\":\"scheduled\"}' \\"
echo "    response.json"
echo ""
if [ "$ENVIRONMENT" = "development" ]; then
  echo "  # Test immediate deletion (dev only)"
  echo "  aws lambda invoke \\"
  echo "    --function-name photolala-deletion-$ENVIRONMENT \\"
  echo "    --payload '{\"type\":\"immediate\",\"userId\":\"test-user-id\"}' \\"
  echo "    response.json"
  echo ""
fi
echo "  # Check batch job status"
echo "  aws lambda invoke \\"
echo "    --function-name photolala-deletion-$ENVIRONMENT \\"
echo "    --payload '{\"type\":\"status\",\"jobId\":\"job-id-here\"}' \\"
echo "    response.json"
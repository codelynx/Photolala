#!/bin/bash

# Deploy Photolala Apple Auth Lambda Function
# This script packages and deploys the Lambda function to AWS

set -e

echo "🚀 Deploying Photolala Apple Auth Lambda..."

# Configuration
FUNCTION_NAME="photolala-apple-auth"
REGION="us-east-1"
RUNTIME="nodejs18.x"
HANDLER="index.handler"
TIMEOUT="30"
MEMORY="256"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "index.js" ]; then
    echo "❌ index.js not found. Please run this script from the lambda function directory."
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install --production

# Create deployment package
echo "📦 Creating deployment package..."
rm -f lambda.zip
zip -r lambda.zip . -x "*.git*" -x "deploy.sh" -x "*.md"

# Check if function exists
echo "🔍 Checking if Lambda function exists..."
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &> /dev/null; then
    echo "📝 Updating existing function..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://lambda.zip \
        --region $REGION
else
    echo "🆕 Creating new function..."
    # You'll need to create an IAM role first
    echo "⚠️  Please create an IAM role for Lambda first with S3 access permissions"
    echo "   Role should have policies:"
    echo "   - AWSLambdaBasicExecutionRole"
    echo "   - S3 access to photolala bucket"
    echo ""
    echo "   Example role ARN: arn:aws:iam::YOUR_ACCOUNT_ID:role/photolala-lambda-role"
    echo ""
    read -p "Enter the IAM role ARN: " ROLE_ARN
    
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime $RUNTIME \
        --role $ROLE_ARN \
        --handler $HANDLER \
        --timeout $TIMEOUT \
        --memory-size $MEMORY \
        --zip-file fileb://lambda.zip \
        --region $REGION
fi

# Update environment variables
echo "🔧 Setting environment variables..."
aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --environment Variables="{APPLE_SERVICE_ID=com.electricwoods.photolala.service}" \
    --region $REGION

# Create or update API Gateway (if needed)
echo "🌐 Setting up API Gateway..."
API_NAME="photolala-auth-api"

# Check if API exists
API_ID=$(aws apigatewayv2 get-apis --region $REGION --query "Items[?Name=='$API_NAME'].ApiId" --output text)

if [ -z "$API_ID" ]; then
    echo "🆕 Creating new API Gateway..."
    API_ID=$(aws apigatewayv2 create-api \
        --name $API_NAME \
        --protocol-type HTTP \
        --target arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$FUNCTION_NAME \
        --region $REGION \
        --query ApiId \
        --output text)
    
    # Add Lambda permission for API Gateway
    aws lambda add-permission \
        --function-name $FUNCTION_NAME \
        --statement-id apigateway-invoke \
        --action lambda:InvokeFunction \
        --principal apigateway.amazonaws.com \
        --source-arn "arn:aws:execute-api:$REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/*" \
        --region $REGION
fi

# Get the API endpoint
API_ENDPOINT=$(aws apigatewayv2 get-api --api-id $API_ID --region $REGION --query ApiEndpoint --output text)

# Clean up
rm lambda.zip

echo "✅ Deployment complete!"
echo ""
echo "📍 Lambda Function: $FUNCTION_NAME"
echo "🌐 API Endpoint: $API_ENDPOINT"
echo ""
echo "Test with:"
echo "curl -X POST $API_ENDPOINT \\
  -H 'Content-Type: application/json' \\
  -d '{\"id_token\": \"YOUR_APPLE_ID_TOKEN\"}'"
echo ""
echo "Add to Android app:"
echo "const val APPLE_AUTH_ENDPOINT = \"$API_ENDPOINT\""
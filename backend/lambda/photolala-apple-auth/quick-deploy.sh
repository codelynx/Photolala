#!/bin/bash
# Quick deployment script for Photolala Apple Auth Lambda
# Run this from the photolala-apple-auth directory

set -e

echo "🚀 Quick Deploy - Photolala Apple Auth Lambda"
echo "============================================="

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install: brew install awscli"
    exit 1
fi

# Check credentials
echo "📍 Checking AWS credentials..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ AWS credentials not configured. Run: aws configure"
    exit 1
fi

REGION=${AWS_DEFAULT_REGION:-us-east-1}
echo "✅ Account: $ACCOUNT_ID"
echo "✅ Region: $REGION"
echo ""

# Create all resources
echo "1️⃣  Creating IAM role..."
aws iam create-role \
    --role-name photolala-lambda-role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    2>/dev/null || echo "   Role already exists"

aws iam attach-role-policy \
    --role-name photolala-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    2>/dev/null || true

aws iam put-role-policy \
    --role-name photolala-lambda-role \
    --policy-name photolala-s3-access \
    --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:PutObject"],"Resource":["arn:aws:s3:::photolala/identities/*","arn:aws:s3:::photolala/emails/*"]}]}'

# Wait for role to be ready
sleep 5

echo "2️⃣  Installing dependencies..."
npm install --production --silent

echo "3️⃣  Creating deployment package..."
zip -r lambda.zip . -x "*.git*" -x "*.md" -x "*.sh" > /dev/null

echo "4️⃣  Deploying Lambda function..."
if aws lambda get-function --function-name photolala-apple-auth &>/dev/null; then
    aws lambda update-function-code \
        --function-name photolala-apple-auth \
        --zip-file fileb://lambda.zip \
        --output text > /dev/null
else
    aws lambda create-function \
        --function-name photolala-apple-auth \
        --runtime nodejs18.x \
        --role arn:aws:iam::${ACCOUNT_ID}:role/photolala-lambda-role \
        --handler index.handler \
        --timeout 30 \
        --memory-size 256 \
        --environment Variables={APPLE_SERVICE_ID=com.electricwoods.photolala.service} \
        --zip-file fileb://lambda.zip \
        --output text > /dev/null
fi

echo "5️⃣  Setting up API Gateway..."
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='photolala-auth-api'].ApiId" --output text 2>/dev/null || echo "")

if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
    API_ID=$(aws apigatewayv2 create-api \
        --name photolala-auth-api \
        --protocol-type HTTP \
        --target arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:photolala-apple-auth \
        --query ApiId \
        --output text)
    
    aws lambda add-permission \
        --function-name photolala-apple-auth \
        --statement-id apigateway-invoke \
        --action lambda:InvokeFunction \
        --principal apigateway.amazonaws.com \
        --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
        2>/dev/null || true
fi

API_ENDPOINT=$(aws apigatewayv2 get-api --api-id $API_ID --query ApiEndpoint --output text)

# Cleanup
rm -f lambda.zip

echo ""
echo "✅ Deployment complete!"
echo "======================"
echo ""
echo "🌐 API Endpoint:"
echo "   $API_ENDPOINT"
echo ""
echo "📱 Add to Android app (IdentityManager.kt):"
echo "   const val APPLE_AUTH_ENDPOINT = \"$API_ENDPOINT\""
echo ""
echo "🧪 Test the endpoint:"
echo "   curl -X POST $API_ENDPOINT \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"id_token\": \"test\"}'"
echo ""
echo "📊 View logs:"
echo "   aws logs tail /aws/logs/lambda/photolala-apple-auth --follow"
echo ""
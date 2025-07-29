#!/bin/bash

# Deploy script for Apple Sign-In callback Lambda

echo "🚀 Deploying Apple Sign-In Callback Lambda..."

# Configuration
FUNCTION_NAME="photolala-apple-callback"
REGION="us-east-1"
RUNTIME="nodejs18.x"
HANDLER="index.handler"
ROLE_ARN="arn:aws:iam::566372147352:role/photolala-lambda-role"

# Package the function
echo "📦 Packaging function..."
zip -j function.zip index.js

# Create or update the Lambda function
echo "⬆️  Uploading to Lambda..."
aws lambda get-function --function-name $FUNCTION_NAME --region $REGION >/dev/null 2>&1
if [ $? -eq 0 ]; then
    # Function exists, update it
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://function.zip \
        --region $REGION
else
    # Function doesn't exist, create it
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime $RUNTIME \
        --handler $HANDLER \
        --role $ROLE_ARN \
        --zip-file fileb://function.zip \
        --timeout 10 \
        --memory-size 128 \
        --region $REGION
fi

# Clean up
rm function.zip

# Get the function URL or create one
echo "🔗 Configuring function URL..."
aws lambda get-function-url-config --function-name $FUNCTION_NAME --region $REGION >/dev/null 2>&1
if [ $? -eq 0 ]; then
    # URL exists, just show it
    URL=$(aws lambda get-function-url-config --function-name $FUNCTION_NAME --region $REGION --query 'FunctionUrl' --output text)
else
    # Create function URL
    URL=$(aws lambda create-function-url-config \
        --function-name $FUNCTION_NAME \
        --auth-type NONE \
        --cors '{
            "AllowOrigins": ["*"],
            "AllowMethods": ["GET", "POST"],
            "AllowHeaders": ["*"],
            "MaxAge": 86400
        }' \
        --region $REGION \
        --query 'FunctionUrl' \
        --output text)
fi

echo "✅ Deployment complete!"
echo "🌐 Function URL: $URL"
echo ""
echo "📝 Next steps:"
echo "1. Update your Apple Service ID redirect URL to: $URL"
echo "2. Update REDIRECT_URI in AppleAuthService.kt to: $URL"
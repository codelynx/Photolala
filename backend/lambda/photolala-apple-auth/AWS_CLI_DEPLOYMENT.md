# Deploy Apple Sign-In Lambda Using AWS CLI

Last Updated: January 3, 2025

## Prerequisites Check

```bash
# Check AWS CLI is installed
aws --version

# Check you're logged in
aws sts get-caller-identity

# Set default region if needed
export AWS_DEFAULT_REGION=us-east-1
```

## Step 1: Create IAM Role for Lambda

```bash
# Create trust policy file
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name photolala-lambda-role \
  --assume-role-policy-document file://trust-policy.json

# Attach basic Lambda execution policy
aws iam attach-role-policy \
  --role-name photolala-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create S3 access policy
cat > s3-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::photolala/identities/*",
        "arn:aws:s3:::photolala/emails/*"
      ]
    }
  ]
}
EOF

# Create and attach S3 policy
aws iam put-role-policy \
  --role-name photolala-lambda-role \
  --policy-name photolala-s3-access \
  --policy-document file://s3-policy.json

# Get the role ARN (save this)
aws iam get-role --role-name photolala-lambda-role --query 'Role.Arn' --output text
```

## Step 2: Prepare Lambda Function

```bash
# Navigate to the lambda directory
cd backend/lambda/photolala-apple-auth

# Install dependencies
npm install --production

# Create deployment package
zip -r lambda.zip . -x "*.git*" -x "*.md" -x "deploy.sh"

# Check the package
ls -lh lambda.zip
```

## Step 3: Create Lambda Function

```bash
# Get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create the Lambda function
aws lambda create-function \
  --function-name photolala-apple-auth \
  --runtime nodejs18.x \
  --role arn:aws:iam::${ACCOUNT_ID}:role/photolala-lambda-role \
  --handler index.handler \
  --timeout 30 \
  --memory-size 256 \
  --environment Variables={APPLE_SERVICE_ID=com.electricwoods.photolala.service} \
  --zip-file fileb://lambda.zip

# Verify it was created
aws lambda get-function --function-name photolala-apple-auth
```

## Step 4: Create API Gateway

```bash
# Create HTTP API
API_ID=$(aws apigatewayv2 create-api \
  --name photolala-auth-api \
  --protocol-type HTTP \
  --target arn:aws:lambda:${AWS_DEFAULT_REGION}:${ACCOUNT_ID}:function:photolala-apple-auth \
  --query ApiId \
  --output text)

echo "API ID: $API_ID"

# Get the API endpoint
API_ENDPOINT=$(aws apigatewayv2 get-api \
  --api-id $API_ID \
  --query ApiEndpoint \
  --output text)

echo "API Endpoint: $API_ENDPOINT"

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
  --function-name photolala-apple-auth \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_DEFAULT_REGION}:${ACCOUNT_ID}:${API_ID}/*/*"
```

## Step 5: Test the Deployment

```bash
# Test Lambda directly (optional)
aws lambda invoke \
  --function-name photolala-apple-auth \
  --payload '{"body": "{\"id_token\": \"test\"}"}' \
  response.json

cat response.json

# Test via API Gateway
curl -X POST ${API_ENDPOINT} \
  -H 'Content-Type: application/json' \
  -d '{"id_token": "test"}'

# You should get an error about invalid token format - that's good!
```

## Step 6: Update Android App

Add this to your Android code:

```kotlin
companion object {
    // Use your actual endpoint from above
    const val APPLE_AUTH_ENDPOINT = "${API_ENDPOINT}"
}
```

## Useful Commands for Management

```bash
# View Lambda logs
aws logs tail /aws/logs/lambda/photolala-apple-auth --follow

# Update Lambda function code
zip -r lambda.zip . -x "*.git*" -x "*.md" -x "deploy.sh"
aws lambda update-function-code \
  --function-name photolala-apple-auth \
  --zip-file fileb://lambda.zip

# Update environment variables
aws lambda update-function-configuration \
  --function-name photolala-apple-auth \
  --environment Variables={APPLE_SERVICE_ID=com.electricwoods.photolala.service,LOG_LEVEL=debug}

# Check function status
aws lambda get-function-configuration \
  --function-name photolala-apple-auth \
  --query '[FunctionName, State, LastModified]'

# Delete everything (if needed)
aws lambda delete-function --function-name photolala-apple-auth
aws apigatewayv2 delete-api --api-id $API_ID
aws iam detach-role-policy \
  --role-name photolala-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role-policy \
  --role-name photolala-lambda-role \
  --policy-name photolala-s3-access
aws iam delete-role --role-name photolala-lambda-role
```

## Complete Script

Save this as `deploy-with-cli.sh`:

```bash
#!/bin/bash
set -e

echo "🚀 Deploying Photolala Apple Auth with AWS CLI..."

# Get account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Step 1: Create IAM Role
echo "📝 Creating IAM role..."
aws iam create-role \
  --role-name photolala-lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "Role already exists"

aws iam attach-role-policy \
  --role-name photolala-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam put-role-policy \
  --role-name photolala-lambda-role \
  --policy-name photolala-s3-access \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": ["arn:aws:s3:::photolala/identities/*", "arn:aws:s3:::photolala/emails/*"]
    }]
  }'

# Step 2: Package Lambda
echo "📦 Packaging Lambda function..."
npm install --production
zip -r lambda.zip . -x "*.git*" -x "*.md" -x "*.sh"

# Step 3: Create/Update Lambda
echo "🔧 Creating Lambda function..."
if aws lambda get-function --function-name photolala-apple-auth &>/dev/null; then
  aws lambda update-function-code \
    --function-name photolala-apple-auth \
    --zip-file fileb://lambda.zip
else
  aws lambda create-function \
    --function-name photolala-apple-auth \
    --runtime nodejs18.x \
    --role arn:aws:iam::${ACCOUNT_ID}:role/photolala-lambda-role \
    --handler index.handler \
    --timeout 30 \
    --memory-size 256 \
    --environment Variables={APPLE_SERVICE_ID=com.electricwoods.photolala.service} \
    --zip-file fileb://lambda.zip
fi

# Step 4: Create API Gateway
echo "🌐 Setting up API Gateway..."
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='photolala-auth-api'].ApiId" --output text)

if [ -z "$API_ID" ]; then
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
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*"
fi

API_ENDPOINT=$(aws apigatewayv2 get-api --api-id $API_ID --query ApiEndpoint --output text)

# Cleanup
rm lambda.zip

echo "✅ Deployment complete!"
echo ""
echo "API Endpoint: ${API_ENDPOINT}"
echo ""
echo "Add to Android app:"
echo "const val APPLE_AUTH_ENDPOINT = \"${API_ENDPOINT}\""
echo ""
echo "Test with:"
echo "curl -X POST ${API_ENDPOINT} -H 'Content-Type: application/json' -d '{\"id_token\": \"test\"}'"
```

Make it executable:
```bash
chmod +x deploy-with-cli.sh
./deploy-with-cli.sh
```

## Troubleshooting

If you get permission errors:
```bash
# Check your AWS credentials
aws configure list

# Check which user/role you're using
aws sts get-caller-identity

# List your policies
aws iam list-attached-user-policies --user-name YOUR_USERNAME
```

## Success!

You now have:
- ✅ Lambda function deployed
- ✅ API Gateway configured
- ✅ Endpoint URL for Android
- ✅ No AWS Console needed!

Total time: ~5 minutes with AWS CLI 🚀
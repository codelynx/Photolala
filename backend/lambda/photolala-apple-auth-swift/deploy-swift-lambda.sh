#!/bin/bash
# Deploy Swift Lambda for Apple Sign-In
# This uses AWS Lambda Custom Runtime for Swift

set -e

echo "🚀 Deploying Swift Lambda for Apple Auth"
echo "========================================"

# Configuration
LAMBDA_NAME="photolala-apple-auth-swift"
ARCHITECTURE="arm64"  # Use arm64 for better performance and cost
SWIFT_VERSION="5.9"

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v swift &> /dev/null; then
    echo "❌ Swift not installed. On macOS, install Xcode."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ Docker not installed. Required for building Lambda package."
    echo "   Install from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Get AWS account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_DEFAULT_REGION:-us-east-1}
echo "✅ Account: $ACCOUNT_ID"
echo "✅ Region: $REGION"

# Step 1: Build Swift Lambda package using Docker
echo ""
echo "🏗️  Building Swift Lambda package..."
echo "   This may take a few minutes on first run..."

# Create Dockerfile for building
cat > Dockerfile << 'EOF'
FROM swift:5.9-amazonlinux2 as builder

WORKDIR /build

# Copy source files
COPY Package.* ./
COPY Sources ./Sources

# Build for Lambda
RUN swift build -c release --product PhotolalaAppleAuth \
    -Xswiftc -static-stdlib

# Create bootstrap file for custom runtime
RUN echo '#!/bin/sh' > bootstrap && \
    echo 'exec "$LAMBDA_TASK_ROOT/PhotolalaAppleAuth"' >> bootstrap && \
    chmod +x bootstrap

# Package for Lambda
FROM public.ecr.aws/lambda/provided:al2-arm64

COPY --from=builder /build/.build/release/PhotolalaAppleAuth ${LAMBDA_TASK_ROOT}/
COPY --from=builder /build/bootstrap ${LAMBDA_TASK_ROOT}/

CMD ["PhotolalaAppleAuth"]
EOF

# Build using Docker
docker build -t photolala-apple-auth-swift .

# Extract the built binary
docker run --rm -v "$PWD":/output photolala-apple-auth-swift \
    sh -c "cp /var/task/PhotolalaAppleAuth /var/task/bootstrap /output/"

# Create deployment package
echo "📦 Creating deployment package..."
zip -j lambda-swift.zip PhotolalaAppleAuth bootstrap

# Step 2: Create/Update IAM Role
echo ""
echo "👤 Setting up IAM role..."
aws iam create-role \
    --role-name photolala-lambda-swift-role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    2>/dev/null || echo "   Role already exists"

aws iam attach-role-policy \
    --role-name photolala-lambda-swift-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam put-role-policy \
    --role-name photolala-lambda-swift-role \
    --policy-name photolala-s3-access \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": ["s3:GetObject", "s3:PutObject"],
            "Resource": [
                "arn:aws:s3:::photolala/identities/*",
                "arn:aws:s3:::photolala/emails/*"
            ]
        }]
    }'

sleep 5

# Step 3: Deploy Lambda Function
echo ""
echo "⚡ Deploying Lambda function..."

if aws lambda get-function --function-name $LAMBDA_NAME &>/dev/null; then
    echo "   Updating existing function..."
    aws lambda update-function-code \
        --function-name $LAMBDA_NAME \
        --zip-file fileb://lambda-swift.zip \
        --architectures $ARCHITECTURE
else
    echo "   Creating new function..."
    aws lambda create-function \
        --function-name $LAMBDA_NAME \
        --runtime provided.al2 \
        --architectures $ARCHITECTURE \
        --role arn:aws:iam::${ACCOUNT_ID}:role/photolala-lambda-swift-role \
        --handler PhotolalaAppleAuth \
        --timeout 30 \
        --memory-size 512 \
        --environment Variables={APPLE_SERVICE_ID=com.electricwoods.photolala.service} \
        --zip-file fileb://lambda-swift.zip
fi

# Step 4: Create API Gateway
echo ""
echo "🌐 Setting up API Gateway..."

API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='photolala-auth-swift-api'].ApiId" --output text 2>/dev/null || echo "")

if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
    API_ID=$(aws apigatewayv2 create-api \
        --name photolala-auth-swift-api \
        --protocol-type HTTP \
        --target arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${LAMBDA_NAME} \
        --query ApiId \
        --output text)
    
    aws lambda add-permission \
        --function-name $LAMBDA_NAME \
        --statement-id apigateway-invoke \
        --action lambda:InvokeFunction \
        --principal apigateway.amazonaws.com \
        --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*"
fi

API_ENDPOINT=$(aws apigatewayv2 get-api --api-id $API_ID --query ApiEndpoint --output text)

# Cleanup
rm -f lambda-swift.zip PhotolalaAppleAuth bootstrap Dockerfile

echo ""
echo "✅ Swift Lambda Deployment Complete!"
echo "===================================="
echo ""
echo "🎯 Lambda Function: $LAMBDA_NAME"
echo "🏗️  Architecture: $ARCHITECTURE"
echo "🌐 API Endpoint: $API_ENDPOINT"
echo ""
echo "📱 Add to Android app:"
echo "   const val APPLE_AUTH_ENDPOINT = \"$API_ENDPOINT\""
echo ""
echo "🧪 Test the endpoint:"
echo "   curl -X POST $API_ENDPOINT \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"idToken\": \"test\"}'"
echo ""
echo "📊 View logs:"
echo "   aws logs tail /aws/logs/lambda/$LAMBDA_NAME --follow"
echo ""
echo "⚡ Performance note: Swift Lambda has ~100ms cold start vs ~500ms for Node.js"
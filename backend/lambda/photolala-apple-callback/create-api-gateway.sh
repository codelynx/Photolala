#!/bin/bash

# Create API Gateway for Apple Sign-In callback

echo "🚀 Creating API Gateway for Apple callback..."

FUNCTION_NAME="photolala-apple-callback"
REGION="us-east-1"
API_NAME="photolala-auth"
STAGE_NAME="prod"

# Get Lambda function ARN
LAMBDA_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --region $REGION --query 'Configuration.FunctionArn' --output text)
echo "Lambda ARN: $LAMBDA_ARN"

# Check if API already exists
API_ID=$(aws apigatewayv2 get-apis --region $REGION --query "Items[?Name=='$API_NAME'].ApiId" --output text)

if [ -z "$API_ID" ]; then
    # Create HTTP API
    echo "Creating new API Gateway..."
    API_ID=$(aws apigatewayv2 create-api \
        --name $API_NAME \
        --protocol-type HTTP \
        --region $REGION \
        --query 'ApiId' \
        --output text)
else
    echo "Using existing API: $API_ID"
fi

# Create or update integration
INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id $API_ID --region $REGION --query "Items[?IntegrationUri=='$LAMBDA_ARN'].IntegrationId" --output text)

if [ -z "$INTEGRATION_ID" ]; then
    echo "Creating Lambda integration..."
    INTEGRATION_ID=$(aws apigatewayv2 create-integration \
        --api-id $API_ID \
        --integration-type AWS_PROXY \
        --integration-uri $LAMBDA_ARN \
        --payload-format-version 2.0 \
        --region $REGION \
        --query 'IntegrationId' \
        --output text)
else
    echo "Using existing integration: $INTEGRATION_ID"
fi

# Create route for Apple callback
ROUTE_ID=$(aws apigatewayv2 get-routes --api-id $API_ID --region $REGION --query "Items[?RouteKey=='POST /auth/apple/callback'].RouteId" --output text)

if [ -z "$ROUTE_ID" ]; then
    echo "Creating POST route..."
    aws apigatewayv2 create-route \
        --api-id $API_ID \
        --route-key 'POST /auth/apple/callback' \
        --target "integrations/$INTEGRATION_ID" \
        --region $REGION
fi

# Also create GET route for testing
ROUTE_ID=$(aws apigatewayv2 get-routes --api-id $API_ID --region $REGION --query "Items[?RouteKey=='GET /auth/apple/callback'].RouteId" --output text)

if [ -z "$ROUTE_ID" ]; then
    echo "Creating GET route..."
    aws apigatewayv2 create-route \
        --api-id $API_ID \
        --route-key 'GET /auth/apple/callback' \
        --target "integrations/$INTEGRATION_ID" \
        --region $REGION
fi

# Create deployment if needed
DEPLOYMENT_ID=$(aws apigatewayv2 get-deployments --api-id $API_ID --region $REGION --query 'Items[0].DeploymentId' --output text)

if [ "$DEPLOYMENT_ID" == "None" ] || [ -z "$DEPLOYMENT_ID" ]; then
    echo "Creating deployment..."
    aws apigatewayv2 create-deployment \
        --api-id $API_ID \
        --region $REGION
fi

# Create or update stage
STAGE_EXISTS=$(aws apigatewayv2 get-stages --api-id $API_ID --region $REGION --query "Items[?StageName=='$STAGE_NAME'].StageName" --output text)

if [ -z "$STAGE_EXISTS" ]; then
    echo "Creating stage..."
    aws apigatewayv2 create-stage \
        --api-id $API_ID \
        --stage-name $STAGE_NAME \
        --auto-deploy \
        --region $REGION
fi

# Add Lambda permission for API Gateway
echo "Adding Lambda permissions..."
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id "apigateway-$API_ID" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:*:$API_ID/*/*" \
    --region $REGION 2>/dev/null || true

# Get the API endpoint
API_ENDPOINT=$(aws apigatewayv2 get-api --api-id $API_ID --region $REGION --query 'ApiEndpoint' --output text)

echo "✅ API Gateway created successfully!"
echo "🌐 API Endpoint: $API_ENDPOINT"
echo "📍 Apple Callback URL: $API_ENDPOINT/auth/apple/callback"
echo ""
echo "📝 Next steps:"
echo "1. Update your Apple Service ID redirect URL to: $API_ENDPOINT/auth/apple/callback"
echo "2. Update REDIRECT_URI in AppleAuthService.kt to: $API_ENDPOINT/auth/apple/callback"
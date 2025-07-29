#!/bin/bash

# Create custom domain for API Gateway

echo "🌐 Setting up custom domain for API Gateway..."

# Configuration
API_ID="kbzojywsa5"
REGION="us-east-1"
DOMAIN_NAME="api.photolala.electricwoods.com"
STAGE_NAME="prod"

# First, we need a certificate. Let's check if one exists
echo "🔍 Checking for existing ACM certificate..."
CERT_ARN=$(aws acm list-certificates --region $REGION \
    --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME' || DomainName=='*.photolala.electricwoods.com' || DomainName=='*.electricwoods.com'].CertificateArn" \
    --output text | head -1)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
    echo "📜 No certificate found. Creating new certificate request..."
    echo ""
    echo "⚠️  IMPORTANT: You'll need to:"
    echo "1. Request a certificate for $DOMAIN_NAME"
    echo "2. Validate domain ownership via DNS or email"
    echo ""
    echo "Run this command to request a certificate:"
    echo "aws acm request-certificate --domain-name $DOMAIN_NAME --validation-method DNS --region $REGION"
    echo ""
    echo "After validation, run this script again."
    exit 1
else
    echo "✅ Found certificate: $CERT_ARN"
fi

# Create custom domain
echo "🔧 Creating custom domain..."
aws apigatewayv2 create-domain-name \
    --domain-name $DOMAIN_NAME \
    --domain-name-configurations CertificateArn=$CERT_ARN \
    --region $REGION 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Custom domain created successfully"
else
    echo "ℹ️  Custom domain might already exist, continuing..."
fi

# Get domain configuration
DOMAIN_CONFIG=$(aws apigatewayv2 get-domain-name --domain-name $DOMAIN_NAME --region $REGION 2>/dev/null)

if [ $? -eq 0 ]; then
    # Extract the API Gateway domain name for CNAME
    API_GATEWAY_DOMAIN=$(echo $DOMAIN_CONFIG | python3 -c "import sys, json; print(json.load(sys.stdin)['DomainNameConfigurations'][0]['ApiGatewayDomainName'])")
    
    echo ""
    echo "📝 Domain Configuration:"
    echo "Domain: $DOMAIN_NAME"
    echo "Target: $API_GATEWAY_DOMAIN"
    
    # Create API mapping
    echo "🔗 Creating API mapping..."
    aws apigatewayv2 create-api-mapping \
        --domain-name $DOMAIN_NAME \
        --api-id $API_ID \
        --stage $STAGE_NAME \
        --api-mapping-key "auth" \
        --region $REGION 2>/dev/null || \
    aws apigatewayv2 update-api-mapping \
        --domain-name $DOMAIN_NAME \
        --api-mapping-id $(aws apigatewayv2 get-api-mappings --domain-name $DOMAIN_NAME --region $REGION --query "Items[0].ApiMappingId" --output text) \
        --api-id $API_ID \
        --stage $STAGE_NAME \
        --api-mapping-key "auth" \
        --region $REGION 2>/dev/null

    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "📌 Next steps:"
    echo "1. Add a CNAME record in your DNS:"
    echo "   Name: api.photolala.electricwoods.com"
    echo "   Value: $API_GATEWAY_DOMAIN"
    echo ""
    echo "2. Once DNS propagates, your Apple callback URL will be:"
    echo "   https://$DOMAIN_NAME/auth/apple/callback"
    echo ""
    echo "3. Update REDIRECT_URI in AppleAuthService.kt to use the new URL"
else
    echo "❌ Failed to get domain configuration"
    exit 1
fi
#!/bin/bash

# Setup Route 53 subdomain for API Gateway

echo "🌐 Setting up photolala.eastlynx.com subdomain..."

# Configuration
DOMAIN="eastlynx.com"
SUBDOMAIN="photolala"
FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
HOSTED_ZONE_ID="Z0931575IRZ1SECWFRLR"
API_ID="kbzojywsa5"
REGION="us-east-1"
STAGE="prod"

# First, request ACM certificate for the subdomain
echo "📜 Checking for SSL certificate..."
CERT_ARN=$(aws acm list-certificates --region $REGION \
    --query "CertificateSummaryList[?DomainName=='$FULL_DOMAIN' || DomainName=='*.$DOMAIN'].CertificateArn" \
    --output text | head -1)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
    echo "🔐 Requesting new SSL certificate for $FULL_DOMAIN..."
    REQUEST_RESULT=$(aws acm request-certificate \
        --domain-name $FULL_DOMAIN \
        --validation-method DNS \
        --region $REGION)
    
    CERT_ARN=$(echo $REQUEST_RESULT | python3 -c "import sys, json; print(json.load(sys.stdin)['CertificateArn'])")
    echo "Certificate ARN: $CERT_ARN"
    
    # Wait a moment for certificate to be ready
    sleep 5
    
    # Get DNS validation records
    echo "🔍 Getting DNS validation records..."
    VALIDATION_OPTIONS=$(aws acm describe-certificate \
        --certificate-arn $CERT_ARN \
        --region $REGION \
        --query 'Certificate.DomainValidationOptions[0].ResourceRecord')
    
    if [ "$VALIDATION_OPTIONS" != "null" ]; then
        DNS_NAME=$(echo $VALIDATION_OPTIONS | python3 -c "import sys, json; print(json.load(sys.stdin)['Name'])")
        DNS_VALUE=$(echo $VALIDATION_OPTIONS | python3 -c "import sys, json; print(json.load(sys.stdin)['Value'])")
        
        echo "📝 Creating DNS validation record..."
        cat > validation-record.json << EOF
{
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "$DNS_NAME",
            "Type": "CNAME",
            "TTL": 300,
            "ResourceRecords": [{"Value": "$DNS_VALUE"}]
        }
    }]
}
EOF
        
        aws route53 change-resource-record-sets \
            --hosted-zone-id $HOSTED_ZONE_ID \
            --change-batch file://validation-record.json
        
        rm validation-record.json
        
        echo "⏳ Waiting for certificate validation (this may take a few minutes)..."
        aws acm wait certificate-validated \
            --certificate-arn $CERT_ARN \
            --region $REGION
    fi
else
    echo "✅ Found existing certificate: $CERT_ARN"
fi

# Create custom domain in API Gateway
echo "🔧 Creating custom domain in API Gateway..."
aws apigatewayv2 create-domain-name \
    --domain-name $FULL_DOMAIN \
    --domain-name-configurations CertificateArn=$CERT_ARN \
    --region $REGION 2>/dev/null

if [ $? -ne 0 ]; then
    echo "ℹ️  Domain might already exist, continuing..."
fi

# Get the API Gateway domain name for the CNAME
DOMAIN_CONFIG=$(aws apigatewayv2 get-domain-name --domain-name $FULL_DOMAIN --region $REGION)
API_GATEWAY_DOMAIN=$(echo $DOMAIN_CONFIG | python3 -c "import sys, json; print(json.load(sys.stdin)['DomainNameConfigurations'][0]['ApiGatewayDomainName'])")

echo "🎯 API Gateway Domain: $API_GATEWAY_DOMAIN"

# Create Route 53 record
echo "📍 Creating Route 53 record..."
cat > route53-record.json << EOF
{
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "$FULL_DOMAIN",
            "Type": "CNAME",
            "TTL": 300,
            "ResourceRecords": [{"Value": "$API_GATEWAY_DOMAIN"}]
        }
    }]
}
EOF

CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file://route53-record.json \
    --query 'ChangeInfo.Id' \
    --output text)

rm route53-record.json

# Create API mapping
echo "🔗 Creating API mapping..."
aws apigatewayv2 create-api-mapping \
    --domain-name $FULL_DOMAIN \
    --api-id $API_ID \
    --stage $STAGE \
    --region $REGION 2>/dev/null || \
aws apigatewayv2 update-api-mapping \
    --domain-name $FULL_DOMAIN \
    --api-mapping-id $(aws apigatewayv2 get-api-mappings --domain-name $FULL_DOMAIN --region $REGION --query "Items[0].ApiMappingId" --output text) \
    --api-id $API_ID \
    --stage $STAGE \
    --region $REGION

echo ""
echo "✅ Setup complete!"
echo ""
echo "🌐 Your new Apple Sign-In callback URL:"
echo "   https://$FULL_DOMAIN/auth/apple/callback"
echo ""
echo "📱 Next steps:"
echo "1. Wait a few minutes for DNS to propagate"
echo "2. Update Apple Service ID redirect URL to: https://$FULL_DOMAIN/auth/apple/callback"
echo "3. Update REDIRECT_URI in AppleAuthService.kt"
echo ""
echo "DNS Change ID: $CHANGE_ID"
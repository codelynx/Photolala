#!/bin/bash

# Create CloudFront distribution with custom domain for cleaner URLs

echo "☁️  Setting up CloudFront distribution..."

REGION="us-east-1"
API_GATEWAY_DOMAIN="kbzojywsa5.execute-api.us-east-1.amazonaws.com"
ORIGIN_PATH="/prod"

# Create CloudFront distribution
cat > cloudfront-config.json << EOF
{
    "CallerReference": "photolala-auth-$(date +%s)",
    "Comment": "Photolala Authentication API",
    "DefaultRootObject": "",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "APIGateway",
                "DomainName": "$API_GATEWAY_DOMAIN",
                "OriginPath": "$ORIGIN_PATH",
                "CustomHeaders": {
                    "Quantity": 0
                },
                "CustomOriginConfig": {
                    "HTTPPort": 80,
                    "HTTPSPort": 443,
                    "OriginProtocolPolicy": "https-only",
                    "OriginSslProtocols": {
                        "Quantity": 3,
                        "Items": ["TLSv1", "TLSv1.1", "TLSv1.2"]
                    },
                    "OriginReadTimeout": 30,
                    "OriginKeepaliveTimeout": 5
                }
            }
        ]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "APIGateway",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 7,
            "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["GET", "HEAD"]
            }
        },
        "ForwardedValues": {
            "QueryString": true,
            "Cookies": {
                "Forward": "all"
            },
            "Headers": {
                "Quantity": 6,
                "Items": ["Accept", "Authorization", "Content-Type", "Origin", "Referer", "User-Agent"]
            }
        },
        "TrustedSigners": {
            "Enabled": false,
            "Quantity": 0
        },
        "MinTTL": 0,
        "DefaultTTL": 0,
        "MaxTTL": 0,
        "Compress": true
    },
    "CacheBehaviors": {
        "Quantity": 0
    },
    "CustomErrorResponses": {
        "Quantity": 0
    },
    "Enabled": true,
    "PriceClass": "PriceClass_100",
    "ViewerCertificate": {
        "CloudFrontDefaultCertificate": true
    }
}
EOF

echo "📝 Creating CloudFront distribution..."
DISTRIBUTION_ID=$(aws cloudfront create-distribution \
    --distribution-config file://cloudfront-config.json \
    --region $REGION \
    --query 'Distribution.Id' \
    --output text)

if [ $? -eq 0 ]; then
    CLOUDFRONT_DOMAIN=$(aws cloudfront get-distribution \
        --id $DISTRIBUTION_ID \
        --region $REGION \
        --query 'Distribution.DomainName' \
        --output text)
    
    echo "✅ CloudFront distribution created!"
    echo "Distribution ID: $DISTRIBUTION_ID"
    echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"
    echo ""
    echo "📌 Option 1 - Use CloudFront domain directly:"
    echo "   URL: https://$CLOUDFRONT_DOMAIN/auth/apple/callback"
    echo ""
    echo "📌 Option 2 - Create a CNAME in your DNS:"
    echo "   Name: auth.photolala.electricwoods.com"
    echo "   Value: $CLOUDFRONT_DOMAIN"
    echo "   Then use: https://auth.photolala.electricwoods.com/auth/apple/callback"
    echo ""
    echo "Note: CloudFront takes 15-20 minutes to deploy globally."
else
    echo "❌ Failed to create CloudFront distribution"
fi

# Clean up
rm -f cloudfront-config.json
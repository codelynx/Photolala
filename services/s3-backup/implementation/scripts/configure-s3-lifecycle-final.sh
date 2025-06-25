#!/bin/bash

# Final S3 Lifecycle Configuration for Photolala
# Based on V5 Pricing Strategy: Universal 180-day archive
# New path structure: photos/, thumbnails/, metadata/

BUCKET_NAME="${PHOTOLALA_BUCKET:-photolala}"
REGION="${AWS_REGION:-us-east-1}"

echo "================================================="
echo "Photolala S3 Lifecycle Configuration"
echo "================================================="
echo ""
echo "Bucket: $BUCKET_NAME"
echo "Region: $REGION"
echo ""
echo "This will configure:"
echo "✅ Photos: Archive to Deep Archive after 180 days"
echo "✅ Thumbnails: Immediate Intelligent-Tiering"
echo "✅ Metadata: Remains in Standard storage"
echo ""
echo "Strategy: Universal 180-day archive for ALL users"
echo "================================================="
echo ""

read -p "Proceed with configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Configuration cancelled."
    exit 1
fi

# Create lifecycle configuration JSON
cat > lifecycle-rules.json <<EOF
{
    "Rules": [
        {
            "ID": "archive-photos-180-days",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "photos/"
            },
            "Transitions": [
                {
                    "Days": 180,
                    "StorageClass": "DEEP_ARCHIVE"
                }
            ]
        },
        {
            "ID": "optimize-thumbnails-immediately",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "thumbnails/"
            },
            "Transitions": [
                {
                    "Days": 0,
                    "StorageClass": "INTELLIGENT_TIERING"
                }
            ]
        },
        {
            "ID": "cleanup-incomplete-multipart-uploads",
            "Status": "Enabled",
            "Filter": {},
            "AbortIncompleteMultipartUpload": {
                "DaysAfterInitiation": 7
            }
        }
    ]
}
EOF

# Apply lifecycle configuration
echo -e "\nApplying lifecycle configuration..."
aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration file://lifecycle-rules.json \
    --region "$REGION"

if [ $? -eq 0 ]; then
    echo "✅ Lifecycle rules configured successfully!"
    
    # Verify the configuration
    echo -e "\nVerifying configuration:"
    echo "========================"
    aws s3api get-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --output table
else
    echo "❌ Failed to configure lifecycle rules"
    rm lifecycle-rules.json
    exit 1
fi

# Clean up
rm lifecycle-rules.json

# Create monitoring script
cat > monitor-lifecycle.sh <<'EOF'
#!/bin/bash
# Monitor Photolala S3 lifecycle transitions

BUCKET="${1:-photolala}"
REGION="${2:-us-east-1}"

echo "Photolala Storage Report"
echo "========================"
echo "Bucket: $BUCKET"
date

# Function to get size by prefix and storage class
get_storage_stats() {
    local prefix=$1
    echo -e "\n$prefix:"
    
    # Get object count and total size
    local stats=$(aws s3api list-objects-v2 \
        --bucket "$BUCKET" \
        --prefix "$prefix" \
        --query "sum(Contents[].Size)" \
        --output text)
    
    if [ "$stats" != "None" ] && [ "$stats" != "null" ]; then
        echo "  Total size: $(numfmt --to=iec-i --suffix=B $stats 2>/dev/null || echo "$stats bytes")"
    fi
    
    # Sample storage classes
    echo "  Storage classes (sample):"
    aws s3api list-objects-v2 \
        --bucket "$BUCKET" \
        --prefix "$prefix" \
        --max-items 100 \
        --query 'Contents[].[StorageClass]' \
        --output text | sort | uniq -c | sed 's/^/    /'
}

# Get stats for each prefix
get_storage_stats "photos/"
get_storage_stats "thumbnails/"
get_storage_stats "metadata/"

# Calculate costs (rough estimate)
echo -e "\nEstimated Monthly Costs:"
echo "========================"
echo "Note: These are rough estimates"
echo "Standard: ~\$0.023/GB"
echo "Intelligent-Tiering: ~\$0.0125/GB"
echo "Deep Archive: ~\$0.00099/GB"
EOF

chmod +x monitor-lifecycle.sh

echo -e "\n📊 Created monitor-lifecycle.sh"
echo "   Run: ./monitor-lifecycle.sh $BUCKET_NAME"

# Create cost calculator
cat > calculate-savings.sh <<'EOF'
#!/bin/bash
# Calculate savings from lifecycle policies

echo "Photolala Lifecycle Savings Calculator"
echo "====================================="
echo ""
echo "Example: 1TB of photos"
echo ""
echo "Without lifecycle (all Standard):"
echo "  1,024 GB × \$0.023 = \$23.55/month"
echo ""
echo "With 180-day lifecycle:"
echo "  4 GB Standard × \$0.023 = \$0.09"
echo "  1,020 GB Deep Archive × \$0.00099 = \$1.01"
echo "  Total: \$1.10/month"
echo ""
echo "Monthly savings: \$22.45 (95% reduction)"
echo "Annual savings: \$269.40"
echo ""
echo "Per user with 1TB:"
echo "  Revenue: \$1.99/month (after Apple's cut: \$1.39)"
echo "  Storage cost: \$1.10/month"
echo "  Gross margin: \$0.29/month (21%)"
EOF

chmod +x calculate-savings.sh

echo "📊 Created calculate-savings.sh"

echo -e "\n✅ Configuration complete!"
echo ""
echo "Summary:"
echo "--------"
echo "• Photos → Deep Archive after 180 days (95% cost reduction)"
echo "• Thumbnails → Intelligent-Tiering immediately (45% cost reduction)"
echo "• Metadata → Standard storage (always accessible)"
echo ""
echo "Next steps:"
echo "1. Update S3BackupService.swift to use new paths"
echo "2. Run ./monitor-lifecycle.sh to track transitions"
echo "3. Set up CloudWatch alarms for cost monitoring"
echo ""
echo "Marketing message:"
echo '"Your last 6 months of photos always at your fingertips!"'
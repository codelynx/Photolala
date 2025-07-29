#!/bin/bash

# Script to check S3 identities folder
# This helps debug authentication issues by showing what identity mappings exist

echo "=== Checking S3 Identity Mappings ==="
echo "Bucket: photolala"
echo "Path: identities/"
echo ""

# List all files in the identities folder
echo "Current identity mappings:"
aws s3 ls s3://photolala/identities/ --recursive | grep -v "/$" | awk '{print $4}'

echo ""
echo "=== Detailed view ==="
# Show the contents of each identity file
for identity in $(aws s3 ls s3://photolala/identities/ --recursive | grep -v "/$" | awk '{print $4}'); do
    echo ""
    echo "Identity: $identity"
    echo -n "Maps to UUID: "
    aws s3 cp "s3://photolala/$identity" - 2>/dev/null || echo "[Error reading file]"
done

echo ""
echo "=== Summary ==="
echo "Total Apple identities: $(aws s3 ls s3://photolala/identities/ --recursive | grep "apple:" | wc -l | tr -d ' ')"
echo "Total Google identities: $(aws s3 ls s3://photolala/identities/ --recursive | grep "google:" | wc -l | tr -d ' ')"
#!/bin/bash

# Script to decode Apple JWT and examine the sub field

if [ $# -eq 0 ]; then
    echo "Usage: $0 <jwt_token>"
    exit 1
fi

JWT=$1

# Split JWT into parts
IFS='.' read -ra PARTS <<< "$JWT"

if [ ${#PARTS[@]} -ne 3 ]; then
    echo "Invalid JWT format - expected 3 parts separated by dots"
    exit 1
fi

echo "=== Decoding Apple JWT ==="
echo ""

# Decode header
echo "Header:"
echo "${PARTS[0]}" | base64 -d 2>/dev/null | python3 -m json.tool || echo "Failed to decode header"
echo ""

# Decode payload
echo "Payload:"
echo "${PARTS[1]}" | base64 -d 2>/dev/null | python3 -m json.tool || echo "Failed to decode payload"
echo ""

# Extract sub field specifically
echo "Extracted 'sub' field:"
echo "${PARTS[1]}" | base64 -d 2>/dev/null | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('sub', 'Not found'))"
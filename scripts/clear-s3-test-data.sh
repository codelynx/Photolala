#!/bin/bash

# Script to clear test data from S3 for fresh authentication testing
# WARNING: This will delete all identity mappings and user data!

echo "=== S3 Test Data Cleanup ==="
echo "WARNING: This will delete all identity mappings and user data!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Current data in S3:"
echo "- Identity mappings:"
aws s3 ls s3://photolala/identities/ --recursive

echo ""
echo "- User folders:"
aws s3 ls s3://photolala/users/ --recursive | head -20

echo ""
read -p "Delete all identity mappings? (yes/no): " delete_identities
if [ "$delete_identities" = "yes" ]; then
    echo "Deleting identity mappings..."
    aws s3 rm s3://photolala/identities/ --recursive
    echo "Identity mappings deleted."
fi

echo ""
read -p "Delete all user folders? (yes/no): " delete_users
if [ "$delete_users" = "yes" ]; then
    echo "Deleting user folders..."
    aws s3 rm s3://photolala/users/ --recursive
    echo "User folders deleted."
fi

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Next steps for testing:"
echo "1. Clear local data on all devices:"
echo "   - iOS/macOS: Sign out or delete app data"
echo "   - Android: Clear app data in Settings"
echo "2. Create a new account on iOS/macOS"
echo "3. Try signing in with the same Apple ID on Android"
echo "4. Both platforms should now use the same Apple ID format (JWT sub)"
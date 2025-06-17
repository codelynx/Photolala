#!/bin/bash

# Configure S3 Lifecycle Rules for Photolala using Lambda-based approach
# This handles the current structure where photos, thumbs, and metadata are all under users/

BUCKET_NAME="${PHOTOLALA_BUCKET:-photolala}"
REGION="${AWS_REGION:-us-east-1}"

echo "Setting up Lambda-based lifecycle management for Photolala"
echo "========================================================="

# Create Lambda function code
cat > photolala-lifecycle-lambda.py <<'EOF'
import boto3
import json
from datetime import datetime, timedelta

s3 = boto3.client('s3')

def lambda_handler(event, context):
    bucket_name = event.get('bucket', 'photolala')
    
    # Process objects that are 180+ days old
    cutoff_date = datetime.now() - timedelta(days=180)
    
    paginator = s3.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=bucket_name, Prefix='users/')
    
    photos_to_archive = []
    
    for page in pages:
        if 'Contents' not in page:
            continue
            
        for obj in page['Contents']:
            key = obj['Key']
            last_modified = obj['LastModified'].replace(tzinfo=None)
            
            # Only process photos (not thumbs or metadata)
            if '/photos/' in key and last_modified < cutoff_date:
                # Check current storage class
                head_obj = s3.head_object(Bucket=bucket_name, Key=key)
                current_class = head_obj.get('StorageClass', 'STANDARD')
                
                if current_class == 'STANDARD':
                    photos_to_archive.append(key)
    
    # Archive photos in batches
    archived_count = 0
    for key in photos_to_archive:
        try:
            # Copy object with new storage class
            copy_source = {'Bucket': bucket_name, 'Key': key}
            s3.copy_object(
                CopySource=copy_source,
                Bucket=bucket_name,
                Key=key,
                StorageClass='DEEP_ARCHIVE',
                MetadataDirective='COPY'
            )
            archived_count += 1
            print(f"Archived: {key}")
        except Exception as e:
            print(f"Error archiving {key}: {str(e)}")
    
    # Also handle thumbnails - move to Intelligent Tiering immediately
    thumb_pages = paginator.paginate(Bucket=bucket_name, Prefix='users/')
    thumbs_optimized = 0
    
    for page in thumb_pages:
        if 'Contents' not in page:
            continue
            
        for obj in page['Contents']:
            key = obj['Key']
            
            if '/thumbs/' in key:
                head_obj = s3.head_object(Bucket=bucket_name, Key=key)
                current_class = head_obj.get('StorageClass', 'STANDARD')
                
                if current_class == 'STANDARD':
                    try:
                        copy_source = {'Bucket': bucket_name, 'Key': key}
                        s3.copy_object(
                            CopySource=copy_source,
                            Bucket=bucket_name,
                            Key=key,
                            StorageClass='INTELLIGENT_TIERING',
                            MetadataDirective='COPY'
                        )
                        thumbs_optimized += 1
                        print(f"Optimized: {key}")
                    except Exception as e:
                        print(f"Error optimizing {key}: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'photos_archived': archived_count,
            'thumbs_optimized': thumbs_optimized,
            'message': f'Processed {archived_count} photos and {thumbs_optimized} thumbnails'
        })
    }
EOF

# Create Lambda execution role policy
cat > lambda-role-policy.json <<EOF
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

# Create Lambda permissions policy
cat > lambda-permissions.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:CopyObject",
                "s3:ListBucket",
                "s3:HeadObject"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}",
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF

echo "Creating Lambda function..."
echo ""
echo "To deploy this Lambda function:"
echo "1. Create IAM role:"
echo "   aws iam create-role --role-name PhotolalaLifecycleRole --assume-role-policy-document file://lambda-role-policy.json"
echo ""
echo "2. Attach permissions:"
echo "   aws iam put-role-policy --role-name PhotolalaLifecycleRole --policy-name S3Access --policy-document file://lambda-permissions.json"
echo ""
echo "3. Package and deploy function:"
echo "   zip photolala-lifecycle.zip photolala-lifecycle-lambda.py"
echo "   aws lambda create-function \\"
echo "     --function-name PhotolalaLifecycle \\"
echo "     --runtime python3.9 \\"
echo "     --role arn:aws:iam::YOUR_ACCOUNT_ID:role/PhotolalaLifecycleRole \\"
echo "     --handler photolala-lifecycle-lambda.lambda_handler \\"
echo "     --zip-file fileb://photolala-lifecycle.zip \\"
echo "     --timeout 300 \\"
echo "     --memory-size 512"
echo ""
echo "4. Create EventBridge rule to run daily:"
echo "   aws events put-rule --name PhotolalaLifecycleDaily --schedule-expression 'rate(1 day)'"
echo ""
echo "5. Add Lambda permission for EventBridge:"
echo "   aws lambda add-permission \\"
echo "     --function-name PhotolalaLifecycle \\"
echo "     --statement-id PhotolalaLifecycleDaily \\"
echo "     --action lambda:InvokeFunction \\"
echo "     --principal events.amazonaws.com"
echo ""
echo "6. Connect rule to Lambda:"
echo "   aws events put-targets --rule PhotolalaLifecycleDaily \\"
echo "     --targets \"Id\"=\"1\",\"Arn\"=\"arn:aws:lambda:${REGION}:YOUR_ACCOUNT_ID:function:PhotolalaLifecycle\""

# Alternative: Simple lifecycle rule that archives everything under users/ except metadata
cat > simple-lifecycle.json <<EOF
{
    "Rules": [
        {
            "ID": "archive-user-content",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "users/"
            },
            "Transitions": [
                {
                    "Days": 180,
                    "StorageClass": "DEEP_ARCHIVE"
                }
            ]
        }
    ]
}
EOF

echo -e "\n\nAlternatively, for a simpler approach that archives everything:"
echo "aws s3api put-bucket-lifecycle-configuration --bucket $BUCKET_NAME --lifecycle-configuration file://simple-lifecycle.json"
echo ""
echo "⚠️  Note: This will also archive metadata files, which may not be desired."
echo "The Lambda approach gives more control over what gets archived."
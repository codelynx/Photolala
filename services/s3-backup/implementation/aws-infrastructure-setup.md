# AWS Infrastructure Setup Guide

This guide walks through setting up the production AWS infrastructure for Photolala's S3 backup service with secure STS token vending.

## Overview

We'll implement a serverless architecture where:
1. Users authenticate with Sign in with Apple
2. Backend service validates the user
3. AWS STS provides temporary, scoped credentials
4. Users directly upload to S3 with their scoped credentials

## Prerequisites

- AWS CLI configured with administrative access
- Domain for API endpoints (e.g., api.photolala.com)
- Apple Developer account for Sign in with Apple

## Step 1: Create S3 Bucket

```bash
# Create the bucket
aws s3api create-bucket \
    --bucket photolala \
    --region us-east-1

# Versioning not needed for this use case
# Skip versioning configuration

# Block public access
aws s3api put-public-access-block \
    --bucket photolala \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

## Step 2: Create IAM Role for STS

Create a role that STS will assume to generate temporary credentials.

### 2.1 Create Trust Policy

Create `trust-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sts.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### 2.2 Create the Role

```bash
aws iam create-role \
    --role-name PhotolalaUserRole \
    --assume-role-policy-document file://trust-policy.json
```

### 2.3 Create Permissions Policy

Create `permissions-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:RestoreObject"
      ],
      "Resource": [
        "arn:aws:s3:::photolala/photos/${aws:userid}/*",
        "arn:aws:s3:::photolala/thumbnails/${aws:userid}/*",
        "arn:aws:s3:::photolala/metadata/${aws:userid}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::photolala",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "photos/${aws:userid}/*",
            "thumbnails/${aws:userid}/*",
            "metadata/${aws:userid}/*"
          ]
        }
      }
    }
  ]
}
```

### 2.4 Attach Policy to Role

```bash
aws iam put-role-policy \
    --role-name PhotolalaUserRole \
    --policy-name PhotolalaUserPolicy \
    --policy-document file://permissions-policy.json
```

## Step 3: Create IAM User for Backend Service

The backend service needs permissions to assume roles on behalf of users.

```bash
# Create the user
aws iam create-user --user-name photolala-backend

# Create access key
aws iam create-access-key --user-name photolala-backend > backend-credentials.json

# Create and attach policy
cat > backend-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "arn:aws:iam::*:role/PhotolalaUserRole"
    },
    {
      "Effect": "Allow", 
      "Action": [
        "sts:TagSession"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-user-policy \
    --user-name photolala-backend \
    --policy-name PhotolalaBackendPolicy \
    --policy-document file://backend-policy.json
```

## Step 4: Configure S3 Lifecycle Rules

Run the lifecycle configuration script:

```bash
cd /Users/kyoshikawa/Projects/Photolala/services/s3-backup/implementation/scripts
./configure-s3-lifecycle-final.sh
```

## Step 5: Set Up Backend Service (Swift/Vapor)

### 5.1 Environment Variables

Set these in your backend deployment:

```bash
AWS_ACCESS_KEY_ID=<from backend-credentials.json>
AWS_SECRET_ACCESS_KEY=<from backend-credentials.json>
AWS_REGION=us-east-1
PHOTOLALA_ROLE_ARN=arn:aws:iam::YOUR_ACCOUNT_ID:role/PhotolalaUserRole
```

### 5.2 Deploy Backend

The backend service (from iam-and-authentication-architecture.md) handles:
- Sign in with Apple validation
- STS token generation
- Usage tracking
- Subscription verification

## Step 6: CloudFormation Template (Optional)

For repeatable deployments, create `photolala-infrastructure.yaml`:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Photolala S3 Backup Service Infrastructure'

Parameters:
  BucketName:
    Type: String
    Default: photolala
    Description: S3 bucket name for photo storage

Resources:
  PhotolalaBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      LifecycleConfiguration:
        Rules:
          - Id: archive-photos-180-days
            Status: Enabled
            Prefix: photos/
            Transitions:
              - StorageClass: DEEP_ARCHIVE
                TransitionInDays: 180
          - Id: optimize-thumbnails
            Status: Enabled
            Prefix: thumbnails/
            Transitions:
              - StorageClass: INTELLIGENT_TIERING
                TransitionInDays: 0

  PhotolalaUserRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: PhotolalaUserRole
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: sts.amazonaws.com
            Action: sts:AssumeRole
          - Effect: Allow
            Principal:
              AWS: !Sub 'arn:aws:iam::${AWS::AccountId}:root'
            Action: sts:AssumeRole
      Policies:
        - PolicyName: PhotolalaUserPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                  - s3:DeleteObject
                  - s3:RestoreObject
                Resource:
                  - !Sub 'arn:aws:s3:::${BucketName}/photos/${!aws:userid}/*'
                  - !Sub 'arn:aws:s3:::${BucketName}/thumbnails/${!aws:userid}/*'
                  - !Sub 'arn:aws:s3:::${BucketName}/metadata/${!aws:userid}/*'
              - Effect: Allow
                Action: s3:ListBucket
                Resource: !Sub 'arn:aws:s3:::${BucketName}'
                Condition:
                  StringLike:
                    s3:prefix:
                      - 'photos/${aws:userid}/*'
                      - 'thumbnails/${aws:userid}/*'
                      - 'metadata/${aws:userid}/*'

  BackendUser:
    Type: AWS::IAM::User
    Properties:
      UserName: photolala-backend
      Policies:
        - PolicyName: PhotolalaBackendPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - sts:AssumeRole
                Resource: !GetAtt PhotolalaUserRole.Arn
              - Effect: Allow
                Action:
                  - sts:TagSession
                Resource: '*'

Outputs:
  BucketName:
    Description: S3 bucket name
    Value: !Ref PhotolalaBucket
  UserRoleArn:
    Description: ARN of the user role for STS
    Value: !GetAtt PhotolalaUserRole.Arn
  BackendUserArn:
    Description: ARN of the backend service user
    Value: !GetAtt BackendUser.Arn
```

Deploy with:
```bash
aws cloudformation create-stack \
    --stack-name photolala-infrastructure \
    --template-body file://photolala-infrastructure.yaml \
    --capabilities CAPABILITY_NAMED_IAM
```

## Step 7: Testing

### 7.1 Test STS Token Generation

```bash
# Assume role as backend service
aws sts assume-role \
    --role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/PhotolalaUserRole \
    --role-session-name test-user-123 \
    --duration-seconds 3600 \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": ["s3:GetObject", "s3:PutObject"],
            "Resource": [
                "arn:aws:s3:::photolala/photos/test-user-123/*",
                "arn:aws:s3:::photolala/thumbnails/test-user-123/*",
                "arn:aws:s3:::photolala/metadata/test-user-123/*"
            ]
        }]
    }'
```

### 7.2 Test S3 Access with Temporary Credentials

Use the credentials from the assume-role response to test S3 access.

## Step 8: Security Checklist

- [ ] S3 bucket has public access blocked
- [ ] IAM roles use least-privilege permissions
- [ ] Backend service credentials are stored securely
- [ ] HTTPS is enforced for all API endpoints
- [ ] CloudTrail logging is enabled
- [ ] S3 access logging is enabled
- [ ] Regular security audits scheduled

## Step 9: Monitoring Setup

### 9.1 CloudWatch Alarms

Create alarms for:
- High S3 request rates
- Failed STS assume role attempts
- S3 access denied errors
- Unusual data transfer patterns

### 9.2 Cost Monitoring

Set up billing alerts for:
- Total AWS costs exceeding threshold
- S3 storage costs
- Data transfer costs
- STS API call costs

## Production Readiness Checklist

- [ ] All resources created successfully
- [ ] Backend service deployed and tested
- [ ] Monitoring and alarms configured
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] Disaster recovery plan in place
- [ ] Cost optimization reviewed

## Next Steps

1. Deploy backend service to production
2. Configure DNS for API endpoints
3. Set up SSL certificates
4. Enable CloudFront for API (optional)
5. Configure auto-scaling for backend
6. Set up backup and disaster recovery
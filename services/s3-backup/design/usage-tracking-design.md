# Usage Tracking Backend Services Design

## Overview

This document outlines the design for backend services that track user storage usage and enforce subscription limits for the Photolala S3 backup service.

## Requirements

1. **Track Storage Usage**
   - Monitor total storage per user (Standard + Deep Archive)
   - Track number of files backed up
   - Monitor retrieval usage (for future pricing tiers)

2. **Enforce Limits**
   - Prevent uploads when user exceeds subscription limit
   - Grace period for users who downgrade
   - Clear messaging about usage and limits

3. **Performance**
   - Minimal latency impact on backup operations
   - Efficient storage of usage data
   - Scalable to handle growth

## Architecture

### Option 1: Lambda + DynamoDB (Recommended)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────▶│  API Gateway │────▶│   Lambda    │
└─────────────┘     └─────────────┘     └─────────────┘
                                                │
                                                ▼
                                         ┌─────────────┐
                                         │  DynamoDB   │
                                         └─────────────┘
```

**Components:**
- **API Gateway**: REST API endpoints
- **Lambda Functions**: Business logic
- **DynamoDB**: Usage data storage
- **EventBridge**: S3 event processing
- **CloudWatch**: Monitoring and alerts

### Option 2: Serverless Framework

Use AWS SAM or Serverless Framework for easier deployment and management.

## Data Model

### DynamoDB Tables

#### UsageTracking Table
```
PK: USER#{apple_user_id}
SK: USAGE#CURRENT

Attributes:
- totalStorageBytes: Number
- standardStorageBytes: Number
- deepArchiveStorageBytes: Number
- fileCount: Number
- lastUpdated: ISO8601 timestamp
- subscriptionTier: String (personal/family)
- subscriptionLimit: Number (bytes)
```

#### UsageHistory Table (for billing/analytics)
```
PK: USER#{apple_user_id}
SK: HISTORY#{yyyy-mm}

Attributes:
- month: String (yyyy-mm)
- dailySnapshots: Map of day -> usage
- peakUsage: Number
- averageUsage: Number
```

## API Endpoints

### 1. Check Usage
```
GET /api/usage/{userId}

Response:
{
  "userId": "apple_123456",
  "usage": {
    "totalBytes": 1500000000000,  // 1.5TB
    "standardBytes": 500000000000,  // 500GB
    "deepArchiveBytes": 1000000000000,  // 1TB
    "fileCount": 150000
  },
  "subscription": {
    "tier": "personal",
    "limitBytes": 2000000000000,  // 2TB
    "percentUsed": 75
  },
  "canUpload": true
}
```

### 2. Update Usage (Internal)
```
POST /internal/usage/update

Body:
{
  "userId": "apple_123456",
  "operation": "add|remove",
  "bytes": 1048576,
  "storageClass": "STANDARD|DEEP_ARCHIVE"
}
```

### 3. Pre-upload Check
```
POST /api/usage/check-upload

Body:
{
  "userId": "apple_123456",
  "estimatedBytes": 1048576
}

Response:
{
  "allowed": true,
  "remainingBytes": 500000000000,
  "message": null
}
```

## Implementation Plan

### Phase 1: Core Infrastructure
1. Set up DynamoDB tables
2. Create Lambda functions
3. Configure API Gateway
4. Set up IAM roles and permissions

### Phase 2: S3 Integration
1. Configure S3 Event Notifications
2. Create Lambda for processing S3 events
3. Implement usage calculation logic
4. Handle file overwrites and deletions

### Phase 3: Client Integration
1. Update iOS client to check usage before upload
2. Add usage display in app
3. Implement upload blocking when over limit
4. Add user notifications

### Phase 4: Monitoring
1. Set up CloudWatch dashboards
2. Configure usage alerts
3. Add cost monitoring
4. Implement anomaly detection

## S3 Event Processing

### Lambda Function: ProcessS3Event
```python
import json
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('UsageTracking')

def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        size = record['s3']['object']['size']
        event_name = record['eventName']
        
        # Extract user ID from S3 key
        # Format: users/{apple_user_id}/photos/{hash}
        parts = key.split('/')
        if len(parts) >= 2 and parts[0] == 'users':
            user_id = parts[1]
            
            if 'ObjectCreated' in event_name:
                update_usage(user_id, size, 'add')
            elif 'ObjectRemoved' in event_name:
                update_usage(user_id, size, 'remove')
                
    return {'statusCode': 200}

def update_usage(user_id, size, operation):
    # Update usage in DynamoDB
    # Handle concurrent updates with conditional expressions
    pass
```

## Cost Optimization

1. **DynamoDB On-Demand**: Start with on-demand pricing
2. **Lambda Reserved Concurrency**: Set limits to control costs
3. **API Gateway Caching**: Cache usage checks for 60 seconds
4. **S3 Event Filtering**: Only process relevant events

## Security Considerations

1. **Authentication**: Validate Apple JWT tokens
2. **Authorization**: Users can only access their own usage
3. **Rate Limiting**: Prevent abuse of API endpoints
4. **Encryption**: Encrypt data at rest and in transit

## Monitoring and Alerts

### CloudWatch Alarms
1. High usage rate (>90% of limit)
2. Rapid usage increase (>10GB/hour)
3. Failed uploads due to limit
4. API errors or high latency

### Metrics to Track
- Total users
- Storage per tier
- Upload success/failure rate
- API latency (p50, p90, p99)
- Cost per user

## Future Enhancements

1. **Usage Predictions**: ML model to predict when users will hit limits
2. **Automated Archiving**: Move old photos to Deep Archive automatically
3. **Usage Reports**: Monthly email summaries
4. **Admin Dashboard**: Web interface for support team

## Development Tasks

1. Create AWS infrastructure (DynamoDB, Lambda, API Gateway)
2. Implement Lambda functions for usage tracking
3. Set up S3 event notifications
4. Create API endpoints
5. Add authentication/authorization
6. Integrate with iOS client
7. Add monitoring and alerts
8. Create admin tools
9. Load testing and optimization
10. Documentation

## Estimated Timeline

- Week 1-2: Infrastructure setup and core Lambda functions
- Week 3: S3 integration and event processing
- Week 4: Client integration and testing
- Week 5: Monitoring, alerts, and optimization
- Week 6: Documentation and deployment
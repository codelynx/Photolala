# Photolala Account Deletion Infrastructure

## Overview

Account deletion system using **S3 Batch Operations** for large-scale deletions. No Docker containers or AWS Batch required - just Lambda and S3's built-in batch processing.

## Architecture

```
iOS/macOS App
     ↓
Lambda Function
     ↓
┌──────────────────────┬────────────────────────┐
│ Small Accounts       │ Large Accounts         │
│ (<1000 objects)      │ (>1000 objects)        │
│                      │                        │
│ Direct S3 Deletion   │ S3 Batch Operations    │
│ (immediate)          │ (async job)            │
└──────────────────────┴────────────────────────┘
```

## Components

### 1. Lambda Function (`lambda/deletion/handler.py`)
- Processes scheduled deletions based on grace periods
- Handles immediate deletion requests (development only)
- Routes to appropriate deletion method based on object count
- Creates S3 Batch Operations jobs for large accounts

### 2. S3 Batch Operations
- Built-in S3 service (no containers needed)
- Handles millions of objects efficiently
- Provides job status tracking
- Generates completion reports

### 3. EventBridge Schedule
- Triggers Lambda on environment-specific schedule
- Development: Every 5 minutes
- Staging/Production: Daily at 2 AM UTC

## Environment Configuration

| Environment | Grace Period | Schedule | Batch Threshold |
|-------------|-------------|----------|-----------------|
| Development | 3 minutes | Every 5 min | >1000 objects |
| Staging | 3 days | Daily 2 AM | >1000 objects |
| Production | 30 days | Daily 2 AM | >1000 objects |

## Setup

### Quick Setup

```bash
# Run setup script for your environment
./setup.sh development   # or staging, production

# This creates:
# - IAM roles for Lambda and S3 Batch
# - Lambda function
# - EventBridge schedule
# - S3 directories for batch jobs
```

### Manual Setup

1. **Create IAM Roles**
   ```bash
   # S3 Batch Operations role
   aws iam create-role --role-name S3BatchOperationsRole \
     --assume-role-policy-document file://iam/s3-batch-operations-role.json

   # Lambda execution role
   aws iam create-role --role-name PhotolalaDeletionLambdaRole \
     --assume-role-policy-document file://iam/lambda-deletion-role.json
   ```

2. **Deploy Lambda**
   ```bash
   cd lambda/deletion
   zip function.zip handler.py

   aws lambda create-function \
     --function-name photolala-deletion-development \
     --runtime python3.11 \
     --handler handler.handler \
     --role arn:aws:iam::ACCOUNT:role/PhotolalaDeletionLambdaRole \
     --zip-file fileb://function.zip
   ```

3. **Create EventBridge Rule**
   ```bash
   aws events put-rule \
     --name photolala-deletion-schedule \
     --schedule-expression "rate(5 minutes)"
   ```

## Testing

### Test Scheduled Deletion Processing
```bash
aws lambda invoke \
  --function-name photolala-deletion-development \
  --payload '{"type":"scheduled"}' \
  response.json

cat response.json | jq .
```

### Test Immediate Deletion (Dev Only)
```bash
aws lambda invoke \
  --function-name photolala-deletion-development \
  --payload '{"type":"immediate","userId":"test-user-123"}' \
  response.json
```

### Check Batch Job Status
```bash
aws lambda invoke \
  --function-name photolala-deletion-development \
  --payload '{"type":"status","jobId":"abc-123-def"}' \
  response.json
```

## Integration with Swift App

```swift
import AWSLambda

class DeletionService {
    let lambda = try LambdaClient(region: .usEast1)

    func deleteAccountImmediately(userId: String) async throws -> DeletionResult {
        let payload = DeleteRequest(type: "immediate", userId: userId)

        let request = InvokeRequest(
            functionName: "photolala-deletion-\(environment)",
            payload: try JSONEncoder().encode(payload)
        )

        let response = try await lambda.invoke(request)
        return try JSONDecoder().decode(DeletionResult.self, from: response.payload!)
    }

    func checkBatchJobStatus(jobId: String) async throws -> JobStatus {
        let payload = StatusRequest(type: "status", jobId: jobId)

        let request = InvokeRequest(
            functionName: "photolala-deletion-\(environment)",
            payload: try JSONEncoder().encode(payload)
        )

        let response = try await lambda.invoke(request)
        return try JSONDecoder().decode(JobStatus.self, from: response.payload!)
    }
}
```

## Response Formats

### Direct Deletion (Small Accounts)
```json
{
  "status": "completed",
  "userId": "user-123",
  "objectCount": 500,
  "deletedCount": 500,
  "method": "direct",
  "message": "Account deleted successfully"
}
```

### Batch Job Created (Large Accounts)
```json
{
  "status": "batch_job_created",
  "userId": "user-123",
  "jobId": "f4d7e3b2-1234-5678-90ab-cdef12345678",
  "objectCount": 50000,
  "method": "batch",
  "message": "Batch job created for 50000 objects"
}
```

### Job Status Response
```json
{
  "jobId": "f4d7e3b2-1234-5678-90ab-cdef12345678",
  "status": "Complete",
  "progressSummary": {
    "totalTasks": 50000,
    "succeeded": 50000,
    "failed": 0
  }
}
```

## Data Deletion Scope

The system deletes:
- `photos/{userId}/` - Original photos
- `thumbnails/{userId}/` - Generated thumbnails
- `catalogs/{userId}/` - Photo catalogs
- `users/{userId}/` - User profile and status
- `identities/{provider}/{id}` - Identity mappings
- `scheduled-deletions/` - Deletion schedule entries

## Monitoring

### CloudWatch Logs
- Lambda logs: `/aws/lambda/photolala-deletion-{environment}`
- Monitor for errors, timeouts, batch job creation

### CloudWatch Metrics
- Lambda invocations, errors, duration
- S3 Batch Operations job success/failure rates

### S3 Batch Job Reports
- Stored in: `s3://photolala-{env}/batch-jobs/reports/`
- Contains details of failed deletions (if any)

## Cost Optimization

### Estimated Costs
- **Lambda**: ~$0.20 per 1M requests
- **S3 DELETE operations**: ~$0.005 per 1000 requests
- **S3 Batch Operations**: $0.25 per job + $1.00 per million objects processed
- **EventBridge**: Free for scheduled rules

### Example Monthly Cost (100 deletions)
- 50 small accounts (direct): $0.01
- 50 large accounts (batch): $12.50 + $0.50 = $13.00
- **Total**: ~$13 per month

## Troubleshooting

### Lambda Timeout
- Reduce DELETION_THRESHOLD to use batch jobs more often
- Default is 1000 objects, try 500 for faster Lambda execution

### S3 Batch Job Not Starting
- Verify S3BatchOperationsRole has correct permissions
- Check manifest file exists and is valid CSV format
- Ensure Lambda can pass role to S3 Batch Operations

### Objects Not Being Deleted
- Check S3 Batch job reports for errors
- Verify objects aren't in Glacier/Deep Archive
- Check IAM permissions for delete operations

### No Scheduled Deletions Processing
- Verify EventBridge rule is ENABLED
- Check Lambda has permission from EventBridge
- Look for scheduled deletion files in correct date prefix

## Security

- Lambda never exposes batch job details to client
- Client can only invoke Lambda, not S3 directly
- All deletions logged to CloudWatch
- Batch jobs require specific IAM role
- Grace periods enforced server-side

## Limitations

- S3 Batch Operations has regional availability
- Maximum 1000 objects per direct delete request
- Lambda 15-minute timeout (handled by routing to batch)
- Batch jobs may take time to start (usually <5 minutes)
# Simple Lambda-Only Setup (No Docker, No CloudFormation)

This is a simplified approach using only Lambda and EventBridge, without AWS Batch or CloudFormation.

## Architecture

```
iOS/macOS App
    ↓ (aws-sdk-swift)
Lambda Function
    ↓
S3 Direct Deletion (small accounts)
    OR
S3 Batch Operations (large accounts - built-in S3 feature, no Docker)
```

## Manual Setup Steps

### 1. Create IAM Role for Lambda

Go to IAM Console → Roles → Create Role:

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
```

**Attach Policies**:
- `AWSLambdaBasicExecutionRole` (AWS managed)
- Create custom policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::photolala-*",
        "arn:aws:s3:::photolala-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateJob",
        "s3:DescribeJob",
        "s3:ListJobs"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. Create Lambda Function

1. Go to Lambda Console → Create Function
2. Name: `photolala-deletion-{environment}`
3. Runtime: Python 3.11
4. Role: Use the role created above
5. Timeout: 15 minutes (maximum)
6. Memory: 1024 MB
7. Environment Variables:
   - `ENVIRONMENT`: development/staging/production
   - `BUCKET_NAME`: photolala-dev/stage/prod

### 3. Upload Lambda Code

```bash
# Package the function
cd lambda/simple-deletion
zip function.zip handler.py

# Upload via AWS CLI
aws lambda update-function-code \
  --function-name photolala-deletion-development \
  --zip-file fileb://function.zip
```

Or upload `handler.py` directly in Lambda console editor.

### 4. Create EventBridge Rule (Optional)

For scheduled deletions:

1. Go to EventBridge → Rules → Create Rule
2. Name: `photolala-deletion-schedule`
3. Schedule expression:
   - Development: `rate(5 minutes)`
   - Staging/Production: `cron(0 2 * * ? *)` (2 AM daily)
4. Target: Lambda function created above
5. Input: `{"type": "scheduled"}`

### 5. Test from Swift App

```swift
import AWSLambda

let lambda = try LambdaClient(region: .usEast1)

// Immediate deletion (dev only)
let request = InvokeRequest(
    functionName: "photolala-deletion-development",
    invocationType: .requestResponse,
    payload: """
    {
        "type": "immediate",
        "userId": "test-user-123"
    }
    """.data(using: .utf8)
)

let response = try await lambda.invoke(request)
let result = String(data: response.payload!, encoding: .utf8)
print(result)
```

## Usage

### From iOS/macOS App

```swift
// In your DeletionScheduler or AccountManager
func deleteAccountImmediately(userId: String) async throws {
    let lambda = try LambdaClient(region: .usEast1)

    let payload = [
        "type": "immediate",
        "userId": userId
    ]

    let request = InvokeRequest(
        functionName: "photolala-deletion-\(environment)",
        payload: try JSONEncoder().encode(payload)
    )

    let response = try await lambda.invoke(request)
    // Handle response
}
```

### Check Job Status (for large deletions)

```swift
func checkDeletionStatus(jobId: String) async throws -> DeletionStatus {
    let lambda = try LambdaClient(region: .usEast1)

    let payload = [
        "type": "status",
        "jobId": jobId
    ]

    let request = InvokeRequest(
        functionName: "photolala-deletion-\(environment)",
        payload: try JSONEncoder().encode(payload)
    )

    let response = try await lambda.invoke(request)
    // Parse response for job status
}
```

## Lambda Response Format

### Small Account (Direct Deletion)
```json
{
  "status": "deleted",
  "objectCount": 456,
  "message": "Account deleted successfully"
}
```

### Large Account (S3 Batch Operations)
```json
{
  "status": "batch_job_created",
  "jobId": "abc-123-def",
  "objectCount": 50000,
  "message": "Large deletion started. Check status with jobId."
}
```

### Job Status Check
```json
{
  "jobId": "abc-123-def",
  "status": "Complete",
  "progressSummary": {
    "TotalNumberOfTasks": 50000,
    "NumberOfTasksSucceeded": 50000,
    "NumberOfTasksFailed": 0
  }
}
```

## Monitoring

View logs in CloudWatch:
- Log group: `/aws/lambda/photolala-deletion-{environment}`

## Cost Estimate

- **Lambda**: ~$0.20 per 1 million requests
- **S3 Operations**: ~$0.005 per 1,000 DELETE requests
- **S3 Batch Operations**: ~$0.25 per job + $1.00 per million objects
- **EventBridge**: Free tier covers scheduled rules

For typical usage (100 deletions/month):
- Total cost: < $1/month

## Advantages of This Approach

1. **No Docker/Container complexity**
2. **No CloudFormation maintenance**
3. **Simple debugging** - just look at Lambda logs
4. **Fast deployment** - just update Lambda code
5. **Lower costs** - no Batch compute environment
6. **Works with existing IAM** - uses app's STS credentials

## Limitations

- Lambda 15-minute timeout (but S3 Batch Operations handles large jobs)
- No parallel processing like AWS Batch (but S3 Batch Operations is parallel)
- Manual infrastructure setup (but it's one-time and simple)

## Troubleshooting

### Lambda Timeout
- Reduce the threshold for using S3 Batch Operations (e.g., >500 objects instead of >1000)

### Permission Errors
- Check Lambda execution role has S3 permissions
- Verify bucket name in environment variables

### S3 Batch Operations Not Available
- Not all regions support it - use us-east-1, us-west-2, eu-west-1
- For small accounts (<1000 objects), direct deletion works fine
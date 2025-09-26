# S3 Batch Operations for Account Deletion (IMPLEMENTED)

**Status**: ✅ Fully implemented in production

## Current Limitation
Direct S3 deletion from the app works but has limitations:
- Lambda 15-minute timeout for large accounts (100K+ objects)
- No progress tracking for long operations
- Can't leverage batch infrastructure we'll need for production

## Proposed Approach: Immediate Batch Job

### Option 1: Direct Batch Job Creation (Not Feasible)
- iOS client STS credentials don't include AWS Batch permissions
- Would require significant IAM changes

### Option 2: Lambda-Triggered Batch Job (Recommended)
```
App → Lambda → AWS Batch Job → S3 Deletion
```

**Benefits:**
- Tests the exact same batch infrastructure as scheduled deletions
- No timeout issues (batch jobs can run for hours)
- Progress tracking via batch job status
- Reuses production deletion logic

**Implementation:**
1. Create deletion Lambda that triggers batch jobs
2. For "Delete Now": Lambda creates immediate batch job
3. For scheduled: EventBridge triggers same Lambda daily
4. Batch job handles actual S3 operations

### Lambda Function
```python
def handler(event, context):
    deletion_type = event.get('type')  # 'immediate' or 'scheduled'

    if deletion_type == 'immediate':
        user_id = event['userId']
        # Create batch job for single user
        submit_batch_job([user_id])
    else:
        # Process scheduled deletions for today
        users_to_delete = get_scheduled_deletions_for_today()
        if users_to_delete:
            submit_batch_job(users_to_delete)
```

### Batch Job Definition
- Container with AWS CLI or SDK
- Script to delete all prefixes for given user IDs
- Handles Deep Archive objects without retrieval
- Progress reporting to CloudWatch

### Benefits for Development
1. **Immediate feedback** - Test deletion logic without waiting
2. **Production-ready** - Same code path as scheduled deletions
3. **Scalable** - Works for 10 objects or 10 million
4. **Observable** - Batch console shows progress

## Current Implementation

The system now uses a hybrid approach implemented in `aws/lambda/deletion/handler.py`:

### Deletion Strategy
- **Small accounts (<1000 objects)**: Direct deletion via Lambda
- **Large accounts (≥1000 objects)**: S3 Batch Operations job
- **Threshold**: 1000 objects (configurable via DELETION_THRESHOLD)

### Implementation Details
- Lambda function: `photolala-deletion-{environment}`
- Handles both immediate (dev) and scheduled deletions
- Identity mappings cleaned up immediately (allows re-registration)
- See `aws/lambda/deletion/handler.py` for full implementation

### Benefits Achieved
1. **No timeout issues** - Batch jobs handle millions of objects
2. **Progress tracking** - Via S3 Batch job status
3. **Production-ready** - Same code path for all environments
4. **Cost-efficient** - ~$0.25 per batch job for 100K objects
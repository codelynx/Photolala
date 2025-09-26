# AWS Batch for Immediate Deletion (Dev Testing)

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

## Simple Alternative (Current Implementation)

For now, we're using `deleteAllUserData` directly from the app, which:
- Works fine for typical accounts (<10K objects)
- Provides immediate deletion in dev
- Avoids additional Lambda complexity

If we encounter timeout issues or need better progress tracking, implementing the batch approach would be the next step.
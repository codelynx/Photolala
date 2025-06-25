# S3 Lifecycle Rules Configuration Guide

This guide walks through setting up S3 lifecycle rules in the AWS Console to automatically archive photos after 6 months.

## Prerequisites

- AWS account with S3 access
- S3 bucket created for Photolala (e.g., `photolala`)
- AWS Console access

## Step-by-Step Configuration

### 1. Navigate to S3 Console

1. Log into AWS Console
2. Go to S3 service
3. Click on your Photolala bucket (e.g., `photolala`)

### 2. Access Lifecycle Rules

1. Click on the "Management" tab
2. Scroll down to "Lifecycle rules" section
3. Click "Create lifecycle rule"

### 3. Configure Rule for User Photos

#### Rule 1: Archive User Photos After 6 Months

**Name**: `archive-user-photos`

**Rule scope**:
- Choose "Limit the scope of this rule using one or more filters"
- Prefix: `photos/`
- This will match all user photo files

**Lifecycle rule actions**:
- ✅ Transition current versions of objects between storage classes
- ❌ Transition previous versions of objects between storage classes
- ❌ Expire current versions of objects
- ❌ Permanently delete previous versions of objects
- ❌ Delete expired object delete markers or incomplete multipart uploads

**Transitions**:
- Days after object creation: `180` (6 months)
- Storage class: `Deep Archive`

### 4. Configure Rule for Metadata (Keep in Standard)

#### Rule 2: Keep Metadata Accessible

**Name**: `keep-metadata-standard`

**Rule scope**:
- Prefix: `metadata/`

**Lifecycle rule actions**:
- No transitions needed (metadata stays in STANDARD storage)
- This rule ensures metadata is always quickly accessible

### 5. Configure Rule for Thumbnails

#### Rule 3: Intelligent Tiering for Thumbnails

**Name**: `optimize-thumbnails`

**Rule scope**:
- Prefix: `thumbnails/`

**Lifecycle rule actions**:
- ✅ Transition current versions of objects between storage classes

**Transitions**:
- Days after object creation: `0`
- Storage class: `Intelligent-Tiering`
- This automatically moves thumbnails between frequent and infrequent access tiers based on usage

### 6. Review and Create

1. Review all three rules
2. Ensure prefixes don't overlap
3. Click "Create rule" for each

## Expected Behavior

### Photo Lifecycle

1. **Days 0-180**: Photos remain in STANDARD storage
   - Immediate access
   - Higher storage cost
   - No retrieval fees

2. **Day 180+**: Photos automatically move to DEEP_ARCHIVE
   - 90% cost reduction
   - 12-48 hour retrieval time
   - Retrieval fees apply

### Cost Impact

For a typical user with 1TB of photos:
- **Before archival**: ~$23/month (STANDARD)
- **After archival**: ~$1/month (DEEP_ARCHIVE)
- **Savings**: ~$22/month (95% reduction)

## Monitoring

### CloudWatch Metrics

Monitor these metrics after enabling lifecycle rules:
- `NumberOfObjects` by storage class
- `BucketSizeBytes` by storage class
- Lifecycle transition events

### S3 Storage Class Analysis

1. Enable Storage Class Analysis for the bucket
2. Wait 30 days for initial data
3. Review recommendations for optimization

## Testing

### Verify Rules are Working

1. Upload a test photo with a specific prefix
2. Use AWS CLI to check storage class:
   ```bash
   aws s3api head-object --bucket photolala \
     --key users/test-user/photos/test.jpg
   ```
3. Check `StorageClass` field in response

### Force Transition (Testing Only)

For testing, you can create a rule with 1-day transition:
1. Create test rule with 1-day transition
2. Upload test files
3. Wait 24 hours
4. Verify files moved to Deep Archive
5. Delete test rule after verification

## Important Considerations

### Minimum Storage Duration

- Deep Archive has a 180-day minimum storage duration
- Early deletion incurs charges for the full 180 days
- Plan lifecycle transitions accordingly

### Retrieval Costs

Inform users about retrieval costs:
- Standard retrieval: $0.025/GB (12-48 hours)
- Expedited retrieval: $0.10/GB (5-12 hours)

### Metadata Importance

Keep metadata in STANDARD storage because:
- Enables search without retrieving photos
- Negligible cost (KB-sized files)
- Required for app functionality

## Rollback Plan

If issues arise:
1. Disable lifecycle rules immediately
2. New uploads will stay in STANDARD
3. Already transitioned objects remain in Deep Archive
4. Can create reverse rules to move back if needed (incurs costs)

## Next Steps

After configuring lifecycle rules:
1. Update app to show archive status (✅ already implemented)
2. Implement retrieval UI (✅ already implemented)
3. Set up CloudWatch alarms for monitoring
4. Document user communication about archival

## Related Documentation

- [AWS S3 Lifecycle Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [S3 Storage Classes](https://aws.amazon.com/s3/storage-classes/)
- [Deep Archive Pricing](https://aws.amazon.com/s3/pricing/)
# Testing Account Deletion Feature

## Prerequisites

1. **Build and run the app in development mode**
```bash
cd apple
open Photolala.xcodeproj
# Select development scheme
# Build and run (⌘R)
```

2. **Verify environment is set to development**
- In app: Settings → Developer → Environment → Development
- This enables 3-minute grace period and "Delete Now" option

## Test Scenarios

### 1. Basic Account Deletion Flow (iOS/macOS App)

#### A. Schedule Deletion with Grace Period
1. Sign in to the app with Apple ID or Google
2. Go to Settings → Account
3. Tap "Delete Account" (red button in Danger Zone)
4. In AccountDeletionView:
   - Review deletion information
   - Tap "Schedule Deletion" (red button)
   - Confirm in the dialog
5. Verify:
   - ✅ Success message shows deletion date (3 minutes from now)
   - ✅ Account status changes to "scheduled_for_deletion"
   - ✅ Countdown timer appears in AccountSettingsView

#### B. Test Immediate Deletion (Dev Only)
1. From AccountDeletionView:
   - Tap "Delete Now (Dev Only)" (orange button)
   - Confirm immediate deletion
2. Verify:
   - ✅ Account data deleted from S3
   - ✅ Signed out automatically
   - ✅ Can create new account with same Apple ID

#### C. Test Cancellation
1. Schedule deletion (step A above)
2. While countdown is active:
   - Tap "Cancel Deletion" in the warning banner
   - Confirm cancellation
3. Verify:
   - ✅ "Account deletion cancelled" message
   - ✅ Account returns to active state
   - ✅ Countdown disappears

### 2. Backend Lambda Testing (AWS)

#### Setup Lambda (if not already done)
```bash
cd aws
./setup.sh development
```

#### Test Direct Deletion (Small Account)
```bash
# Test with a small test account
aws lambda invoke \
  --function-name photolala-deletion-development \
  --payload '{
    "type": "immediate",
    "userId": "test-user-small"
  }' \
  response.json

cat response.json | jq .
# Expected: {"status": "completed", "method": "direct", ...}
```

#### Test Batch Deletion (Large Account)
```bash
# First, create many test objects (>1000)
# Then test deletion
aws lambda invoke \
  --function-name photolala-deletion-development \
  --payload '{
    "type": "immediate",
    "userId": "test-user-large"
  }' \
  response.json

cat response.json | jq .
# Expected: {"status": "batch_job_created", "jobId": "...", "method": "batch"}

# Check batch job status
aws lambda invoke \
  --function-name photolala-deletion-development \
  --payload '{
    "type": "status",
    "jobId": "YOUR-JOB-ID-HERE"
  }' \
  status.json

cat status.json | jq .
```

#### Test Scheduled Deletion Processing
```bash
# Process all scheduled deletions for today
aws lambda invoke \
  --function-name photolala-deletion-development \
  --payload '{"type": "scheduled"}' \
  scheduled.json

cat scheduled.json | jq .
# Expected: {"processed": N, "results": [...]}
```

### 3. Verify S3 Data

#### Check User Data Exists Before Deletion
```bash
aws s3 ls s3://photolala-dev/users/YOUR-USER-ID/
aws s3 ls s3://photolala-dev/photos/YOUR-USER-ID/
aws s3 ls s3://photolala-dev/identities/ | grep YOUR-USER-ID
```

#### Check Scheduled Deletion Entry
```bash
# After scheduling deletion
aws s3 ls s3://photolala-dev/scheduled-deletions/
aws s3 cp s3://photolala-dev/users/YOUR-USER-ID/status.json - | jq .
# Should show: {"accountStatus": "scheduled_for_deletion", ...}
```

#### Verify Data Removed After Deletion
```bash
# After deletion completes
aws s3 ls s3://photolala-dev/users/YOUR-USER-ID/
# Should return: No such key

aws s3 ls s3://photolala-dev/identities/ | grep YOUR-USER-ID
# Should return: Nothing (identity mappings removed)
```

### 4. Test Edge Cases

#### A. Delete and Re-signup
1. Delete account (immediate or wait for scheduled)
2. Sign in again with same Apple ID
3. Verify:
   - ✅ New account created successfully
   - ✅ New UUID assigned
   - ✅ No old data restored

#### B. Network Interruption
1. Start deletion process
2. Turn off network
3. Verify:
   - ✅ Appropriate error message
   - ✅ Can retry when network returns

#### C. Large Account Handling
1. Upload many photos (>1000)
2. Delete account
3. Verify:
   - ✅ S3 Batch job created (check AWS console)
   - ✅ Can track job progress
   - ✅ Identity mappings removed immediately

## Monitoring

### CloudWatch Logs
```bash
# View Lambda logs
aws logs tail /aws/lambda/photolala-deletion-development --follow
```

### EventBridge Rule (Scheduled Deletions)
```bash
# Check if rule is enabled
aws events describe-rule --name photolala-deletion-schedule-development

# Manually trigger scheduled processing
aws events put-events \
  --entries '[{
    "Source": "testing",
    "DetailType": "manual-trigger",
    "Detail": "{\"type\":\"scheduled\"}"
  }]'
```

### S3 Batch Operations Console
1. Go to AWS S3 Console
2. Click "Batch Operations" in left menu
3. View job status and progress

## Troubleshooting

### Account won't delete
- Check Lambda logs for errors
- Verify IAM permissions
- Check S3 bucket exists and is accessible

### Can't sign in after deletion
- Verify identity mappings were removed:
  ```bash
  aws s3 ls s3://photolala-dev/identities/
  ```
- Check no status.json remains:
  ```bash
  aws s3 ls s3://photolala-dev/users/USER-ID/
  ```

### Batch job stuck
- Check job status in S3 console
- Verify S3BatchOperationsRole exists
- Check manifest file is valid CSV

## Success Criteria

✅ **Phase 1**: status.json created/updated correctly
✅ **Phase 2**: UI shows countdown and allows cancellation
✅ **Phase 3**: Lambda processes deletions (direct or batch)
✅ **Identity cleanup**: User can re-register immediately
✅ **Data removal**: All user data deleted from S3

## Reset Test Environment

```bash
# Remove all test data
aws s3 rm s3://photolala-dev/users/test-user-id/ --recursive
aws s3 rm s3://photolala-dev/photos/test-user-id/ --recursive
aws s3 rm s3://photolala-dev/scheduled-deletions/ --recursive

# Clear local app data
# iOS: Delete app and reinstall
# macOS: ~/Library/Application Support/Photolala/
```
# Soft Account Deletion Implementation Plan

## Executive Summary

Implement a user-friendly account deletion system that provides a grace period for users to change their mind while maintaining full compliance with Apple, Google, and privacy regulations. The system uses scheduled deletion with status.json as the source of truth for account existence.

**Key Innovation**: Uses S3 Batch Operations for scalable deletion of 100K+ objects including Deep Archive data, ensuring compliance by deleting all data on the same schedule without retrieval fees.

## Problem Statement

### Current Issues
1. **Account Resurrection Bug**: Deleted accounts can sign back in and get a fresh account
2. **No User Safety Net**: Accidental deletions are permanent and irreversible
3. **Identity Mapping Inconsistency**: Mix of legacy and canonical key formats
4. **Platform Compliance**: Need to meet Apple/Google deletion requirements

### Requirements
- Apple/Google: Must provide in-app account deletion
- GDPR: Must delete data "without undue delay" (typically 30 days)
- User Experience: Prevent accidental permanent data loss
- Security: Prevent deleted accounts from being recreated

## Solution Overview

### Three-Phase Deletion System

```
1. active → User requests deletion
2. scheduled_for_deletion → Grace period (3 min dev, 3 days staging, 30 days production)
3. [removed] → Permanent deletion (status.json removed)
```

### Key Components
1. **Scheduled Deletion**: Queue deletions with configurable grace period
2. **Status.json as Source of Truth**: Account exists if status.json exists
3. **Lambda Processor**: Daily job to execute scheduled deletions
4. **Cancellation Flow**: Allow users to cancel during grace period

### Account Detection Logic

The system uses `users/{uuid}/status.json` as the definitive source for account existence:

**Account States**:
- status.json exists with `active` → Normal account
- status.json exists with `scheduled_for_deletion` → Grace period
- status.json exists with `deleted` → Soft deleted (awaiting cleanup)
- status.json returns 404 → Account fully deleted, can create new

**Sign-in Flow**:
1. User signs in with Apple/Google ID
2. Lambda checks identity mapping → gets UUID
3. Check `users/{uuid}/status.json`
4. If no status.json → account deleted → offer signup
5. If status.json exists → check state → proceed accordingly

## Technical Architecture

### Data Flow

```
User Request → Schedule Deletion → Grace Period → Lambda Execution → Full Deletion
      ↓                                    ↓                              ↓
  Confirmation                    Can Cancel/Expedite           status.json Removed
      ↓                                    ↓                              ↓
 All Devices Notified            Read-Only Access             Account No Longer Exists
```

### S3 Structure

**Identity Mappings** (simple UUID storage):
- Active/Scheduled: `identities/apple:000123` → `"user-uuid"`
- Deleted: Key removed entirely

**Scheduled Deletions** (organized by date for batch processing):
- `scheduled-deletions/2024-02-14/user-uuid` → Deletion metadata

**User Status** (primary detection mechanism):
- `users/{uuid}/status.json` → Account state, deletion date, access level
- Present = Account exists
- 404 = Account deleted

**IAM Considerations**:
- Auth Lambda: Read-only access to identities and status.json
- Deletion Lambda: Write/delete access for all user data
- Client apps: No direct identity access, only user data

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

#### 1.1 Identity Mapping Management

**What**: Keep identity mappings simple - they only store the user UUID

**Format**: Simple UUID string
- Always stores: `user-uuid` (never changes)
- All state information: Tracked in `users/{uuid}/status.json`
- On deletion: Identity mapping removed entirely

**Key principle**: Identity mappings are stateless - they only map external ID to internal UUID

#### 1.2 Deletion Scheduling Service

**What**: Service to manage account deletion lifecycle

**Key Responsibilities**:
- Schedule deletions with environment-specific grace periods:
  - **Development**: 3 minutes (for rapid testing)
  - **Staging**: 3 days (for integration testing)
  - **Production**: 30 days (for user safety)
- Create scheduled deletion entries organized by date/time
- Update status.json to reflect scheduled state
- Handle cancellations by updating status.json back to active
- Send confirmation emails

### Phase 2: S3 Batch Operations Integration (Week 2-3)

#### 2.1 Deletion Orchestration Strategy

**Approach**: Scheduled Batch Processing with S3 Batch Operations

**Implementation**:
- EventBridge triggers Lambda on schedule:
  - **Development**: Every 5 minutes (3-minute grace period)
  - **Staging**: Daily at 2 AM (3-day grace period)
  - **Production**: Daily at 2 AM (30-day grace period)
- Lambda processes all deletions scheduled for that time
- Small accounts (<1K objects): Direct deletion via Lambda
- Large accounts (>1K objects): Creates S3 Batch Operations job
- Handles multiple accounts in single batch for efficiency

**Expedited Deletion**:
- **Development only**: "Delete Now" button triggers immediate Lambda execution
  - Bypasses grace period for testing
  - Direct deletion without waiting for batch
- **Staging/Production**: "Delete Now" moves scheduled date to next batch run
  - Maintains audit trail and safety
  - No bypass of batch processing

#### 2.2 Implementation Approach

**Implementation Flow**:
1. **Client**: Calls deletion Lambda API with user credentials
2. **Lambda**: Validates request and determines account size
3. **Lambda**: For large accounts, creates S3 Batch Operations job
4. **Lambda**: Returns status to client for monitoring
5. **Client**: Polls Lambda status endpoint only (no direct AWS API access)
6. **Lambda**: Handles all backend work - deletion, notifications, cleanup

**Key Security Boundaries**:
- Client never touches S3Control or S3 APIs directly for deletion
- Client only interacts with Lambda endpoints
- Lambda owns all privileged operations (deletion, batch jobs, emails)
- Client role limited to requesting and monitoring

#### 2.3 Key Technical Decisions

**Identity Mapping Format**: Simple UUID storage
- All account states: `user-uuid`
- Account state tracked in: `users/{uuid}/status.json`
- Deleted accounts: Identity mapping removed entirely

**Batch Job Triggers**:
- **User-initiated**: Client calls Lambda endpoint → Lambda creates batch job
- **Scheduled processing**: EventBridge triggers deletion Lambda daily for grace period completions

**Completion Monitoring**:
- Swift: Background task polling
- Lambda: EventBridge rule on job status change

### Phase 3: Multi-Device UX Implementation (Week 3-4)

#### 3.1 Status Synchronization

**What**: Account state detection and multi-device synchronization

**State Detection Strategy**:
- Store UUID in UserDefaults: `com.electricwoods.photolala.account.uuid`
- On app launch: Check `users/{uuid}/status.json` existence
- Status file present (200) → Account exists (active or scheduled)
- Status file missing (404) → Account doesn't exist (deleted or never created)
- No stored UUID → Fresh install or post-app-deletion

**Status File Strategy**:
- At initial launch: All new accounts get status.json from day one
- Post-launch: Auth Lambda maintains status.json on every sign-in
- Simple rule: No status.json = Account doesn't exist

**Why UserDefaults over Keychain**:
- App deletion clears UserDefaults → Clean slate
- UUID isn't sensitive (not a credential)
- Natural reset mechanism for deleted accounts
- Simpler recovery from edge cases

**Status Polling**:
- Check on app launch
- Background refresh every 10 minutes while active
- Status file contains: account state, deletion date, access level

#### 3.2 Grace Period UX

**Access Restrictions During Grace Period**:
- **Read-only mode**: Can view and export photos
- **Disabled features**: Upload, edit, share, organize
- **Allowed actions**: Cancel deletion, export data, sign out
- **Visual indicators**: Red banner on all screens, disabled UI elements

**Multi-Device Behavior**:
- Deletion initiated on Device A → Online devices enter grace period mode within 10 minutes
- Any signed-in device can cancel deletion
- Cancellation immediately restores full access (propagates to online devices within 10 minutes)
- **Caveat**: Offline devices remain in previous state until they come online and sync

#### 3.3 Deletion Warning UI

**Persistent Banner Design**:
- Top-of-screen red banner: "Account scheduled for deletion in X days"
- Tap for details → Full-screen deletion status view
- Options: "Cancel Deletion" or "Delete Now"

**Home Screen Replacement** (Optional for final 24 hours):
- Replace normal home view with deletion countdown
- Large warning icon and countdown timer
- Prominent "Cancel Deletion" button
- "Export My Data" option
- **Development only**: "Delete Now" button for immediate deletion

#### 3.4 Final Hours Safety Measures

**Force Sign-Out Protocol**:
- 10 minutes before hard deletion: Force sign-out all devices
- Clear local cache and credentials
- Prevent re-authentication during final window
- Show: "Account deletion in progress. Sign-in disabled."
- Clear UserDefaults UUID to prevent confusion

#### 3.5 Post-Deletion Device Handling

**App Launch After Deletion**:
1. UserDefaults contains UUID → Fetch status.json → 404
2. Conclude account was deleted
3. Clear UserDefaults UUID
4. Show: "This account was permanently deleted"
5. Offer sign-in with different account

**App Reinstall After Deletion**:
1. UserDefaults empty (cleared by iOS on uninstall)
2. Show standard sign-in screen
3. If user tries same identity → No status.json found → Offer new signup

**Network Failure Handling**:
- Distinguish between 404 (deleted) and network errors
- Don't assume deletion on network failure
- Implement retry with exponential backoff
- Cache last known status for offline mode

### Phase 4: Authentication Updates (Week 4)

#### 4.1 Lambda Authentication Changes

**What**: Modify auth Lambda to respect account states AND maintain status.json

**Key Behaviors**:
- **On successful auth**: Create/update `users/{uuid}/status.json`
- **Deleted accounts**: Return 403 with clear error message
- **Scheduled accounts**: Allow limited access for cancellation
- **Active accounts**: Normal authentication flow
- **New accounts**: Initialize status.json with active state

**Critical Addition - Status File Maintenance**:
- Every sign-in updates status.json with current timestamp
- New account creation includes status.json initialization
- Prevents existing users from appearing deleted post-deployment

**State Detection**: Check status.json to determine account state

#### 4.2 Swift Authentication Handler

**What**: Client-side handling of account states

**Behaviors**:
- **Active**: Normal sign-in and app access
- **Scheduled**: Limited access, show cancellation UI
- **Deleted**: Show error with explanation

## Migration Path

### Step 1: Deploy Infrastructure (No Impact)
1. Deploy Lambda function (inactive)
2. Set up EventBridge rule (disabled)
3. Create DLQ and monitoring
4. Deploy batch operations Lambda with S3Control permissions

### Step 2: Update Authentication Lambda
1. Add status.json creation for all new accounts
2. Update status.json on every sign-in
3. Add support for scheduledForDeletion and deleted states in status.json

### Step 3: Update Client
1. Deploy updated S3Service with status.json checks
2. Update AccountManager with scheduled deletion logic
3. Simple detection: No status.json = No account
4. Add UI for deletion options (hidden behind feature flag)

### Step 4: Complete Lambda Deployment
1. Deploy deletion processing Lambda
2. Configure EventBridge for daily execution
3. Test with small accounts first

### Step 5: Enable Feature (Gradual Rollout)
1. Enable in development (3-minute retention for rapid testing)
2. Enable in staging (3-day retention for integration testing)
3. Enable in production (30-day retention for user safety)

### Step 6: Monitor and Optimize
1. Monitor deletion success rate
2. Track cancellation rate
3. Adjust grace periods based on user behavior
4. Verify all active users have status.json files

## Testing Strategy

### Unit Tests
- Verify identity mappings store only UUID
- Test scheduling and cancellation logic
- Confirm deleted accounts (no status.json) allow new signup
- Validate identity mappings deleted with account
- Status polling mechanism
- Force sign-out timing logic

### Integration Tests
- Full deletion flow (schedule → wait → process)
- Cancellation during grace period
- Multiple identity providers
- Email delivery verification
- Lambda processor with mock data
- Multi-device synchronization scenarios
- Offline device handling

### Load Tests
- Process 1000+ scheduled deletions
- Handle concurrent cancellations
- Verify S3 rate limits compliance
- Stress test status polling with many devices

### Multi-Device Test Scenarios
1. **Cross-device cancellation**: Init on iPhone, cancel on Mac
2. **Offline grace period**: Device offline during deletion, comes online after
3. **Rapid status changes**: Cancel and re-schedule quickly
4. **Force sign-out**: Verify all devices signed out before deletion
5. **Mixed app versions**: Old app version behavior during deletion

## Monitoring & Alerts

### Key Metrics
- Deletions scheduled/cancelled/processed
- Deletion failure rate
- Processing time per deletion
- Grace period cancellation rate
- Device sync lag (time to propagate status)
- Force sign-out success rate

### Critical Alarms
- High deletion failure rate (>10%)
- Lambda execution errors
- DLQ message age (>1 hour)
- Scheduled deletion backlog (>100)
- Status sync failures (>5% devices not updated)
- Force sign-out failures in final window

### Dashboard Views
- Daily deletion volume
- Cancellation patterns by grace period day
- Average time to cancellation decision
- Failed deletion details

## Compliance Verification

### Apple App Store ✅
- In-app deletion initiated immediately
- Process clearly explained
- User data removed within reasonable timeframe

### Google Play Store ✅
- Account deletion available in-app
- Retention period clearly stated (30 days)
- Data deletion confirmed via email

### GDPR ✅
- Deletion within 30 days (without undue delay)
- Clear information about process
- Right to erasure fulfilled

### CCPA ✅
- Verifiable consumer request process
- 45-day completion (well within grace period)
- Confirmation of deletion provided

## Compliance & Cost Considerations

### Deep Archive Deletion
- All storage classes deleted on same schedule for compliance
- S3 Batch Operations handles all classes uniformly
- No retrieval fees for deletion
- Only costs: $0.25 batch job + early deletion penalties (if applicable)

### Cost Analysis for 100K Photos (90% Deep Archive)
- **Small accounts** (<1K objects): ~$0.01 via Lambda
- **Large accounts** (100K objects): ~$0.25 via Batch Operations
- **With early deletion** (60 days into 180-day minimum): ~$2.03 total

### Deletion Strategy Selection
- <1K objects: Direct Lambda deletion
- 1K-10K objects (no Deep Archive): Lambda with batch delete
- >10K objects or Deep Archive: S3 Batch Operations

## Success Metrics

### User Experience
- <1% accidental deletion support tickets
- >20% deletion cancellation rate (healthy second thoughts)
- <24 hour average time to cancellation decision

### Technical
- 99.9% deletion processing success rate
- <5 minute Lambda execution time
- Zero account resurrections after deletion

### Business
- Reduced support burden
- Improved user trust
- Compliance with all regulations

## Configuration

### Environment Settings
- **Grace periods**:
  - Development: 3 minutes (rapid testing, worst case ~8 minutes)
  - Staging: 3 days (integration testing)
  - Production: 30 days (user safety)
- **EventBridge Schedule**:
  - Development: Every 5 minutes (rate(5 minutes))
  - Staging: Daily at 2 AM (cron(0 2 * * ? *))
  - Production: Daily at 2 AM (cron(0 2 * * ? *))
- **Email notifications**: Enabled per environment
- **Batch processing**: Size limits and retry counts
- **Feature flags**: Scheduled deletion, immediate deletion, banners

## Rollback Plan

If issues arise:

1. **Disable EventBridge rule** - Stop processing new deletions
2. **Revert Lambda** - Deploy previous version
3. **Clear scheduled deletions** - Move to backup prefix
4. **Update client** - Hide deletion UI via feature flag
5. **Investigate** - Analyze logs and metrics
6. **Fix and redeploy** - Address issues before re-enabling

## Future Enhancements

### Phase 2 (Optional)
1. **Data Export** - Auto-generate before deletion
2. **Partial Deletion** - Delete photos but keep account
3. **Account Recovery** - Limited time after deletion
4. **Admin Tools** - Dashboard for managing deletions

### Phase 3 (Long-term)
1. **Predictive Warnings** - ML to identify at-risk accounts
2. **Progressive Deletion** - Gradual data removal
3. **Cross-Region** - Handle global compliance differences
4. **Audit Logs** - Comprehensive deletion history

## Conclusion

This soft deletion approach provides the optimal balance between user safety, platform compliance, and technical simplicity. The 30-day grace period for production gives users ample time to reconsider while meeting all regulatory requirements. Using status.json as the single source of truth eliminates complexity - when an account is fully deleted (no status.json), the same identity can create a new account.
# Cancellation and Non-Payment Policy

## Overview
Design a fair, user-friendly approach that protects user data while ensuring sustainable economics.

## Cancellation Scenarios

### 1. Voluntary Cancellation (User Cancels)

#### Grace Period: 30 Days
```
Day 0: User cancels subscription
Days 1-30: 
- Read-only access to all photos
- Can download everything
- Can't upload new photos
- Shows: "Subscription ends in X days"

Day 31+:
- Thumbnails still visible
- Can't download originals
- Can purchase "Recovery Pass" ($9.99)
- Shows: "Reactivate to access photos"
```

#### Data Retention Timeline
```
0-30 days: Full access (grace period)
31-90 days: Browse only, can reactivate
91-365 days: Data archived, $19.99 reactivation
365+ days: Data queued for deletion
```

### 2. Payment Failure (Involuntary)

#### Apple's Payment Retry Period
```
Day 0: Payment fails
Days 1-60: Apple retries (per App Store rules)
- User keeps full access
- Shows: "Payment issue - update payment method"

Day 61+: Subscription terminated
- Enters same flow as voluntary cancellation
```

## User Experience Flows

### Cancellation Warning
```
┌─────────────────────────────────────┐
│ ⚠️ Before You Cancel                │
├─────────────────────────────────────┤
│                                     │
│ Your backed up photos:              │
│ • 15,234 photos (152GB)             │
│ • 10.2GB in recent storage          │
│ • 141.8GB in archive                │
│                                     │
│ What happens next:                  │
│ ✓ 30 days to download everything    │
│ ✓ Thumbnails remain viewable        │
│ ⚠️ After 90 days, reactivation fee  │
│ ❌ After 365 days, permanent deletion│
│                                     │
│ [Download All] [Keep Subscription]  │
│ [Proceed with Cancellation]         │
└─────────────────────────────────────┘
```

### During Grace Period
```
┌─────────────────────────────────────┐
│ 📸 Photolala Cloud Backup           │
├─────────────────────────────────────┤
│ ⏰ Subscription ends in 23 days     │
│                                     │
│ You can still:                      │
│ • View all photos                   │
│ • Download originals                │
│ • Retrieve from archive (credits)   │
│                                     │
│ You cannot:                         │
│ • Upload new photos                 │
│ • Earn new credits                  │
│                                     │
│ [Reactivate] [Download Photos]      │
└─────────────────────────────────────┘
```

### After Cancellation
```
┌─────────────────────────────────────┐
│ 📸 Photolala Cloud Backup           │
├─────────────────────────────────────┤
│ 🔒 Subscription Inactive            │
│                                     │
│ Your photos are safe:               │
│ • 15,234 photos preserved           │
│ • Browse thumbnails only            │
│ • 67 days until archive fee         │
│                                     │
│ Options:                            │
│ [Reactivate - $1.99/mo]             │
│ [Recovery Pass - $9.99 once]        │
│ [Delete All Data]                   │
└─────────────────────────────────────┘
```

## Data Handling Policies

### What Stays Accessible
1. **Always Available** (even without subscription):
   - Thumbnails (low bandwidth cost)
   - Basic metadata
   - Folder structure
   - Photo count/statistics

2. **Requires Active Subscription**:
   - Original photo downloads
   - Archive retrievals
   - New uploads
   - Credit accumulation

### Recovery Options

#### 1. Reactivation (Resume Subscription)
- **0-90 days**: Instant, no extra fee
- **91-365 days**: $19.99 one-time fee
- **365+ days**: Not available

#### 2. Recovery Pass (One-Time Purchase)
- **Price**: $9.99
- **Duration**: 7 days full access
- **Purpose**: Download your data
- **Limitations**: No uploads, no new credits

#### 3. Data Export
- **Format**: ZIP files via download links
- **Organization**: By year/month
- **Includes**: Photos, metadata, folder structure
- **Cost**: Included in Recovery Pass

## Special Considerations

### 1. Credits and Retrievals
```
Active retrievals when cancelled:
- In-progress retrievals complete
- Retrieved photos available for 30 days
- Unused credits expire immediately
- No refunds for unused credits
```

### 2. Shared/Family Plans
```
When Family organizer cancels:
- 60-day grace period for members
- Members can take over billing
- Each member's data handled separately
- Option to export before separation
```

### 3. Long-Term Storage Costs
```
Cost Analysis for Retained Data:
- Thumbnails: ~$0.01/user/month
- Metadata: ~$0.001/user/month
- Minimal cost to keep indefinitely
- Good PR to preserve thumbnails
```

## Implementation Details

### Database Schema
```swift
@Model
class UserSubscription {
    let userId: String
    let status: SubscriptionStatus
    let cancelledAt: Date?
    let expiresAt: Date?
    let gracePeriodEnds: Date?
    let dataRetentionEnds: Date?
    let reactivationFee: Decimal?
}

enum SubscriptionStatus {
    case active
    case cancelled
    case gracePeriod
    case suspended
    case expired
    case pendingDeletion
}
```

### Automated Actions
```
Daily Cron Jobs:
1. Check expiring grace periods
2. Move expired data to deletion queue
3. Send warning emails
4. Update user access permissions
5. Calculate reactivation fees
```

## Communication Timeline

### Email Notifications
1. **Immediate**: Cancellation confirmation
2. **Day 7**: "23 days to download your photos"
3. **Day 23**: "Last week to download"
4. **Day 29**: "Tomorrow is your last day"
5. **Day 31**: "Browse-only mode active"
6. **Day 60**: "Reactivation fee starting soon"
7. **Day 350**: "Final warning - deletion in 15 days"

### In-App Messaging
- Persistent banner during grace period
- Modal on first open after cancellation
- Clear status in settings
- Download progress tracker

## Competitive Analysis

### Industry Standards
- **Google Photos**: Immediate read-only
- **iCloud**: 30-day grace period
- **Dropbox**: Immediate downgrade
- **Amazon Photos**: Keep photos, lose features

### Photolala Advantage
- Generous 30-day grace period
- Thumbnails always available
- Clear communication
- Fair reactivation options
- One-time Recovery Pass option

## Business Rationale

### Why This Approach
1. **User Trust**: Fair policies build loyalty
2. **Win-Back Opportunity**: Easy reactivation
3. **Low Cost**: Thumbnails cost ~$0.01/month
4. **Good PR**: "We never delete your memories"
5. **Upsell Path**: Recovery Pass revenue

### Expected Outcomes
- 30% reactivation within grace period
- 10% purchase Recovery Pass
- 5% reactivate after 90 days
- Positive word-of-mouth

## Edge Cases

### 1. Free Tier Users
- No grace period (already free)
- Immediate archive-only access
- Can upgrade anytime

### 2. Promotional Subscriptions
- Grace period based on paid value
- Convert to regular pricing

### 3. Refund Requests
- Follow App Store policies
- Maintain data for 30 days post-refund
- Clear communication about data retention
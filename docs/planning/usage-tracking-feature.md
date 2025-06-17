# Usage Tracking Feature Design

## Overview

This document describes the design for tracking storage usage in the Photolala S3 backup service. Users need to know how much storage they're using and when they're approaching their subscription limits.

## User Stories

1. **As a user**, I want to see how much storage I'm using so I can manage my backup space
2. **As a user**, I want to be warned before I exceed my storage limit so I can take action
3. **As a user**, I want to know the breakdown of my storage (standard vs archive) so I can optimize costs
4. **As a user**, I want the app to prevent uploads that would significantly exceed my limit

## Requirements

### Functional Requirements

1. **Display Current Usage**
   - Show total storage used (GB/TB)
   - Show percentage of limit used
   - Show breakdown by storage class (Standard/Deep Archive)
   - Show number of photos backed up
   - Show when usage was last calculated

2. **Usage Limits**
   - Personal tier: 2TB limit
   - Family tier: 10TB limit
   - Show remaining storage available
   - Visual indicators (progress bar with color coding)

3. **Upload Warnings**
   - Warn at 80% usage (yellow)
   - Warn at 95% usage (orange)
   - Block uploads at 110% usage (10% grace buffer)
   - Show warning before large uploads that would exceed limit

4. **Performance**
   - Cache usage data for 24 hours
   - Allow manual refresh
   - Don't block UI while calculating
   - Handle large photo libraries efficiently

### Non-Functional Requirements

1. **Accuracy**: Usage should be accurate within 1GB
2. **Responsiveness**: Usage check should complete within 10 seconds
3. **Reliability**: App should function even if usage check fails
4. **Privacy**: Usage data should remain private to the user

## Design Approach

### Phase 1: Client-Side Implementation (MVP)

For the initial release, we'll implement usage tracking entirely on the client side:

1. **Calculate usage from S3 ListObjects API**
   - Enumerate all objects in user's prefix
   - Sum up sizes by storage class
   - Count total objects

2. **Cache results locally**
   - Store in UserDefaults with timestamp
   - Expire after 24 hours
   - Refresh on demand

3. **Integrate with upload flow**
   - Check before upload
   - Show warnings as appropriate
   - Block if over hard limit

### Phase 2: Server-Side Enhancement (Future)

Later, we can add server-side tracking for better performance:

1. **Backend service tracks usage**
   - Process S3 events
   - Store in DynamoDB
   - Provide API for quick lookups

2. **Real-time updates**
   - Push notifications for usage changes
   - Sync across devices
   - Admin tools for support

## UI/UX Design

### Storage Usage View

```
┌─────────────────────────────────────┐
│ Storage Usage                       │
│                                     │
│ ████████████████░░░░  1.5 TB / 2 TB│
│                        75% used     │
│                                     │
│ 📷 150,432 photos                   │
│ 💾 Standard: 500 GB                 │
│ 🗄️ Archive: 1 TB                    │
│                                     │
│ Updated 2 hours ago   [Refresh]    │
└─────────────────────────────────────┘
```

### Upload Warning Dialog

```
┌─────────────────────────────────────┐
│ ⚠️ Storage Warning                   │
│                                     │
│ This upload will use 50 GB and      │
│ bring you to 95% of your storage    │
│ limit.                              │
│                                     │
│ Current: 1.9 TB / 2 TB              │
│ After upload: 1.95 TB / 2 TB        │
│                                     │
│ [Cancel]           [Upload Anyway]  │
└─────────────────────────────────────┘
```

### Integration Points

1. **Subscription View**: Show usage prominently
2. **Backup Settings**: Show usage summary
3. **Upload Flow**: Check before each upload
4. **Menu Bar**: Quick usage indicator (macOS)

## Technical Considerations

### S3 ListObjects Performance

- Use pagination (1000 objects per request)
- Process results as they arrive
- Show progress during calculation
- Consider parallel requests for large libraries

### Caching Strategy

```swift
struct UsageCache {
    let usage: StorageUsage
    let timestamp: Date
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 86400 // 24 hours
    }
}
```

### Error Handling

1. **Network errors**: Use cached data if available
2. **S3 errors**: Retry with exponential backoff
3. **No subscription**: Show appropriate message
4. **Calculation timeout**: Show partial results

## Implementation Plan

### Week 1: Core Implementation
- [ ] Create StorageUsage model
- [ ] Implement UsageTrackingService
- [ ] Add S3 enumeration logic
- [ ] Implement caching

### Week 2: UI Integration
- [ ] Create StorageUsageView
- [ ] Add to SubscriptionView
- [ ] Integrate with upload flow
- [ ] Add warning dialogs

### Week 3: Testing & Polish
- [ ] Test with large libraries
- [ ] Optimize performance
- [ ] Add error handling
- [ ] Polish UI/UX

## Success Metrics

1. **Usage Visibility**: 90% of users check their usage monthly
2. **Warning Effectiveness**: <5% of users hit hard limit
3. **Performance**: 95% of usage checks complete in <5 seconds
4. **User Satisfaction**: Positive feedback on storage management

## Future Enhancements

1. **Usage History**: Show trends over time
2. **Predictive Warnings**: "At current rate, you'll exceed limit in 30 days"
3. **Smart Archiving**: Suggest photos to archive based on usage patterns
4. **Family Sharing**: Show breakdown by family member
5. **Export Reports**: Download usage reports for accounting

## Open Questions

1. Should we show usage in binary (1024) or decimal (1000) units?
2. How often should we auto-refresh usage in the background?
3. Should we allow users to continue uploading past 110%?
4. How do we handle users who downgrade with data over new limit?
5. Should archived photos count differently toward limits?
# Status.json Specification

## Overview

`users/{uuid}/status.json` serves as the authoritative source for account state. Its presence indicates an account exists; its absence means the account is deleted.

## Current Implementation (v1.0)

### Schema
```json
{
  "accountStatus": "active|scheduled_for_deletion",
  "deleteDate": "2024-02-14T10:30:00Z",  // Only present when scheduled_for_deletion
  "lastModified": "2024-01-15T10:30:00Z"
}
```

### Account States

| State | status.json | Description |
|-------|------------|-------------|
| **Active** | `{"accountStatus": "active"}` | Normal account operations |
| **Scheduled** | `{"accountStatus": "scheduled_for_deletion", "deleteDate": "..."}` | Grace period before deletion |
| **Deleted** | `[404 - File not found]` | Account removed, can sign up again |

### State Transitions
```
active → scheduled_for_deletion → [removed]
   ↑            ↓
   ←────────────
   (cancellation)
```

### Client Behavior

```swift
// Check account existence
if let status = await s3Service.getUserStatus(uuid) {
    switch status.accountStatus {
    case "active":
        // Normal operations
    case "scheduled_for_deletion":
        // Show warning, offer cancellation
        // Display: "Account scheduled for deletion on {deleteDate}"
    }
} else {
    // No status.json = account doesn't exist
    // User can create new account with same identity
}
```

### Key Principles

1. **No status.json = No account**: Enables clean re-signup after deletion
2. **Simple states**: Just active and scheduled_for_deletion for now
3. **Atomic operations**: Status changes are single S3 PUT operations
4. **Client polling**: Check status every 10 minutes (1 minute during scheduled deletion)

## Future Extensibility

The schema is designed to grow without breaking existing clients:

### Potential Future Additions
```json
{
  "accountStatus": "active|suspended|scheduled_for_deletion",
  "deleteDate": "2024-02-14T10:30:00Z",
  "suspendedReason": "payment_failed",        // Future: Account suspension
  "quotas": {                                  // Future: Storage limits
    "storageUsed": 5368709120,
    "storageLimit": 10737418240
  },
  "restrictions": {                            // Future: Granular permissions
    "canUpload": false,
    "canDelete": true
  },
  "features": {                                // Future: Feature flags
    "aiTagging": true,
    "betaAccess": false
  },
  "subscription": {                            // Future: Tier management
    "tier": "premium",
    "expiresAt": "2024-12-31T23:59:59Z"
  },
  "lastModified": "2024-01-15T10:30:00Z"
}
```

### Extension Guidelines

- **Optional fields**: New fields are always optional with sensible defaults
- **Backward compatible**: Clients ignore unknown fields
- **Flat structure**: Prefer flat keys until nesting provides clear value
- **Semantic versioning**: Add version field only for breaking changes

## Implementation Details

### S3 Path
- Location: `users/{uuid}/status.json`
- Content-Type: `application/json`
- Access: Read via signed URL, Write via Lambda only

### Grace Periods
- Development: 3 minutes
- Staging: 3 days
- Production: 30 days

### Deletion Process
1. User requests deletion
2. Update status.json: `scheduled_for_deletion` with `deleteDate`
3. Create entry in `scheduled-deletions/{date}/{uuid}.json`
4. Grace period countdown
5. Lambda processes scheduled deletions daily
6. Delete all user data including status.json
7. User can now sign up fresh with same identity

### Cancellation Process
1. User requests cancellation (during grace period)
2. Update status.json: back to `active`
3. Remove `scheduled-deletions/{date}/{uuid}.json`
4. Account continues normally

## Security & Performance

### Access Control
- **Clients**: Read-only via signed URLs
- **Lambda**: Full read/write access
- **Direct S3**: Blocked by IAM policy

### Caching
- Client caches for 5 minutes
- Force refresh on critical operations
- Poll frequency based on state urgency

### Error Handling
- Missing status.json = Account doesn't exist (not an error)
- Malformed JSON = Treat as active (fail safe)
- Network failure = Use cached value with warning

## Summary

This specification defines a minimal yet extensible system for account state management. Starting with just deletion scheduling, the schema can grow to accommodate suspension, quotas, feature flags, and other account-level concerns without breaking existing implementations. The key insight is that the absence of status.json definitively indicates a deleted account, enabling clean re-signup flows.
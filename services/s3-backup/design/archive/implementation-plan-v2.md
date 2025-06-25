# Implementation Plan for New Pricing Strategy

## Summary of Changes

### Storage Tiers (What to Implement)
```
Free:      200MB  (was 5GB)
Starter:   500GB  (was 200GB) - $0.99
Essential: 1TB    (keep same) - $1.99  
Plus:      1.5TB  (was 2TB)   - $2.99
```

### S3 Storage Classes by Data Type
```
Photos:
├── 0-2 days:  S3 Standard ($0.023/GB)
└── 3+ days:   S3 Glacier Instant ($0.004/GB)

Thumbnails:
├── 0-7 days:  S3 Standard ($0.023/GB)
└── 8+ days:   S3 Standard-IA ($0.0125/GB)

Metadata:
└── Always:    S3 Standard-IA ($0.0125/GB)
```

## Code Changes Required

### 1. Update IdentityManager.swift
```swift
var storageLimit: Int64 {
    switch self {
    case .free: return 200 * 1024 * 1024           // 200 MB (was 5GB)
    case .starter: return 500 * 1024 * 1024 * 1024 // 500 GB
    case .essential: return 1024 * 1024 * 1024 * 1024 // 1 TB (same)
    case .plus: return 1536 * 1024 * 1024 * 1024   // 1.5 TB (was 2TB)
    case .family: return 1536 * 1024 * 1024 * 1024 // 1.5 TB shared
    }
}
```

### 2. Update S3BackupService.swift
Add lifecycle configuration for different data types:
- Photos: transition to Glacier Instant after 2 days
- Thumbnails: transition to Standard-IA after 7 days
- Metadata: always Standard-IA

### 3. Update Marketing Copy
- SubscriptionView.swift descriptions
- SignInPromptView.swift (5GB free → 200MB free trial)
- Documentation

### 4. Consider Renaming Tiers
Current names don't reflect the sharp reduction:
- "Plus" at 1.5TB might need a new name
- Consider adding "Family" as sharing option at same price

## Profit Margin Validation

With Apple's 30% cut:
- Starter ($0.99): $0.69 revenue, $0.55 cost = 20% margin ✅
- Essential ($1.99): $1.39 revenue, $1.13 cost = 19% margin ✅
- Plus ($2.99): $2.09 revenue, $1.70 cost = 19% margin ✅

## Migration Strategy

For existing users (if any):
1. Grandfather current storage amounts
2. New users get new tiers
3. Clear communication about the change

## Next Steps

1. Update IdentityManager.swift with new storage limits
2. Update all UI strings and descriptions
3. Add S3 lifecycle rules to service
4. Update StoreKit products (if needed)
5. Test thoroughly with new limits
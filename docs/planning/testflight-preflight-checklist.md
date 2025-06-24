# TestFlight Pre-Flight Checklist

Quick checklist to verify before uploading to TestFlight.

## Code Readiness

### IAP Implementation
- [x] IAPManager implemented with StoreKit 2
- [x] SubscriptionView shows all tiers
- [x] Purchase handling implemented
- [x] Restore purchases supported
- [ ] Receipt validation (currently local only)
- [x] Entitlements checking via Transaction.currentEntitlements

### S3 Backup Features
- [x] Photo upload to S3
- [x] Thumbnail generation and upload
- [x] Metadata backup
- [x] Archive badge display
- [x] Retrieval dialog (PhotoRetrievalView)
- [x] Batch selection for retrieval
- [x] Storage quota enforcement
- [ ] Background uploads
- [ ] Push notifications for retrieval

### UI/UX Polish
- [x] Subscription tier cards
- [x] Storage usage display
- [x] Archive status badges
- [x] Retrieval cost estimation
- [ ] Loading states for all operations
- [ ] Error messages user-friendly
- [ ] Empty states designed

## Configuration Files

### Info.plist Updates Needed
```xml
<!-- Add these entries -->
<key>ITSAppUsesNonExemptEncryption</key>
<false/>

<key>NSPhotoLibraryUsageDescription</key>
<string>Photolala needs access to your photos to back them up securely.</string>
```

### Build Settings
- [ ] Set version number (e.g., 1.0.0)
- [ ] Set build number (start with 1)
- [ ] Verify bundle ID: com.electricwoods.photolala
- [ ] Team ID: 2P97EM4L4N

### Capabilities to Enable
- [x] In-App Purchase (already in .entitlements)
- [ ] Background Modes → Background fetch
- [ ] Associated Domains (for universal links)

## Testing Credentials

### AWS Setup
- [ ] Production S3 bucket created
- [ ] Lifecycle rules applied
- [ ] IAM roles configured
- [ ] Backend service deployed (or use test credentials)

### Temporary Solution for Testing
Until backend is ready, testers can use:
1. Environment variables in Xcode scheme
2. Test AWS credentials with limited permissions
3. Or skip S3 features in TestFlight

## Known Issues to Document

### For TestFlight Notes
```
Known Limitations in Beta:
- Receipt validation is local only (server coming soon)
- Push notifications for retrieval not yet implemented  
- Background uploads not enabled
- Family sharing requires iOS 14+

Test Focus Areas:
- Purchase flow for all subscription tiers
- Upgrade/downgrade between tiers
- Photo upload to S3 (if credentials provided)
- Archive retrieval UI and cost calculation
```

## Quick Fixes Needed

### 1. Add Loading States
```swift
// In S3BackupManager
@Published var isUploading = false
@Published var uploadProgress: Double = 0.0

// In PhotoRetrievalView  
@State private var isRestoring = false
```

### 2. User-Friendly Errors
```swift
enum UserFacingError: LocalizedError {
    case noInternetConnection
    case quotaExceeded
    case subscriptionRequired
    
    var errorDescription: String? {
        switch self {
        case .noInternetConnection:
            return "Please check your internet connection"
        case .quotaExceeded:
            return "You've reached your storage limit. Upgrade to continue backing up photos."
        case .subscriptionRequired:
            return "A subscription is required to use backup features"
        }
    }
}
```

### 3. Sandbox Detection
```swift
// Add to IAPManager
var isSandbox: Bool {
    Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
}
```

## Minimum Viable TestFlight

If you want to ship quickly to TestFlight:

### Option 1: IAP Only
1. Disable S3 features temporarily
2. Focus on subscription purchase flow
3. Show "Coming Soon" for backup features

### Option 2: Full Features with Test Account
1. Hardcode test AWS credentials
2. Limit to internal testers only
3. Add warning about test environment

### Option 3: Local Testing Only
1. Use StoreKit configuration file
2. Mock S3 responses
3. Focus on UI/UX testing

## Recommended Approach

1. **First TestFlight Build**: IAP + UI only
   - Test subscription flows
   - Gather UI feedback
   - No real S3 integration

2. **Second Build**: Add S3 with test credentials
   - Limited beta testers
   - Real upload/download testing
   - Monitor AWS costs

3. **Third Build**: Full integration
   - Backend receipt validation
   - Production S3 setup
   - Ready for public beta

## Next Immediate Steps

1. Add Info.plist entries
2. Create archive with incremented build number
3. Upload to TestFlight with IAP-only focus
4. Test subscription flows thoroughly
5. Plan backend deployment timeline
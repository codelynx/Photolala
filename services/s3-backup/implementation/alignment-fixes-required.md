# Implementation Alignment Fixes Required

## Overview

Our current implementation doesn't match our payment and identity strategy. This document outlines required changes.

## Critical Misalignments

### 1. Identity Management

**Current**: Device-based UUID
**Required**: Sign in with Apple

```swift
// WRONG - Current implementation
var userId: String {
    return UUID().uuidString  // Device-specific!
}

// CORRECT - What we need
var userId: String {
    guard let appleUserID = IdentityManager.shared.currentUser?.serviceUserID else {
        throw IdentityError.signInRequired
    }
    return appleUserID
}
```

### 2. AWS Credentials

**Current**: User provides AWS credentials
**Required**: Photolala-managed AWS account

```swift
// WRONG - Current approach
struct AWSCredentialsView {
    @State private var accessKey = ""
    @State private var secretKey = ""
}

// CORRECT - What we need
struct PhotolalaBackupService {
    // Credentials embedded in app (encrypted)
    // Or fetched from our backend
    // User NEVER sees AWS credentials
}
```

### 3. Subscription Integration

**Current**: No subscription checks
**Required**: IAP with storage tiers

```swift
// MISSING - Need to add
enum SubscriptionTier: String {
    case free = "com.photolala.free"           // 5 GB
    case basic = "com.photolala.basic"         // 100 GB - $2.99
    case standard = "com.photolala.standard"   // 1 TB - $9.99
    case pro = "com.photolala.pro"             // 5 TB - $39.99
    case family = "com.photolala.family"       // 10 TB - $69.99
}

class SubscriptionManager {
    func currentTier() -> SubscriptionTier
    func storageLimit() -> Int64
    func usedStorage() -> Int64
    func canUpload(size: Int64) -> Bool
}
```

## Implementation Phases

### Phase 1: Fix Identity (Priority 1)

1. **Add Sign in with Apple**
```swift
import AuthenticationServices

class IdentityManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var currentUser: PhotolalaUser?
    
    func signIn() async throws {
        // Implement Sign in with Apple
        // Create service user ID
        // Store in Keychain
    }
}
```

2. **Update S3BackupManager**
```swift
class S3BackupManager {
    func uploadPhoto(_ photo: PhotoReference) async throws {
        // Check if signed in
        guard IdentityManager.shared.isSignedIn else {
            throw BackupError.signInRequired
        }
        
        // Check subscription
        guard SubscriptionManager.shared.canUpload(size: photo.fileSize) else {
            throw BackupError.quotaExceeded
        }
        
        // Continue with upload...
    }
}
```

### Phase 2: Fix AWS Credentials (Priority 2)

1. **Remove AWSCredentialsView** - Users shouldn't see this
2. **Implement backend service** or **Embed encrypted credentials**

```swift
class PhotolalaAWSService {
    private static let encryptedCredentials = "..." // Encrypted at build time
    
    private func getCredentials() -> AWSCredentials {
        // Decrypt using device key
        // Or fetch from our backend using auth token
    }
}
```

### Phase 3: Add Subscriptions (Priority 3)

1. **StoreKit 2 Integration**
```swift
import StoreKit

class IAPManager: ObservableObject {
    @Published var subscriptions: [Product] = []
    @Published var currentSubscription: Product?
    
    func loadProducts() async throws {
        subscriptions = try await Product.products(for: [
            "com.photolala.basic",
            "com.photolala.standard",
            "com.photolala.pro",
            "com.photolala.family"
        ])
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        // Handle purchase result
    }
}
```

2. **Usage Tracking**
```swift
class StorageManager {
    func calculateUsage(for userId: String) async throws -> Int64 {
        // Query S3 for total storage used
    }
    
    func enforceQuota(for tier: SubscriptionTier) async throws {
        let usage = try await calculateUsage()
        let limit = tier.storageLimit
        
        if usage >= limit {
            throw StorageError.quotaExceeded(usage: usage, limit: limit)
        }
    }
}
```

## UI Flow Changes

### Current Flow (Wrong)
```
App Launch → Browse Photos → Select Photos → Configure AWS → Backup
```

### Correct Flow
```
App Launch → Browse Photos → Select Photos → Sign in Required → Check Subscription → Backup
                                                      ↓
                                            Create Apple ID Account
                                                      ↓
                                              Free Tier (5GB)
                                                      ↓
                                            Upgrade Option (IAP)
```

## Immediate Actions Required

1. **STOP** using user-provided AWS credentials
2. **ADD** Sign in with Apple before any backup
3. **IMPLEMENT** subscription tiers with StoreKit 2
4. **TRACK** storage usage per user
5. **ENFORCE** quotas based on subscription

## Backend Requirements

Since we're doing Photolala-managed storage, we need:

1. **User Service**
```
POST /api/users/create
{
  "appleUserId": "xxx",
  "email": "user@example.com"
}
→ { "serviceUserId": "uuid", "tier": "free" }
```

2. **Subscription Service**
```
POST /api/subscriptions/validate
{
  "userId": "uuid",
  "receipt": "base64..."
}
→ { "tier": "standard", "expiresAt": "2024-12-31" }
```

3. **Storage Service**
```
GET /api/storage/usage/{userId}
→ { "used": 1234567890, "limit": 5368709120 }
```

## Migration Path

For current test implementation:

1. Keep AWS credential UI for **development only**
2. Add feature flag: `DEVELOPMENT_MODE`
3. In production: Hide AWS UI, use managed service
4. Gradual rollout with backend services

## Conclusion

Our current implementation is built for "user manages their own AWS" model, but our strategy is "Photolala-managed with IAP subscriptions". We need to:

1. Add authentication (Sign in with Apple)
2. Remove user AWS credential management  
3. Add subscription tiers
4. Implement storage quotas
5. Build backend services

This is a significant pivot but aligns with our business model of $2.99-$69.99/month subscriptions vs users managing their own AWS.
# S3 Identity Upload and Download Operations Analysis

## Overview

This document analyzes how identities are uploaded to and downloaded from S3 in both Android and Apple platforms for the Photolala application.

## Key Findings

### 1. Bucket Configuration
- **Android**: `BUCKET_NAME = "photolala"` (S3Service.kt:24)
- **Apple**: `bucketName = "photolala"` (S3BackupService.swift:54)
- ✅ **Both platforms use the same bucket name**

### 2. Identity Path Format
- **Android**: `identities/${provider.value}:${providerID}` (IdentityManager.kt:599)
- **Apple**: `identities/${provider.rawValue}:${providerID}` (IdentityManager+Authentication.swift:366)
- ✅ **Both platforms use identical path format**

### 3. Identity Content Format
- **Android**: UUID stored as UTF-8 string via `serviceUserID.toByteArray()` (IdentityManager.kt:603)
- **Apple**: UUID stored as UTF-8 string via `serviceUserID.data(using: .utf8)!` (IdentityManager+Authentication.swift:370)
- ✅ **Both platforms store the same content format**

## Upload Operations (Account Creation)

### Android Implementation
```kotlin
// IdentityManager.kt:595-607
private suspend fun createS3UserFolders(user: PhotolalaUser) {
    // Create user directory
    val userPath = "users/${user.serviceUserID}/"
    s3Service.createFolder(userPath)
    
    // Create provider ID mapping
    val identityKey = "${user.primaryProvider.value}:${user.primaryProviderID}"
    val identityPath = "identities/$identityKey"
    
    // Store the UUID as content of the identity file
    val uuidData = user.serviceUserID.toByteArray()
    s3Service.uploadData(uuidData, identityPath)
}
```

### Apple Implementation
```swift
// IdentityManager+Authentication.swift:356-374
private func createS3UserFolders(for user: PhotolalaUser) async throws {
    // Create user directory
    let userPath = "users/\(user.serviceUserID)/"
    try await s3Manager.createFolder(at: userPath)
    
    // Create provider ID mapping in /identities/
    let identityKey = "\(user.primaryProvider.rawValue):\(user.primaryProviderID)"
    let identityPath = "identities/\(identityKey)"
    
    // Store the UUID as content of the identity file
    let uuidData = user.serviceUserID.data(using: .utf8)!
    try await s3Manager.uploadData(uuidData, to: identityPath)
}
```

## Download Operations (Sign In)

### Android Implementation
```kotlin
// IdentityManager.kt:541-588
private suspend fun findUserByProviderID(
    provider: AuthProvider,
    providerID: String
): PhotolalaUser? {
    // Check S3 identity mapping
    val identityKey = "${provider.value}:$providerID"
    val identityPath = "identities/$identityKey"
    
    try {
        val downloadResult = s3Service.downloadData(identityPath)
        val uuidData = downloadResult.getOrNull()
        if (uuidData != null) {
            val serviceUserID = String(uuidData).trim()
            // Reconstruct basic user
            val reconstructedUser = PhotolalaUser(
                serviceUserID = serviceUserID,
                primaryProvider = provider,
                primaryProviderID = providerID,
                // ... other fields
            )
            return reconstructedUser
        }
    } catch (e: Exception) {
        // Handle error
    }
    return null
}
```

### Apple Implementation
```swift
// IdentityManager+Authentication.swift:289-339
internal func findUserByProviderID(
    provider: AuthProvider, 
    providerID: String
) async throws -> PhotolalaUser? {
    // Look up UUID from identity mapping
    let identityKey = "\(provider.rawValue):\(providerID)"
    let identityPath = "identities/\(identityKey)"
    
    do {
        let uuidData = try await s3Service.downloadData(from: identityPath)
        guard let serviceUserID = String(data: uuidData, encoding: .utf8) else {
            return nil
        }
        
        // Reconstruct user from available data
        let reconstructedUser = PhotolalaUser(
            serviceUserID: serviceUserID,
            provider: provider,
            providerID: providerID,
            // ... other fields
        )
        return reconstructedUser
    } catch {
        return nil
    }
}
```

## Provider Naming Convention
Both platforms use the same lowercase provider names:
- Apple Sign-In: `"apple"`
- Google Sign-In: `"google"`

This is confirmed by:
- Android: `AuthProvider` enum values (`apple`, `google`)
- Apple: `AuthProvider` enum `rawValue` properties (`"apple"`, `"google"`)

## Email Mapping Operations

### Apple Implementation (Additional Feature)
```swift
// IdentityManager+Linking.swift:179-189
func updateEmailMapping(email: String, serviceUserID: String) async throws {
    let hashedEmail = hashEmail(email)
    let emailPath = "emails/\(hashedEmail)"
    let data = serviceUserID.data(using: .utf8)!
    
    let s3Manager = S3BackupManager.shared
    if let s3Service = s3Manager.s3Service {
        try await s3Service.uploadData(data, to: emailPath)
    }
}
```

**Note**: Android doesn't currently implement email mapping, but this doesn't affect cross-platform sign-in functionality.

## Verification Results

From actual S3 data inspection:
- Current identity mappings: 1 total
- Apple identities: 1
- Google identities: 0
- Sample mapping: `identities/apple:001196.9c1591b8ce9246eeb78b745667d8d7b6.0842` → `72328ed9-4de3-429e-87b5-6aeb3bef026d`

## Conclusion

✅ **The S3 identity operations are fully compatible between Android and Apple platforms:**

1. **Identical bucket name**: `photolala`
2. **Identical path format**: `identities/{provider}:{providerID}`
3. **Identical content format**: Service User ID (UUID) as UTF-8 encoded string
4. **Identical provider naming**: `apple` and `google` (lowercase)

Users can create an account on one platform and successfully sign in on the other platform. The identity mapping system works seamlessly across both platforms.
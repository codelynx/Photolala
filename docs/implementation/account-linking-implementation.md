# Account Linking Implementation

## Overview

This document details the technical implementation of the account linking feature, including the Google Sign-In keychain error workaround and complete provider unlinking functionality.

## Key Components

### 1. Multi-Provider Authentication

**PhotolalaUser Model Enhancement**:
```swift
struct PhotolalaUser: Codable {
    let serviceUserID: String
    let primaryProvider: AuthProvider
    let primaryProviderID: String
    var linkedProviders: [ProviderLink] = []
    // ... other properties
}

struct ProviderLink: Codable {
    let provider: AuthProvider
    let providerID: String
    let linkedAt: Date
}
```

### 2. Google Sign-In Keychain Error Workaround

**Problem**: Google Sign-In SDK returns error code -2 when accessing keychain in sandboxed macOS app.

**Solution**: Implemented web-based OAuth fallback in `GoogleAuthProvider+Web.swift`:

```swift
func signInWithWebFlow() async throws -> AuthCredential {
    // Use ASWebAuthenticationSession for OAuth flow
    // Exchange authorization code for tokens
    // Decode JWT to extract user info
    // Return AuthCredential
}
```

**Key Features**:
- Uses standard OAuth 2.0 authorization code flow
- JWT decoding for user info extraction
- Removes `prompt=select_account` to avoid double sign-in
- Full error handling and logging

### 3. Keychain Failure Handling

**Enhancement**: Made Keychain failures non-fatal in `IdentityManager+Authentication.swift`:

```swift
private func saveUser(_ user: PhotolalaUser) {
    do {
        try KeychainManager.shared.save(userData, for: keychainKey)
    } catch {
        print("[IdentityManager] Keychain save failed: \(error), continuing anyway")
        // Don't throw - S3 persistence is sufficient
    }
}
```

**Rationale**: S3 persistence is the primary source of truth, Keychain is for convenience.

### 4. Complete Provider Unlinking

**Implementation** in `IdentityManager+Linking.swift`:

```swift
func unlinkProvider(_ provider: AuthProvider) async throws {
    // 1. Update local state
    currentUser?.linkedProviders.removeAll { $0.provider == provider }
    
    // 2. Delete S3 identity mapping
    let identityPath = "identities/\(provider.rawValue):\(providerID)"
    try await s3Service.deleteObject(at: identityPath)
    
    // 3. Save updated user
    saveUser(currentUser!)
}
```

**S3BackupService Enhancement**:
```swift
func deleteObject(at path: String) async throws {
    let deleteInput = DeleteObjectInput(bucket: bucketName, key: path)
    _ = try await client.deleteObject(input: deleteInput)
}
```

### 5. UI Components

**LinkedProvidersView**:
- Shows all linked providers with unlink buttons
- "Link Another Sign-In Method" button
- Confirmation dialog for unlinking
- Modern card-based design

**AccountSettingsView Redesign**:
- User header with avatar and name
- Storage usage progress bar
- Subscription info card
- Linked providers section
- Modern gradients and shadows

## Security Considerations

1. **Authentication Tokens**: Never stored locally, only provider IDs
2. **S3 Identity Mappings**: Only contain UUID references
3. **Keychain Access**: Graceful fallback if unavailable
4. **Provider Validation**: Prevents duplicate linking

## Error Handling

1. **Google Sign-In Keychain Error**:
   - Detected by error code -2
   - Automatic retry with state clearing
   - Falls back to web-based OAuth

2. **Provider Already Linked**:
   - Clear error message
   - Prevents duplicate linking

3. **Cannot Unlink Last Provider**:
   - UI validation prevents this
   - Server-side check as backup

## Testing Performed

1. **Google Sign-In**:
   - ✅ SDK authentication (when keychain works)
   - ✅ Web fallback (when keychain fails)
   - ✅ No double sign-in prompt

2. **Provider Linking**:
   - ✅ Link Apple to Google account
   - ✅ Link Google to Apple account
   - ✅ Prevent duplicate linking

3. **Provider Unlinking**:
   - ✅ Unlink with confirmation
   - ✅ S3 identity mapping deleted
   - ✅ Cannot unlink last provider

## Implementation Timeline

1. **Session Start**: 
   - User reported Google Sign-In keychain error
   - Investigated and added logging

2. **Keychain Error Debugging**:
   - Identified Google SDK error code -2
   - Implemented retry logic
   - Created web-based OAuth fallback

3. **UI Enhancement**:
   - Redesigned AccountSettingsView
   - Added modern styling

4. **Complete Unlinking**:
   - Implemented S3 deletion
   - Added confirmation dialogs
   - Tested end-to-end

## Code Organization

```
apple/Photolala/
├── Services/
│   ├── IdentityManager+Authentication.swift  # Core auth logic
│   ├── IdentityManager+Linking.swift        # Account linking
│   ├── GoogleAuthProvider.swift             # Google Sign-In SDK
│   ├── GoogleAuthProvider+Web.swift         # Web OAuth fallback
│   └── S3BackupService.swift               # Added deleteObject()
├── Views/
│   ├── AccountSettingsView.swift           # Main settings UI
│   ├── LinkedProvidersView.swift          # Provider management
│   └── AccountLinkingPrompt.swift         # Linking flow UI
└── Models/
    └── PhotolalaUser.swift                # User model with providers
```

## Future Improvements

1. **Provider Management**:
   - Audit trail of link/unlink actions
   - Email notifications for security
   - Support for more providers

2. **Error Recovery**:
   - Retry mechanisms for S3 operations
   - Better offline handling
   - Sync conflict resolution

3. **Performance**:
   - Cache provider status
   - Batch S3 operations
   - Background sync
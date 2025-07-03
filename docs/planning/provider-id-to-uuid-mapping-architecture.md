# Provider ID to UUID Mapping Architecture

## Implementation Status: ✅ COMPLETED (July 3, 2025)

## Overview

This document describes the identity mapping system that allows multiple authentication providers (Apple ID, Google ID) to map to a single internal UUID for S3 storage, while maintaining the ability to look up users by their provider IDs.

## Problem Statement

- UUIDs like `a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m` are not human-readable and impossible to reverse lookup
- Users authenticate with provider-specific IDs (Apple ID: `001234.5678abcd.9012`, Google ID: `123456789012345678901`)
- Need to map provider IDs to internal UUIDs for consistent S3 storage
- Must support multiple providers per user

## Solution: Provider ID Lookup Table

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Identity Mapping System                       │
│                                                                  │
│  Provider IDs (from JWT)          Lookup Table                  │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │ Apple ID:           │────────▶│ Provider → UUID Map │       │
│  │ 001234.5678abcd... │         │                     │       │
│  └─────────────────────┘         │ apple:001234... →  │       │
│                                  │   uuid123...       │       │
│  ┌─────────────────────┐         │                     │       │
│  │ Google ID:          │────────▶│ google:123456... → │       │
│  │ 123456789012345... │         │   uuid123...       │       │
│  └─────────────────────┘         └─────────────────────┘       │
│                                           │                      │
│                                           ▼                      │
│                                  ┌─────────────────────┐       │
│                                  │ Service User ID    │       │
│                                  │ (UUID)             │       │
│                                  │ a3f4d5e6-b7c8...   │       │
│                                  └─────────────────────┘       │
│                                           │                      │
│                                           ▼                      │
│                                  ┌─────────────────────┐       │
│                                  │ S3 Storage Path    │       │
│                                  │ /users/{uuid}/     │       │
│                                  └─────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### Lookup Table Structure

The lookup table stores mappings from provider IDs to UUIDs:

```
Key Format: {provider}:{providerID}
Value: {serviceUserID}

Examples:
apple:001234.5678abcd.9012 → a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m
google:123456789012345678901 → a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m
```

## Implementation Details

### 1. Sign In Flow

```swift
func signIn(with provider: AuthProvider) async throws -> PhotolalaUser {
    // Step 1: Authenticate and get provider ID from JWT
    let credential = try await authenticate(with: provider)
    let providerID = credential.providerID // e.g., "001234.5678abcd.9012"
    
    // Step 2: Look up UUID using provider ID
    let lookupKey = "\(provider.rawValue):\(providerID)"
    
    if let serviceUserID = try await lookupProviderMapping(lookupKey) {
        // Found existing user
        let user = try await loadUser(serviceUserID: serviceUserID)
        return user
    } else {
        // No account found
        throw AuthError.noAccountFound
    }
}
```

### 2. Create Account Flow

```swift
func createAccount(with provider: AuthProvider) async throws -> PhotolalaUser {
    // Step 1: Authenticate and get provider ID from JWT
    let credential = try await authenticate(with: provider)
    let providerID = credential.providerID
    
    // Step 2: Check if provider ID already exists
    let lookupKey = "\(provider.rawValue):\(providerID)"
    
    if let _ = try await lookupProviderMapping(lookupKey) {
        // Account already exists
        throw AuthError.accountAlreadyExists
    }
    
    // Step 3: Generate new UUID
    let serviceUserID = UUID().uuidString.lowercased()
    
    // Step 4: Create provider mapping
    try await createProviderMapping(
        lookupKey: lookupKey,
        serviceUserID: serviceUserID
    )
    
    // Step 5: Create user
    let newUser = PhotolalaUser(
        serviceUserID: serviceUserID,
        primaryProvider: provider,
        primaryProviderID: providerID,
        // ... other fields
    )
    
    try await saveUser(newUser)
    return newUser
}
```

### 3. Link Additional Provider

```swift
func linkProvider(_ provider: AuthProvider, to user: PhotolalaUser) async throws {
    // Step 1: Authenticate with new provider
    let credential = try await authenticate(with: provider)
    let providerID = credential.providerID
    
    // Step 2: Check if provider ID is already linked
    let lookupKey = "\(provider.rawValue):\(providerID)"
    
    if let existingUserID = try await lookupProviderMapping(lookupKey) {
        if existingUserID != user.serviceUserID {
            throw AuthError.providerAlreadyLinkedToAnotherAccount
        }
        // Already linked to this user, nothing to do
        return
    }
    
    // Step 3: Create new provider mapping
    try await createProviderMapping(
        lookupKey: lookupKey,
        serviceUserID: user.serviceUserID
    )
    
    // Step 4: Update user record
    var updatedUser = user
    updatedUser.linkedProviders.append(ProviderLink(
        provider: provider,
        providerID: providerID,
        linkedAt: Date()
    ))
    
    try await saveUser(updatedUser)
}
```

## Storage Implementation Options

### Option 1: Local Storage (Initial MVP)

Store mappings in Keychain/UserDefaults:

```swift
// Keychain keys
"provider_mapping:apple:001234.5678abcd.9012" → "a3f4d5e6-b7c8..."
"provider_mapping:google:123456789012345678901" → "a3f4d5e6-b7c8..."
```

### Option 2: S3-Based Lookup (No Backend)

Store mappings in S3 with clear directory structure:

```
photolala/
├── identities/                         # External provider ID → UUID lookups
│   ├── apple/
│   │   └── 001234.5678abcd.9012      # Plain text file containing UUID
│   └── google/
│       └── 123456789012345678901      # Plain text file containing UUID
│
└── users/                              # UUID-based user data storage
    └── a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m/
        ├── photos/
        │   └── {md5}.jpg
        ├── thumbnails/
        │   └── {md5}_thumb.jpg
        ├── metadata/
        │   └── catalog.json
        └── account/
            ├── profile.json            # User profile and subscription
            └── providers.json          # Reverse lookup of linked providers
```

**Mapping File Format** (Plain text for efficiency):
- File: `/identities/apple/001234.5678abcd.9012`
- Content: `a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m` (just the UUID)
- Size: ~36 bytes

**Alternative JSON Format** (if metadata needed):
```json
{
  "serviceUserID": "a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m",
  "created": "2024-01-15T10:30:00Z",
  "lastAccessed": "2024-03-20T15:45:00Z"
}
```

### Option 3: Backend Service (Future)

```
POST /api/auth/lookup
{
    "provider": "apple",
    "providerID": "001234.5678abcd.9012"
}

Response:
{
    "serviceUserID": "a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m",
    "user": { ... }
}
```

## Benefits

1. **Human-Readable Lookups**: Can trace provider IDs to UUIDs for debugging
2. **Multi-Provider Support**: Multiple provider IDs map to single UUID
3. **Consistent Storage**: All user data stored under single UUID path
4. **Provider Independence**: Can add new providers without changing storage structure
5. **Migration Path**: Easy to migrate from local to backend storage

## Example Scenario

1. **Bob signs up with Apple**:
   - Apple JWT provides ID: `001234.5678abcd.9012`
   - System generates UUID: `a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m`
   - Creates mapping: `apple:001234.5678abcd.9012 → a3f4d5e6-b7c8...`
   - S3 storage at: `/users/a3f4d5e6-b7c8.../`

2. **Bob gets Android phone, links Google**:
   - Google JWT provides ID: `123456789012345678901`
   - System creates mapping: `google:123456789012345678901 → a3f4d5e6-b7c8...`
   - Both providers now access same S3 storage

3. **Bob signs in on any device**:
   - With Apple: Lookup `apple:001234...` → finds UUID → accesses photos
   - With Google: Lookup `google:123456...` → finds same UUID → accesses same photos

## Security Considerations

1. **Provider ID Privacy**: Store hashed provider IDs if concerned about privacy
2. **Access Control**: Ensure users can only create mappings for their authenticated IDs
3. **Audit Trail**: Log all mapping operations for security review
4. **Rate Limiting**: Prevent brute force lookups

## S3 Implementation Details

### Lookup Operations

**Sign In Flow**:
```
1. Authenticate with Apple → Get provider ID: 001234.5678abcd.9012
2. S3 GET: /identities/apple/001234.5678abcd.9012
3. Response: a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m
4. S3 LIST: /users/a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m/photos/
5. User sees their photos
```

**Create Account Flow**:
```
1. Authenticate with Apple → Get provider ID: 001234.5678abcd.9012
2. S3 HEAD: /identities/apple/001234.5678abcd.9012 (check existence)
3. 404 Not Found → Proceed with account creation
4. Generate UUID: a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m
5. S3 PUT: /identities/apple/001234.5678abcd.9012 (content: UUID)
6. S3 PUT: /users/a3f4d5e6-b7c8.../account/profile.json
7. S3 PUT: /users/a3f4d5e6-b7c8.../account/providers.json
```

### Providers.json Structure

Located at `/users/{uuid}/account/providers.json` for reverse lookup:

```json
{
  "version": 1,
  "primaryProvider": "apple",
  "providers": [
    {
      "type": "apple",
      "id": "001234.5678abcd.9012",
      "email": "bob@icloud.com",
      "displayName": "Bob Smith",
      "linkedAt": "2024-01-15T10:30:00Z",
      "lastUsed": "2024-03-20T15:45:00Z",
      "isPrimary": true
    },
    {
      "type": "google",
      "id": "123456789012345678901",
      "email": "bob@gmail.com",
      "displayName": "Bob S",
      "linkedAt": "2024-03-01T14:20:00Z",
      "lastUsed": "2024-03-19T09:30:00Z",
      "isPrimary": false
    }
  ]
}
```

### Profile.json Structure

Located at `/users/{uuid}/account/profile.json`:

```json
{
  "version": 1,
  "serviceUserID": "a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m",
  "displayName": "Bob Smith",
  "email": "bob@icloud.com",
  "createdAt": "2024-01-15T10:30:00Z",
  "lastUpdated": "2024-03-20T15:45:00Z",
  "subscription": {
    "tier": "essential",
    "startDate": "2024-01-15T10:30:00Z",
    "expiryDate": "2024-04-15T10:30:00Z",
    "storageLimit": 214748364800,
    "storageUsed": 53687091200
  },
  "preferences": {
    "uploadQuality": "high",
    "autoBackup": true,
    "wifiOnlyBackup": true
  }
}
```

## Implementation Priority

1. **Phase 1**: Local Keychain storage for provider mappings
   - Quick MVP implementation
   - Single device only
   - Good for testing

2. **Phase 2**: S3-based lookup for cross-device sync
   - Use `/identities/` directory structure
   - Plain text files for mappings
   - JSON files for user profiles
   - No backend required

3. **Phase 3**: Backend service for centralized management
   - API-based lookups
   - Better performance with caching
   - Support for complex queries

## Performance Considerations

### S3 Lookup Performance

- **Identity lookup**: Single S3 GET request (~50-100ms)
- **Small file size**: 36 bytes for UUID
- **Cacheable**: Can cache locally after first lookup
- **CDN-friendly**: Could use CloudFront for faster global access

### Optimization Strategies

1. **Local Cache**: Cache identity mappings in Keychain after first lookup
2. **Prefetch**: When showing provider selection, prefetch both potential mappings
3. **Batch Operations**: When linking accounts, batch S3 operations
4. **Eventual Consistency**: Design for S3's eventual consistency model

## Bob's Complete Journey

### Day 1: Bob Signs Up with Apple

1. **Bob taps "Create Account"** → **"Sign up with Apple"**
2. **Apple returns**: Provider ID = `001234.5678abcd.9012`
3. **System checks**: S3 HEAD `/identities/apple/001234.5678abcd.9012` → 404 Not Found ✓
4. **System generates**: UUID = `a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m`
5. **System creates**:
   ```
   /identities/apple/001234.5678abcd.9012 (contains: a3f4d5e6-b7c8...)
   /users/a3f4d5e6-b7c8.../account/profile.json
   /users/a3f4d5e6-b7c8.../account/providers.json
   ```
6. **Bob starts uploading photos** to `/users/a3f4d5e6-b7c8.../photos/`

### Day 30: Bob Returns (Correct Provider)

1. **Bob taps "Sign In"** → **"Sign in with Apple"**
2. **Apple returns**: Provider ID = `001234.5678abcd.9012`
3. **System looks up**: S3 GET `/identities/apple/001234.5678abcd.9012`
4. **Returns**: `a3f4d5e6-b7c8-9d0e-1f2g-3h4i5j6k7l8m`
5. **System loads**: `/users/a3f4d5e6-b7c8.../account/profile.json`
6. **Bob sees all his photos**

### Day 60: Bob Forgets (Wrong Provider)

1. **Bob taps "Sign In"** → **"Sign in with Google"**
2. **Google returns**: Provider ID = `123456789012345678901`
3. **System looks up**: S3 GET `/identities/google/123456789012345678901`
4. **Returns**: 404 Not Found
5. **Shows error**: "No account found with Google. Try Apple or create new account."
6. **Bob realizes**: "Oh right, I used Apple!"

### Day 90: Bob Links Google

1. **Bob is signed in** → **Settings** → **"Link Google Account"**
2. **Google returns**: Provider ID = `123456789012345678901`
3. **System checks**: S3 HEAD `/identities/google/123456789012345678901` → 404 ✓
4. **System creates**: `/identities/google/123456789012345678901` (contains: a3f4d5e6-b7c8...)
5. **Updates**: `/users/a3f4d5e6-b7c8.../account/providers.json` to include Google
6. **Now Bob can sign in with either provider**

## Implementation Details

### iOS/macOS Files Modified
1. **IdentityManager+Authentication.swift**
   - `createS3UserFolders()`: Creates identity mapping files
   - `findUserByProviderID()`: Checks S3 when user not found locally
   - Reconstructs user from S3 mapping on cross-device sign-in

2. **S3BackupService.swift**
   - Added `uploadData()` and `downloadData()` generic methods
   - Used for identity file operations

3. **S3BackupManager.swift**
   - Added `createFolder()` and `uploadData()` wrapper methods

### Android Implementation (July 3, 2025)
1. **IdentityManager.kt**
   - `createS3UserFolders()`: Creates identity mapping files
   - `findUserByProviderID()`: Checks S3 when user not found locally
   - Complete sign-up/sign-in flow with intent handling
   - Android Keystore encryption for secure storage

2. **S3Service.kt**
   - Added `uploadData()`, `downloadData()`, and `createFolder()` methods
   - Matches iOS functionality for identity operations

3. **SecurityUtils.kt**
   - Android Keystore implementation with AES/GCM encryption
   - Secure storage of user credentials

4. **Data Models**
   - PhotolalaUser, AuthProvider, AuthCredential, ProviderLink
   - Kotlinx.serialization support with custom DateSerializer

### Key Implementation Points
- Identity mappings stored at `/identities/{provider}:{providerID}`
- File contains only the UUID as plain text
- Sign-in flow: Local encrypted storage → S3 identity lookup → Reconstruct user
- User properties (email, fullName) updated from fresh JWT on sign-in
- Supports cross-device authentication seamlessly
- Consistent implementation across all platforms (iOS, macOS, Android)

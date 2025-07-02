# Authentication Implementation Summary

## Overview

This document summarizes the authentication strategy for Photolala, consolidating decisions from multiple planning documents.

## Key Decisions

### 1. Explicit Signup/Signin Flow
- **Separate "Sign In" and "Create Account" buttons** on welcome screen
- Prevents users from accidentally creating duplicate accounts
- Solves the "forgotten provider" problem (Bob's scenario)
- Clear user intent and better UX

### 2. Single Service User ID
- Each user has one `serviceUserID` (UUID) for S3 storage
- This UUID is generated during account creation
- All providers link to this single UUID
- S3 folder structure: `/users/{serviceUserID}/`

### 3. Provider Strategy
- **iOS/macOS**: Sign in with Apple (primary), Google (secondary)
- **Android**: Sign in with Google (primary), Apple (optional later)
- Both providers available on all platforms eventually

## Authentication Flow

### Create Account (New Users)
1. User taps "Create Account"
2. Chooses provider (Apple/Google)
3. Authenticates with provider
4. System generates new `serviceUserID` (UUID)
5. Creates user record linking provider ID → serviceUserID
6. Creates S3 folder structure
7. User enters app

### Sign In (Existing Users)
1. User taps "Sign In"
2. Chooses provider
3. Authenticates with provider
4. System looks up serviceUserID by provider ID
5. If found: User enters app
6. If not found: "No account found. Please create an account first."

### Account Linking (Future)
1. User signs in with primary provider
2. In Settings: "Link Another Account"
3. Authenticates with new provider
4. System links new provider ID to existing serviceUserID
5. User can now sign in with either provider

## Technical Implementation

### User Model
```swift
struct PhotolalaUser {
    let serviceUserID: String          // UUID for S3
    let primaryProvider: AuthProvider  // First provider used
    let primaryProviderID: String      // Provider's user ID
    var linkedProviders: [ProviderLink] = []
    // ... other fields
}
```

### Storage
- **Local**: Keychain (iOS/macOS) / KeyStore (Android)
- **Cloud**: S3 at `/users/{serviceUserID}/`
- **Mapping**: Provider ID → Service User ID stored locally

### Security
- Provider handles authentication (we trust their JWT/tokens)
- UUID generation for serviceUserID prevents conflicts
- Keychain/KeyStore for secure credential storage
- Future: Backend validation of JWTs

## Implementation Phases

### Phase 1: Core Authentication (Current)
- Explicit signup/signin flows
- Single provider per platform
- Local storage only

### Phase 2: Cross-Platform (Next)
- Add secondary providers
- Manual account linking
- Email-based discovery

### Phase 3: Backend Integration (Future)
- Server-side JWT validation
- Centralized user management
- Advanced security features

## Benefits of This Approach

1. **No Duplicate Accounts**: Users can't accidentally create multiple accounts
2. **Clear Mental Model**: Users understand signup vs signin
3. **Provider Flexibility**: Support multiple providers per user
4. **Future-Proof**: Ready for backend integration
5. **Platform-Native**: Respects platform conventions

## Migration

Existing Sign in with Apple users:
- Keep their current serviceUserID
- Update to new user model structure
- No disruption to service
- Can link Google account later

## Related Documents

1. **[authentication-strategy.md](./authentication-strategy.md)** - Original strategy document
2. **[multi-provider-authentication-aggregation.md](./multi-provider-authentication-aggregation.md)** - Detailed multi-provider handling
3. **[signup-process-technical-details.md](./signup-process-technical-details.md)** - Technical implementation of signup flow
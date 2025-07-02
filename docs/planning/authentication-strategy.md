# Authentication Strategy for Photolala

## Overview

This document outlines the authentication strategy for Photolala across Apple (iOS/macOS/tvOS) and Android platforms, including implementation of Sign in with Apple and Sign in with Google with explicit signup/signin flows to prevent duplicate accounts.

**Key Decision**: Implement separate "Sign In" and "Create Account" flows to prevent users from accidentally creating multiple accounts when they forget which provider they used.

## Related Documents

- **[multi-provider-authentication-aggregation.md](./multi-provider-authentication-aggregation.md)**: Detailed strategy for handling multiple auth providers and account linking
- **[signup-process-technical-details.md](./signup-process-technical-details.md)**: Technical implementation details of the signup flow from JWT to S3 setup

## Current State

### Apple Platforms (iOS/macOS/tvOS)
- **Implemented**: Sign in with Apple
- **Architecture**: Native AuthenticationServices framework
- **Storage**: Keychain for secure credential storage
- **User Model**: Internal service ID + Apple user ID
- **Subscription System**: Tiered storage plans (Free, Starter, Essential, Plus, Family)

### Android Platform
- **Implemented**: None
- **Current State**: No user authentication
- **AWS Integration**: Basic credential management only

## Authentication Requirements

### Business Requirements
1. Support multiple authentication providers (Apple, Google)
2. Maintain consistent user experience across platforms
3. Enable cross-platform user accounts
4. Support offline/local-only usage
5. Integrate with subscription system
6. Secure credential storage

### Technical Requirements
1. Native authentication flows
2. Secure token management
3. Graceful fallback for auth failures
4. Support for anonymous users
5. Migration path for existing users

## Proposed Architecture

### 1. Multi-Provider Authentication Model

```swift
// Enhanced user model supporting multiple providers
struct PhotolalaUser: Codable {
    let serviceUserID: String          // Internal UUID
    let authProvider: AuthProvider     // Apple, Google, etc.
    let providerUserID: String         // Provider-specific ID
    let email: String?
    let fullName: String?
    let photoURL: String?              // Profile photo (Google)
    let createdAt: Date
    var linkedAccounts: [LinkedAccount]? // Other linked providers
    var subscription: Subscription?
}

enum AuthProvider: String, Codable {
    case apple = "apple"
    case google = "google"
    case email = "email"    // Future option
}

struct LinkedAccount: Codable {
    let provider: AuthProvider
    let providerUserID: String
    let linkedAt: Date
}
```

### 2. Platform-Specific Implementations

#### Apple Platforms (iOS/macOS)

**Sign in with Apple** (Existing)
- Continue using AuthenticationServices framework
- Maintain current implementation

**Sign in with Google** (New)
- Use Google Sign-In SDK for iOS
- Installation via Swift Package Manager
- Required configuration:
  - OAuth 2.0 client ID
  - URL schemes in Info.plist
  - Keychain sharing for credential storage

```swift
// Example Google Sign-In integration
import GoogleSignIn

class GoogleAuthProvider: AuthProviderProtocol {
    func signIn() async throws -> AuthCredential {
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController
        )
        
        return AuthCredential(
            provider: .google,
            userID: result.user.userID,
            email: result.user.profile?.email,
            fullName: result.user.profile?.name,
            photoURL: result.user.profile?.imageURL(withDimension: 200)
        )
    }
}
```

#### Android Platform

**Sign in with Google** (Primary)
- Native Google Sign-In for Android
- Uses Google Play Services
- Seamless integration with Android accounts

```kotlin
// Example Android implementation
class GoogleAuthProvider(private val context: Context) : AuthProvider {
    private val googleSignInClient: GoogleSignInClient
    
    init {
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestEmail()
            .requestProfile()
            .build()
            
        googleSignInClient = GoogleSignIn.getClient(context, gso)
    }
    
    suspend fun signIn(): AuthCredential {
        val account = googleSignInClient.silentSignIn().await()
        return AuthCredential(
            provider = AuthProvider.GOOGLE,
            userId = account.id ?: "",
            email = account.email,
            displayName = account.displayName,
            photoUrl = account.photoUrl?.toString()
        )
    }
}
```

**Sign in with Apple** (Secondary)
- Use Apple ID SDK for Android
- Requires web-based flow
- Additional configuration needed

### 3. Backend Integration Options

#### Option A: Direct Provider Integration (Recommended for MVP)
- Each platform handles auth independently
- User accounts linked by email
- Simple implementation, no backend required

**Pros:**
- Quick to implement
- No server infrastructure
- Platform-native experience

**Cons:**
- No true cross-platform accounts
- Difficult to manage subscriptions across platforms
- Limited user account management

#### Option B: Custom Backend Service
- Central authentication service
- Token exchange with providers
- Unified user management

**Architecture:**
```
Mobile App -> Auth Provider -> Backend Service -> Database
                                     |
                                     v
                              JWT/Session Token
```

**Pros:**
- True cross-platform accounts
- Centralized subscription management
- Better security control

**Cons:**
- Requires backend development
- Additional infrastructure cost
- More complex implementation

#### Option C: Firebase Authentication (Hybrid Approach)
- Use Firebase Auth as authentication broker
- Supports multiple providers out-of-box
- Can integrate with custom backend later

**Pros:**
- Quick implementation
- Built-in security
- Easy provider management
- Real-time user sync

**Cons:**
- Firebase dependency
- Potential vendor lock-in
- Cost at scale

### 4. Implementation Phases

#### Phase 1: Android Authentication (Priority)
1. Implement Google Sign-In for Android
2. Create Android user model matching iOS structure
3. Implement secure credential storage (Android Keystore)
4. Add sign-in UI components
5. Test subscription flow

#### Phase 2: Google Sign-In for Apple Platforms
1. Add Google Sign-In SDK to iOS/macOS
2. Extend IdentityManager for multiple providers
3. Update UI to show provider options
4. Test cross-provider scenarios

#### Phase 3: Cross-Platform Account Linking
1. Implement email-based account linking
2. Add account management UI
3. Handle provider switching
4. Test migration scenarios

#### Phase 4: Backend Integration (Future)
1. Design backend API
2. Implement token exchange
3. Migrate existing users
4. Add advanced features (2FA, SSO)

### 5. Security Considerations

#### Token Storage
- **iOS/macOS**: Keychain Services
- **Android**: Android Keystore
- **Encryption**: AES-256 for sensitive data
- **Token Rotation**: Implement refresh token flow

#### Best Practices
1. Never store passwords
2. Use secure random session IDs
3. Implement token expiration
4. Clear credentials on sign out
5. Validate tokens server-side (when backend exists)

### 6. UI/UX Guidelines

#### Sign-In Screen Design
```
┌─────────────────────────────┐
│      Photolala Logo         │
│                             │
│  ┌───────────────────────┐  │
│  │  Sign in with Apple   │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │  Sign in with Google  │  │
│  └───────────────────────┘  │
│                             │
│  ─────── or ───────        │
│                             │
│  [ Browse Locally Only ]    │
│                             │
└─────────────────────────────┘
```

#### Platform-Specific Considerations
- **iOS/macOS**: Use native button styles
- **Android**: Follow Material Design guidelines
- **All**: Consistent branding and messaging

### 7. Data Privacy & Compliance

#### Data Collection
- Minimal data collection (email, name)
- Optional profile photo
- Clear privacy policy
- User consent for data usage

#### GDPR Compliance
- Right to deletion
- Data portability
- Clear consent mechanisms
- Privacy by design

### 8. Testing Strategy

#### Unit Tests
- Authentication flow mocking
- Token validation
- Error handling
- Provider switching

#### Integration Tests
- Real provider authentication
- Cross-platform scenarios
- Subscription flow
- Account linking

#### User Acceptance Tests
- Sign-in success rate
- Error message clarity
- Performance metrics
- Accessibility compliance

### 9. Migration Plan

#### Existing iOS Users
1. Maintain current Sign in with Apple
2. Prompt to link Google account (optional)
3. No forced migration
4. Preserve all user data

#### New Users
1. Show all provider options
2. Encourage platform-native choice
3. Explain benefits of each
4. Allow anonymous browsing

### 10. Success Metrics

- Sign-in conversion rate > 60%
- Authentication success rate > 95%
- Cross-platform account linking > 30%
- User satisfaction score > 4.5/5
- Support ticket reduction by 40%

## Recommendation

For immediate implementation:
1. **Android**: Implement Google Sign-In (native experience)
2. **iOS/macOS**: Add Google Sign-In as secondary option
3. **Backend**: Start with Option A (direct integration), plan for Option B
4. **Timeline**: 4-6 weeks for Phase 1 & 2

This approach provides:
- Quick market entry for Android
- Consistent experience across platforms
- Foundation for future enhancements
- Minimal infrastructure requirements

## Next Steps

1. Review and approve this strategy
2. Set up Google Cloud Console project
3. Obtain OAuth 2.0 credentials
4. Begin Android implementation
5. Create detailed technical specifications
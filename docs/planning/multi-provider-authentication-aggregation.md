# Multi-Provider Authentication Aggregation Strategy

## Executive Summary

This document outlines the strategy for supporting multiple authentication providers (Sign in with Apple, Sign in with Google) while maintaining a single, unified user identity for S3 storage in Photolala. The approach ensures users can sign in with their preferred provider while their photos are backed up to a single S3 location, regardless of which provider they use.

## Problem Statement

### Current Situation
- Photolala currently supports Sign in with Apple on iOS/macOS
- Each user has a `serviceUserID` (internal UUID) that maps to their S3 storage location
- Plans to add Sign in with Google for Android and as a secondary option for Apple platforms
- Implementing explicit signup/signin flow to prevent duplicate accounts

### Challenge
- Users may want to sign in with different providers on different devices
- Need to ensure the same user (human) maps to the same S3 storage location
- Must handle scenarios where users have different emails across providers
- Prevent users from accidentally creating multiple accounts
- Maintain security while providing convenience

## Proposed Solution: Hybrid Email-Based Linking with Future Backend Support

### Core Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     User Identity                        │
│                                                          │
│  ┌─────────────┐     ┌──────────────────┐              │
│  │  Apple ID   │────▶│                   │              │
│  └─────────────┘     │   serviceUserID   │────▶ S3      │
│  ┌─────────────┐     │   (UUID - single) │     Storage  │
│  │  Google ID  │────▶│                   │              │
│  └─────────────┘     └──────────────────┘              │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Key Principles

1. **One serviceUserID per User**: Each human user has exactly one `serviceUserID` (UUID) that determines their S3 storage location
2. **Multiple Provider IDs**: A single `serviceUserID` can be associated with multiple provider IDs (Apple ID, Google ID)
3. **Email-Based Discovery**: Initially use email as the primary method to identify existing users
4. **Explicit Linking Option**: Allow users to manually link accounts in settings
5. **Future-Proof Design**: Structure ready for backend service when needed

## Implementation Details

### 1. Enhanced User Model

```swift
// Core user identity
struct PhotolalaUser: Codable {
    // Primary identity
    let serviceUserID: String          // UUID for S3 storage
    let primaryProvider: AuthProvider  // First provider used
    let primaryProviderID: String      // ID from primary provider
    
    // User information
    let email: String?                 // Primary email (may be masked)
    let fullName: String?
    let photoURL: String?              // Profile photo URL
    let createdAt: Date
    let lastUpdated: Date
    
    // Linked accounts
    var linkedProviders: [ProviderLink] = []
    
    // Account settings
    var subscription: Subscription?
    var preferences: UserPreferences?
}

struct ProviderLink: Codable {
    let provider: AuthProvider
    let providerID: String
    let email: String?            // Provider-specific email
    let linkedAt: Date
    let linkMethod: LinkMethod    // How it was linked
}

enum AuthProvider: String, Codable {
    case apple = "apple"
    case google = "google"
}

enum LinkMethod: String, Codable {
    case emailMatch = "email_match"      // Automatic via email
    case userInitiated = "user_initiated" // Manual linking
    case support = "support"              // Support intervention
}
```

### 2. Explicit Signup/Signin Flow

#### Separate Signup and Signin to Prevent Duplicate Accounts

The authentication flow explicitly separates account creation from signin:
- **Clear user intent**: Users choose "Sign In" or "Create Account"
- **Prevents forgotten provider issue**: Can't accidentally create duplicate accounts
- **Provider authentication**: Both flows use provider authentication (Apple/Google)
- **Single serviceUserID**: Each user gets one UUID for S3 storage

#### A. Sign In Flow (Existing Users)

```swift
extension IdentityManager {
    func signIn(with provider: AuthProvider) async throws -> PhotolalaUser {
        // Step 1: Authenticate with provider
        let credential = try await authenticate(with: provider)
        
        // Step 2: Look up existing user
        guard let existingUser = try await findUserByProviderID(
            provider: credential.provider,
            providerID: credential.providerID
        ) else {
            // No account found with this provider
            throw AuthError.noAccountFound(
                message: "No account found. Please create an account first.",
                provider: provider
            )
        }
        
        // Step 3: Update last seen and return
        existingUser.lastUpdated = Date()
        try await saveUser(existingUser)
        
        return existingUser
    }
}

#### B. Create Account Flow (New Users)

```swift
extension IdentityManager {
    func createAccount(with provider: AuthProvider) async throws -> PhotolalaUser {
        // Step 1: Authenticate with provider
        let credential = try await authenticate(with: provider)
        
        // Step 2: Check if already exists
        if let _ = try await findUserByProviderID(
            provider: credential.provider,
            providerID: credential.providerID
        ) {
            throw AuthError.accountAlreadyExists(
                message: "Account already exists. Please sign in instead.",
                provider: provider
            )
        }
        
        // Step 3: Generate new serviceUserID (UUID for S3)
        let serviceUserID = UUID().uuidString.lowercased()
        
        // Step 4: Create new user
        let newUser = PhotolalaUser(
            serviceUserID: serviceUserID,
            primaryProvider: provider,
            primaryProviderID: credential.providerID,
            email: credential.email,
            fullName: credential.fullName,
            photoURL: credential.photoURL,
            createdAt: Date(),
            lastUpdated: Date(),
            linkedProviders: [],
            subscription: Subscription.freeTrial()
        )
        
        // Step 5: Save and create S3 structure
        try await saveUser(newUser)
        try await createS3UserFolders(for: newUser)
        
        return newUser
    }
}
```

#### C. Manual Account Linking

```swift
extension IdentityManager {
    func linkAccount(
        currentUser: PhotolalaUser,
        newProvider: AuthProvider
    ) async throws -> PhotolalaUser {
        // Step 1: Initiate sign-in with new provider
        let credential = try await authenticate(with: newProvider)
        
        // Step 2: Check if already linked to another user
        if let existingUser = try await findUserByProviderID(
            provider: credential.provider,
            providerID: credential.providerID
        ), existingUser.serviceUserID != currentUser.serviceUserID {
            throw AuthError.providerAlreadyLinked
        }
        
        // Step 3: Link to current user
        return try await linkProvider(
            to: currentUser,
            credential: credential,
            method: .userInitiated
        )
    }
}
```

### 3. S3 Storage Structure

```
photolala-backups/
└── users/
    └── {serviceUserID}/              # Single UUID per user
        ├── photos/
        │   └── {photo-hash}.jpg
        ├── thumbnails/
        │   └── {photo-hash}_thumb.jpg
        ├── metadata/
        │   └── photos.db
        └── account/
            ├── user.json             # User profile
            └── providers.json        # Linked providers
```

### 4. Security Considerations

#### A. Account Hijacking Prevention
- Never auto-link accounts with private relay emails
- Require email verification for new links (when backend available)
- Log all linking activities
- Allow users to review and unlink providers

#### B. Data Access Control
```swift
struct S3AccessPolicy {
    // Each serviceUserID can only access their own folder
    let allowedPrefix: String = "users/\(serviceUserID)/"
    
    // Temporary credentials scoped to user's folder
    func generateScopedCredentials() -> AWSCredentials {
        // Generate STS token with policy limiting to user's folder
    }
}
```

#### C. Privacy Protection
- Store minimal user information
- Hash emails for lookup (when backend available)
- Allow anonymous usage option
- Clear data deletion process

### 5. Platform Authentication Strategy

#### Platform-Native Primary Providers

**iOS/macOS**: 
- Primary: Sign in with Apple (native, seamless)
- Secondary: Sign in with Google (for cross-platform users)

**Android**:
- Primary: Sign in with Google (native, expected)
- Secondary: Sign in with Apple (for cross-platform users)
- Consider: Skip entirely on Android unless user specifically requests

**Key Principle**: Show platform-native provider prominently, others as secondary options.

#### UI Approach by Platform

**iOS/macOS Welcome Screen**:
```
[Sign in with Apple] ← Primary button (prominent)
[Sign in with Google] ← Secondary button (smaller)
```

**Android Welcome Screen**:
```
[Sign in with Google] ← Primary button (prominent)
[Other sign-in options ▼] ← Expands to show Apple
```

### 6. Implementation Phases

#### Phase 1: Local Email-Based Linking (MVP)
**Timeline: 2-3 weeks**

1. Implement enhanced user model
2. Add email-based account discovery
3. Store provider links in Keychain
4. Update UI to show linked accounts
5. Test with Apple + Google providers

**Code Changes:**
- Update `PhotolalaUser` model
- Enhance `IdentityManager` with linking logic
- Add `LinkedAccountsView` to settings
- Update `KeychainManager` for new data structure

#### Phase 2: Manual Account Linking UI
**Timeline: 1-2 weeks**

1. Add "Link Another Account" button in settings
2. Implement linking flow UI
3. Handle edge cases (already linked, conflicts)
4. Add unlink functionality

**UI Flow:**
```
Settings → Account → Linked Accounts
├── Apple ID: user@icloud.com ✓
├── Google: user@gmail.com ✓
└── [+ Link Another Account]
```

#### Phase 3: Backend Service Integration
**Timeline: 4-6 weeks (future)**

1. Design account linking API
2. Implement server-side user matching
3. Add email verification
4. Migrate local links to server
5. Enhanced security with backend validation

**API Endpoints:**
```
POST /auth/signin
POST /auth/link-account
GET  /auth/linked-accounts
POST /auth/unlink-account
GET  /users/{serviceUserID}/profile
```

### 6. User Experience Flows

#### Recommended: Explicit Account Creation Flow

**Rationale**: Prevents accidental duplicate accounts while maintaining simplicity

**Welcome Screen**:
```
Welcome to Photolala

Already have an account?
[Sign In] → Shows all providers

New to Photolala?
[Create Account] → Shows all providers
```

**Sign In Flow** (Existing Users):
```swift
func signIn(with provider: AuthProvider) async throws {
    let credential = try await authenticate(with: provider)
    
    if let user = findUser(by: credential.providerID) {
        // Found account, proceed
        proceedToApp(user: user)
    } else {
        // No account found
        showError("No account found. Please create an account first.")
        showCreateAccountOption()
    }
}
```

**Create Account Flow** (New Users):
```swift
func createAccount(with provider: AuthProvider) async throws {
    let credential = try await authenticate(with: provider)
    
    // Check if provider already used
    if userExists(with: credential.providerID) {
        showError("Account already exists. Please sign in instead.")
        return
    }
    
    // Create new account with UUID
    let newUser = PhotolalaUser(
        serviceUserID: UUID().uuidString,  // Our S3 identifier
        provider: provider,
        providerID: credential.providerID,
        email: credential.email
    )
    
    saveUser(newUser)
    proceedToApp(user: newUser)
}
```

**Benefits of This Flow**:
1. **No Duplicate Accounts**: Can't accidentally create multiple accounts
2. **Clear User Journey**: Users understand if they're signing in or creating new
3. **Provider Memory Aid**: "No account found" helps users remember correct provider
4. **Single Authentication**: Only authenticate once per action
5. **Future-Proof**: Easy to add email/password option later

#### A. First-Time User Flow
```
1. User installs app
2. Sees welcome screen with "Create Account" and "Sign In"
3. Taps "Create Account"
4. Chooses provider (Apple or Google)
5. Authenticates with provider
6. Photolala creates account:
   - Generates new serviceUserID (UUID)
   - Links to provider ID
   - Creates S3 folder at /users/{serviceUserID}/
7. User enters app with new account
```

#### B. Returning User - Correct Provider
```
1. User opens app on new device
2. Taps "Sign In"
3. Chooses same provider they used before
4. Authenticates
5. System finds their account
6. Access restored to all their photos
```

#### C. Returning User - Wrong Provider (Bob's Scenario)
```
1. Bob used Apple before, but forgot
2. Taps "Sign In"
3. Chooses Google
4. Authenticates with Google
5. System shows: "No account found with Google"
6. Options presented:
   - "Try signing in with Apple instead"
   - "Create new account with Google"
7. Bob realizes: "Oh, I must have used Apple"
8. Signs in with Apple successfully
```

#### D. Cross-Platform User - Account Linking
```
1. User has account with Apple
2. Gets Android device
3. In Settings: "Link Google Account"
4. Authenticates with Google
5. Google ID linked to same serviceUserID
6. Can now use either provider
```

### 7. Migration Strategy

#### For Existing Apple Sign-In Users
- No action required
- Their current `serviceUserID` remains unchanged
- Can optionally link Google account later

#### Database Migration
```swift
// Migration from old to new user model
func migrateUserData() {
    if let oldUser = loadOldUserModel() {
        let newUser = PhotolalaUser(
            serviceUserID: oldUser.serviceUserID,
            primaryProvider: .apple,
            primaryProviderID: oldUser.appleUserID,
            email: oldUser.email,
            fullName: oldUser.fullName,
            createdAt: oldUser.createdAt,
            lastUpdated: Date(),
            linkedProviders: [],  // No linked providers yet
            subscription: oldUser.subscription
        )
        saveNewUserModel(newUser)
    }
}
```

### 8. Error Handling

```swift
enum AuthError: LocalizedError {
    case providerAlreadyLinked
    case requiresManualLinking(existingUser: PhotolalaUser)
    case emailMismatch
    case linkingFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .providerAlreadyLinked:
            return "This account is already linked to another user"
        case .requiresManualLinking:
            return "Please link this account manually in Settings"
        case .emailMismatch:
            return "Email addresses don't match"
        case .linkingFailed(let reason):
            return "Account linking failed: \(reason)"
        }
    }
}
```

### 9. Analytics and Monitoring

Track key metrics:
- Account creation by provider
- Successful auto-links by email
- Manual linking attempts
- Failed linking attempts
- Provider usage distribution
- Cross-platform usage (users with multiple providers)

### 10. Future Enhancements

1. **Social Account Recovery**: Use linked accounts for recovery
2. **Provider Preferences**: Set preferred provider for specific features
3. **Family Sharing**: Link family member accounts
4. **Enterprise SSO**: Support for corporate authentication
5. **Biometric Linking**: Use device biometrics to verify account ownership

## Critical Design Decision: Signup vs No Signup

### The Forgotten Provider Problem

Without explicit signup, users can accidentally create multiple accounts:
- User signs in with Provider A, backs up photos
- Returns later, forgets which provider
- Signs in with Provider B, creates new empty account
- Result: Confused user, poor experience

### Recommended Approach: Intelligent Onboarding

1. **Clear Welcome Screen**: Distinguish between new and returning users
2. **Smart Detection**: Detect when a user might have an existing account
3. **Guided Recovery**: Help users find their correct provider
4. **Email-Based Linking**: Automatically link accounts when safe

This provides the simplicity of "no signup" while preventing the multiple account problem.

## Recommendation

### Implement Explicit Sign In / Create Account Flow

Based on the analysis, implementing separate "Sign In" and "Create Account" options provides the best balance:

**Advantages**:
1. **Prevents Bob's Problem**: Can't accidentally create duplicate accounts
2. **Clear Mental Model**: Users understand their account status
3. **Provider Flexibility**: Can offer both Apple and Google on all platforms
4. **Single Authentication**: Users only authenticate once (not twice)
5. **Future-Proof**: Easy to add more providers or email/password

**Implementation Priority**:

1. **Phase 1 - Core Flow**:
   - Welcome screen with "Sign In" and "Create Account"
   - Both providers available on both platforms
   - Store provider → UUID mapping in Keychain/KeyStore
   - "No account found" helps users find correct provider

2. **Phase 2 - Account Linking**:
   - Add "Link Another Provider" in settings
   - Email-based discovery for safe linking
   - Allow users to use either provider after linking

3. **Phase 3 - Enhanced UX**:
   - Smart suggestions when no account found
   - Provider usage analytics
   - Optional: Add email/password authentication

This approach solves the forgotten provider problem while maintaining simplicity and security.

## Success Criteria

1. Users can sign in with multiple providers and access the same photos
2. No duplicate S3 folders for the same user
3. Account linking process is intuitive and secure
4. Existing users experience no disruption
5. System is ready for backend integration without major refactoring
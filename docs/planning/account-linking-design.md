# Account Linking Design Document

## Overview

Account linking allows users to connect multiple authentication providers (Apple Sign-In and Google Sign-In) to the same Photolala account. This enables users to sign in with either provider and access the same photos and data.

## Current State

### User Model Structure
```swift
PhotolalaUser {
    serviceUserID: String              // UUID for S3 storage
    primaryProvider: AuthProvider      // First provider used (apple/google)
    primaryProviderID: String          // ID from primary provider
    linkedProviders: [ProviderLink]    // Additional linked providers
    email: String?                     // Primary email
    ...
}

ProviderLink {
    provider: AuthProvider
    providerID: String
    linkedAt: Date
}
```

### S3 Identity Mapping
- Primary: `/identities/{primaryProvider}:{primaryProviderID}` → serviceUserID
- Linked: `/identities/{linkedProvider}:{linkedProviderID}` → serviceUserID

## Account Linking Flow

### 1. Automatic Linking (Email Match)
When a user signs in with a new provider that has the same email as an existing account:

```
User signs in with Google (email@example.com)
  ↓
System finds existing Apple account with same email
  ↓
Prompt: "Link to existing account?"
  ↓
If Yes → Link providers
If No → Create separate account
```

### 2. Manual Linking (From Settings)
Users can manually link providers from account settings:

```
Settings → Account → Link Provider
  ↓
Choose provider (Apple/Google)
  ↓
Authenticate with provider
  ↓
Confirm linking
  ↓
Providers linked
```

## Implementation Design

### Phase 4.1: Backend Logic

#### IdentityManager Extensions

```swift
extension IdentityManager {
    /// Check if an email is already associated with an account
    func findUserByEmail(_ email: String) async throws -> PhotolalaUser? {
        // Check local storage first
        // Then check S3 for email mapping
    }
    
    /// Link a new provider to existing account
    func linkProvider(
        _ provider: AuthProvider,
        credential: AuthCredential,
        to user: PhotolalaUser
    ) async throws -> PhotolalaUser {
        // Verify credential
        // Check if provider already linked
        // Create S3 identity mapping
        // Update user's linkedProviders
        // Save updated user
    }
    
    /// Unlink a provider (keep at least one)
    func unlinkProvider(
        _ provider: AuthProvider,
        from user: PhotolalaUser
    ) async throws -> PhotolalaUser {
        // Verify not unlinking last provider
        // Remove S3 identity mapping
        // Update user's linkedProviders
        // Save updated user
    }
}
```

#### S3 Email Mapping
New S3 structure for email lookups:
```
/emails/{hashedEmail} → serviceUserID
```

### Phase 4.2: UI Implementation

#### Account Linking Prompt
When signing in with a new provider that matches an existing email:

```swift
struct AccountLinkingPrompt: View {
    let existingUser: PhotolalaUser
    let newCredential: AuthCredential
    let onLink: () -> Void
    let onCreateNew: () -> Void
    
    var body: some View {
        VStack {
            Text("Account Found")
                .font(.title)
            
            Text("An account with \(newCredential.email ?? "") already exists.")
            
            VStack(alignment: .leading) {
                Label("Existing account uses \(existingUser.primaryProvider.displayName)", 
                      systemImage: existingUser.primaryProvider.iconName)
                Label("You're signing in with \(newCredential.provider.displayName)", 
                      systemImage: newCredential.provider.iconName)
            }
            
            HStack {
                Button("Create Separate Account") {
                    onCreateNew()
                }
                
                Button("Link to Existing Account") {
                    onLink()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
```

#### Account Settings UI
Add provider management to UserAccountView:

```swift
struct LinkedProvidersSection: View {
    @ObservedObject var identityManager: IdentityManager
    
    var body: some View {
        Section("Linked Sign-In Methods") {
            // Primary provider (can't be removed)
            HStack {
                Image(systemName: user.primaryProvider.iconName)
                Text(user.primaryProvider.displayName)
                Spacer()
                Text("Primary")
                    .foregroundColor(.secondary)
            }
            
            // Linked providers
            ForEach(user.linkedProviders) { link in
                HStack {
                    Image(systemName: link.provider.iconName)
                    Text(link.provider.displayName)
                    Spacer()
                    Button("Unlink") {
                        unlinkProvider(link.provider)
                    }
                }
            }
            
            // Add provider button
            if availableProviders.count > 0 {
                Button("Link Another Sign-In Method") {
                    showLinkProvider = true
                }
            }
        }
    }
}
```

### Phase 4.3: Security Considerations

#### Email Verification
- Only auto-suggest linking for verified emails
- Show warning for unverified emails
- Consider provider trust levels

#### Conflict Resolution
- What if provider IDs already exist for different users?
- Handle edge case of multiple accounts with same email
- Provide clear merge/migration options

#### Provider Limits
- Maximum number of linked providers per account
- Rate limiting for linking attempts
- Audit trail for security

## User Flows

### Flow 1: New User with Existing Email
1. User signs up with Google (has existing Apple account)
2. System detects email match
3. Show linking prompt
4. If accepted, link providers
5. User now signed in to existing account

### Flow 2: Manual Linking from Settings
1. User goes to Settings → Account
2. Taps "Link Sign-In Method"
3. Chooses provider to link
4. Authenticates with provider
5. Confirms linking
6. Provider added to account

### Flow 3: Sign In with Linked Provider
1. User previously linked Google to Apple account
2. User signs in with Google
3. System finds identity mapping
4. User signed in to same account

## Error Handling

### Common Errors
1. **Provider Already Linked**: "This Google account is already linked"
2. **Email Mismatch**: "Email addresses don't match"
3. **Account Conflict**: "This sign-in method is already used by another account"
4. **Last Provider**: "Can't remove your only sign-in method"

### Recovery Options
- Clear instructions for each error
- Support contact for complex cases
- Account recovery flow

## Testing Plan

### Unit Tests
- Email matching logic
- Provider linking/unlinking
- S3 identity mapping
- Conflict detection

### Integration Tests
- Full linking flow
- Cross-platform linking
- Edge cases (same email, different providers)

### Manual Testing
- Link Apple to Google
- Link Google to Apple  
- Sign in with each provider
- Unlink providers
- Error scenarios

## Migration Considerations

### Existing Users
- No changes needed for single-provider users
- Backfill email mappings for existing accounts
- Clear communication about new feature

### S3 Structure
- Add `/emails/` directory
- Maintain backward compatibility
- Clean up orphaned mappings

## Success Metrics

1. **Adoption Rate**: % of users who link multiple providers
2. **Success Rate**: % of successful linking attempts
3. **Error Rate**: Track common failures
4. **Support Tickets**: Linking-related issues

## Timeline

- Day 1: Backend implementation
- Day 2: UI implementation  
- Day 3: Testing and polish

## Next Steps

1. Review design with team
2. Create feature branch
3. Implement backend logic first
4. Add UI components
5. Comprehensive testing
6. Documentation updates
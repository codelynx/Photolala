# Account Linking Feature

## Overview

The account linking feature allows users to connect multiple sign-in methods (Apple ID and Google) to a single Photolala account. This provides flexibility and redundancy - users can sign in with either method and access the same photos, backup storage, and subscription.

## User Benefits

- **Flexibility**: Sign in with whichever method is most convenient
- **Security**: If one provider has issues, use the alternate method
- **Account Recovery**: Multiple ways to access your account
- **Convenience**: Use Apple Sign In on iOS/macOS, Google on other devices

## How It Works

### Identity Mapping

Each sign-in method creates an identity mapping in S3:
```
identities/
├── apple:APPLE_USER_ID → "uuid-abc-123"
├── google:GOOGLE_USER_ID → "uuid-abc-123"
```

Both identity files contain the same Photolala UUID, linking them to the same user account.

### User Data Structure

```swift
struct PhotolalaUser {
    let serviceUserID: String          // The Photolala UUID
    let primaryProvider: AuthProvider  // First provider used
    var linkedProviders: [ProviderLink] = []  // Additional providers
}
```

## User Interface

### Accessing Account Settings

1. Click the user menu in the toolbar
2. Select "Account Settings..."
3. View the "Sign-In Methods" section

### Sign-In Methods Display

- **Primary**: The original sign-in method used to create the account
- **Linked**: Additional sign-in methods added later
- Shows provider icon, name, and when it was linked

### Linking a New Provider

1. In Account Settings, click "Link Another Sign-In Method"
2. Select the provider you want to link (Apple or Google)
3. Complete the authentication flow
4. The provider is now linked to your account

### Unlinking a Provider

- Click "Unlink" next to any linked provider
- Cannot unlink your last/only sign-in method
- Unlinking removes the ability to sign in with that method

## Implementation Details

### Key Components

1. **LinkedProvidersView.swift**: Main UI for managing linked accounts
2. **IdentityManager+Authentication.swift**: `linkProvider()` method handles the linking process
3. **IdentityManager+Linking.swift**: Helper methods for account discovery and management

### Error Handling

The system prevents common issues:
- **Provider Already Linked**: Can't link the same provider twice
- **Provider In Use**: Can't link a provider already used by another Photolala account
- **Cannot Unlink Last Provider**: Must keep at least one sign-in method

### Security Considerations

- Each provider authentication is independent
- No passwords or credentials are stored locally
- Identity mappings in S3 only contain the UUID reference
- Provider-specific tokens are managed by iOS/macOS Keychain

## Technical Flow

### First Time Sign In
1. User signs in with Apple ID
2. System generates new Photolala UUID: `uuid-abc-123`
3. Creates identity mapping: `identities/apple:APPLE_ID → uuid-abc-123`
4. Creates user folder: `users/uuid-abc-123/`

### Linking Google Account
1. User opens Account Settings
2. Clicks "Link Another Sign-In Method" → Google
3. Authenticates with Google
4. System checks if Google ID is already in use
5. Creates identity mapping: `identities/google:GOOGLE_ID → uuid-abc-123`
6. Updates user's `linkedProviders` array

### Subsequent Sign Ins
1. User can sign in with either Apple or Google
2. System looks up identity mapping to find Photolala UUID
3. Loads user data and grants access to their photos

## Error Messages

- "This sign-in method is already linked to your account"
- "This [Provider] account is already linked to a different Photolala account"
- "Cannot remove your only sign-in method"

## UX Design Decisions

### Switching Accounts
Users who want to switch accounts (e.g., from work to personal Google account) use a two-step process:
1. Unlink the current account
2. Link the new account

This approach is clearer and more flexible than a combined "Switch Account" action.

### Complete Unlinking
When unlinking a provider:
- Local state is updated immediately
- S3 identity mapping is deleted completely
- The provider cannot be used for sign-in anymore
- The same or different account can be linked later
- Confirmation dialog prevents accidental unlinking

For detailed UX documentation, see [Account Linking UX Design](./account-linking-ux.md).

## Future Enhancements

- Email-based account recovery
- Support for additional providers (Microsoft, Facebook)
- Account merging for users with multiple accounts
- Provider-specific settings and preferences
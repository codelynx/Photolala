# Authentication System Overview

Photolala implements a unified authentication system supporting multiple providers across all platforms (iOS, macOS, Android).

## Authentication Providers

### Supported Providers
1. **Apple Sign In** - Primary provider for Apple platforms
2. **Google Sign In** - Cross-platform provider
3. **Email/Password** - Traditional authentication (planned)

## Architecture

### Account Structure
- **User ID**: Unique UUID for each user account
- **Provider ID Mapping**: Maps provider-specific IDs to internal user IDs
- **Account Linking**: Allows users to link multiple providers to one account

### Authentication Flow
1. User selects authentication provider
2. Provider authentication (native flow)
3. Token exchange with backend
4. User profile creation/retrieval
5. Credential storage in Keychain/KeyStore

## Platform Implementation

### iOS/macOS
- Native Apple Sign In integration
- Google Sign In SDK
- Keychain storage for credentials
- SwiftUI authentication views

### Android
- Apple Sign In via web view bridge
- Native Google Sign In
- Encrypted SharedPreferences for credentials
- Jetpack Compose UI

## Account Management

### Account Discovery
- Email-based account lookup
- Prevents duplicate accounts
- Automatic account linking suggestions

### Credential Management
- Secure storage per platform
- Automatic token refresh
- Logout across all providers

## Backend Integration

### API Endpoints
- `/auth/signin` - Authenticate with provider token
- `/auth/verify` - Verify authentication status
- `/auth/link` - Link additional provider
- `/auth/profile` - Get/update user profile

### Token Management
- JWT tokens for API authentication
- Refresh token rotation
- Provider token validation

## Security

### Best Practices
- No plain text credential storage
- HTTPS only communication
- Token expiration handling
- Provider-specific security requirements

### Credential Code Integration
- Encrypted AWS credentials built into app
- Fallback for S3 operations
- User credentials take precedence

## Migration and Compatibility

### Existing User Migration
- Automatic migration from provider ID to UUID
- Backward compatibility for old accounts
- Zero user action required

### Cross-Platform Sync
- Account state synchronized across devices
- Provider availability per platform
- Consistent user experience

## Related Documentation

- [Apple Sign In Implementation](./apple-signin.md)
- [Google Sign In Implementation](./google-signin.md)
- [Account Linking](./account-linking.md)
- [Troubleshooting Guide](../../development/troubleshooting/auth-issues.md)
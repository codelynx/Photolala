# Email-Based Account Discovery

Last Updated: July 3, 2025

## Overview

Photolala implements email-based account discovery to support account linking and prevent duplicate accounts. This system allows users to find their existing account when signing in with a different provider that uses the same email address.

## Implementation

### Email Hashing

For privacy and security, email addresses are hashed before being stored in S3:

```swift
func hashEmail(_ email: String) -> String {
    let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let data = Data(normalizedEmail.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}
```

### S3 Storage Structure

Email mappings are stored in S3 at:
```
/emails/{hashedEmail} → serviceUserID
```

Example:
```
/emails/5d41402abc4b2a76b9719d911017c592 → 123e4567-e89b-12d3-a456-426614174000
```

### Account Discovery Flow

1. **User signs in with new provider**
2. **System normalizes email**: Lowercase, trim whitespace
3. **Hash the email**: SHA256 for privacy
4. **Check S3 mapping**: Look for `/emails/{hashedEmail}`
5. **If found**: Offer to link accounts
6. **If not found**: Proceed with new account creation

### Email Mapping Updates

Email mappings are created/updated when:
- User creates a new account with email
- User links a provider that has email
- User updates their email address

```swift
func updateEmailMapping(email: String, serviceUserID: String) async throws {
    let hashedEmail = hashEmail(email)
    let emailPath = "emails/\(hashedEmail)"
    let data = serviceUserID.data(using: .utf8)!
    
    try await s3Service.uploadData(data, to: emailPath)
}
```

## Security Considerations

### Privacy
- Email addresses are never stored in plain text in S3
- SHA256 hashing is one-way (cannot reverse to get email)
- Hash includes full email (including domain)

### Normalization
- Emails are lowercased before hashing
- Whitespace is trimmed
- Ensures consistent hashing across platforms

### Collision Handling
- SHA256 collisions are astronomically unlikely
- If collision occurs, first account wins
- User must use different email or contact support

## Platform Implementation

### iOS/macOS
- Implemented in `IdentityManager+Linking.swift`
- Uses CryptoKit for SHA256 hashing
- Integrated with account linking flow

### Android
- Uses same SHA256 algorithm for consistency
- Email normalization matches iOS exactly
- Cross-platform account discovery works

## Testing

### Test Cases
1. **Same email, different providers**: Should find existing account
2. **Different email cases**: "User@Example.com" = "user@example.com"
3. **Whitespace handling**: " user@example.com " = "user@example.com"
4. **Cross-platform**: iOS creates, Android finds (and vice versa)

### Verification Steps
1. Create account with email on Platform A
2. Check S3 for hashed email mapping
3. Sign in with same email on Platform B
4. Verify account discovery prompt appears

## Future Enhancements

### Email Verification
- Only create mappings for verified emails
- Add verification status to mapping
- Prevent unverified email hijacking

### Multiple Emails
- Support multiple emails per account
- Primary vs secondary emails
- Email change history

### Cleanup
- Remove mappings when email changes
- Garbage collection for orphaned mappings
- Audit trail for security

## Related Documentation

- [Account Linking Design](../planning/account-linking-design.md)
- [Authentication Strategy](../planning/authentication-strategy.md)
- [Cross-Platform Authentication Status](./cross-platform-authentication-status.md)
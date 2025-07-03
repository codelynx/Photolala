# Google Sign-In Troubleshooting Guide

Last Updated: July 3, 2025

## Common Issues and Solutions

### 1. Provider ID Mismatch Between Platforms

**Symptom**: User signs in on iOS and Android but gets different accounts

**Cause**: Platform using email instead of Google user ID

**Solution**:
1. Verify both platforms use `account.id` (not `account.email`)
2. Check S3 identity mappings format
3. Clean up incorrect mappings

**Correct Format**:
```
/identities/google:115288286590115386621
```

**Incorrect Format**:
```
/identities/google:user@example.com
```

### 2. Google Sign-In Error 10 (Android)

**Symptom**: Sign-in fails with error code 10

**Cause**: Missing or misconfigured OAuth clients

**Solution**:
1. Ensure BOTH Android and Web OAuth clients exist
2. Verify they're in the same Google Cloud project
3. Use Web client ID in code (not Android client ID)
4. Check SHA-1 fingerprint matches

### 3. Error 28444 (Android Credential Manager)

**Symptom**: Credential Manager returns Error 28444

**Cause**: Unknown issue with Credential Manager API

**Solution**:
1. Use Legacy Google Sign-In API instead
2. Implement with Activity Result pattern
3. See `GoogleSignInLegacyService.kt` for implementation

### 4. Cross-Device Sign-In Not Working

**Symptom**: Same Google account creates different users on each platform

**Diagnosis Steps**:
1. Check S3 `/identities/` folder
2. Look for duplicate entries with same user
3. Verify provider ID format consistency

**Fix**:
1. Ensure both platforms use numeric Google user ID
2. Clean up incorrect S3 mappings
3. Test with fresh Google account

### 5. OAuth Configuration Issues

**iOS/macOS Checklist**:
- [ ] URL scheme in Info.plist matches client ID
- [ ] GoogleSignIn SDK properly linked
- [ ] Client ID is iOS type (not Web)
- [ ] Bundle ID matches OAuth client

**Android Checklist**:
- [ ] google-services.json present and correct
- [ ] Web OAuth client ID used in code
- [ ] Android OAuth client has correct SHA-1
- [ ] Package name matches exactly

### 6. Simulator/Emulator Issues

**iOS Simulator**:
- Passkeys don't work properly
- May need manual credential entry
- Test on physical device if possible

**Android Emulator**:
- Should work with Google Play Services
- Ensure emulator has Google APIs
- Sign in to Google account on emulator first

## Debugging Tools

### 1. Check Provider ID (iOS)
```swift
print("Google User ID: \(user.userID)")
print("Email: \(user.profile?.email ?? "none")")
```

### 2. Check Provider ID (Android)
```kotlin
Log.d("GoogleSignIn", "Google User ID: ${account.id}")
Log.d("GoogleSignIn", "Email: ${account.email}")
```

### 3. Verify S3 Mappings
```bash
# List all identity mappings
aws s3 ls s3://photolala/identities/

# Check specific user
aws s3 cp s3://photolala/identities/google:USER_ID -
```

### 4. Clean Up Bad Mappings
```bash
# Remove incorrect email-based mapping
aws s3 rm s3://photolala/identities/google:user@example.com

# Keep correct ID-based mapping
# s3://photolala/identities/google:115288286590115386621
```

## Platform-Specific Issues

### iOS/macOS
1. **Framework not found**: Manually link GoogleSignIn frameworks
2. **URL scheme error**: Verify Info.plist configuration
3. **Async/await issues**: Use SDK v8.0.0 or later

### Android
1. **Package already in use**: Find which project owns it
2. **SHA-1 mismatch**: Get correct fingerprint from keystore
3. **No OAuth consent screen**: Add test users

## Testing Checklist

### New Implementation
1. [ ] Create fresh Google account for testing
2. [ ] Sign in on Platform A
3. [ ] Check S3 for identity mapping
4. [ ] Note the provider ID format
5. [ ] Sign in on Platform B
6. [ ] Verify same serviceUserID retrieved
7. [ ] Check user data consistency

### Existing User Migration
1. [ ] Document existing S3 mappings
2. [ ] Identify incorrect formats
3. [ ] Create migration plan
4. [ ] Test with backup data first
5. [ ] Clean up bad mappings
6. [ ] Verify cross-platform access

## Error Code Reference

| Code | Platform | Meaning | Solution |
|------|----------|---------|----------|
| 10 | Android | Developer error | Check OAuth configuration |
| 12500 | Android | Sign-in failed | Verify google-services.json |
| 12501 | Android | User cancelled | Handle gracefully |
| 28444 | Android | Credential Manager error | Use Legacy API |
| -4 | iOS | Key mismatch | Check URL scheme |

## Contact for Help

If issues persist:
1. Check all configuration items in this guide
2. Review platform-specific documentation
3. Test with a fresh Google account
4. Compare working vs non-working setups

## Related Documentation

- [Android Implementation Summary](../../android/docs/GOOGLE_SIGNIN_IMPLEMENTATION_SUMMARY.md)
- [iOS Setup Guide](../../apple/docs/GOOGLE_SIGNIN_IOS_SETUP.md)
- [Provider ID Fix](./google-signin-providerid-fix.md)
- [Cross-Platform Authentication Status](../current/cross-platform-authentication-status.md)
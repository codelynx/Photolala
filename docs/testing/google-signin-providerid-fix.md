# Google Sign-In Provider ID Fix

## Issue
Android was using email address instead of Google user ID for the provider ID, causing incorrect S3 identity mappings.

## What Was Wrong
```kotlin
// Before:
providerID = account.email ?: account.id ?: "",  // Wrong - uses email first

// After:
providerID = account.id ?: "",  // Correct - uses Google user ID
```

## Files Fixed
1. `android/app/src/main/java/com/electricwoods/photolala/services/GoogleSignInLegacyService.kt`
   - Fixed line 61 to use `account.id` instead of email
   - Added debug log to show Google User ID

2. `android/app/src/main/java/com/electricwoods/photolala/services/GoogleAuthService.kt`
   - Fixed line 117 to set email to null (needs investigation if email is available)

## S3 Identity Format

### Correct Format
```
/identities/google:115288286590115386621  → UUID
```

### Incorrect Format (Bug)
```
/identities/google:kaz.yoshikawa@gmail.com  → UUID
```

## Testing

1. **Clean up incorrect S3 entries**:
   - Delete `/identities/google:kaz.yoshikawa@gmail.com`
   - Keep `/identities/google:115288286590115386621`

2. **Test Android sign-in**:
   - Sign out from Android app
   - Sign in again with Google
   - Check logs for "Google User ID: ..." message
   - Verify new S3 identity uses numeric ID

3. **Cross-platform test**:
   - Sign in on Android with fixed code
   - Sign in on iOS with same Google account
   - Should resolve to same user account

## Expected Result
Both platforms should create/use the same identity mapping:
- iOS: `/identities/google:115288286590115386621`
- Android: `/identities/google:115288286590115386621`
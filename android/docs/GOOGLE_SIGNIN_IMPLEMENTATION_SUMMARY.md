# Google Sign-In Implementation Summary

Last Updated: July 3, 2025 (Added provider ID fix)

## Quick Reference for Future Implementations

### What Worked
✅ Legacy Google Sign-In API (`com.google.android.gms.auth.api.signin`)
✅ Single Google Cloud project for all OAuth clients
✅ Activity result pattern for sign-in flow

### What Didn't Work
❌ Credential Manager API (Error 28444)
❌ Multiple Google Cloud projects
❌ Web OAuth client alone (needs Android client too)

## Required OAuth Clients

You need **BOTH** in the same Google Cloud project:

1. **Android OAuth Client**
   - Type: Android
   - Package name: Must match app exactly
   - SHA-1: Must match signing certificate
   - Purpose: Authenticates the app

2. **Web OAuth Client**  
   - Type: Web application
   - No redirect URIs needed
   - Purpose: Gets ID token for user
   - This ID goes in your code

## Common Pitfalls

### 1. Wrong Project
- OAuth clients in different project than Firebase/google-services.json
- Solution: Use same project for everything

### 2. Missing Android Client
- Only creating Web client (Error code 10)
- Solution: Create both Android and Web clients

### 3. SHA-1 Mismatch
- Wrong fingerprint in Android OAuth client
- Debug vs Release certificates differ
- Get correct SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`

### 4. Package Name Issues
- OAuth client package doesn't match app
- Android client already exists with package (can't create duplicate)

### 5. Provider ID Issues (Fixed July 3, 2025)
- Was using email instead of Google user ID
- Fixed in GoogleSignInLegacyService.kt
- Now correctly uses `account.id` for provider ID
- Solution: Find existing client or use different package

## Implementation Checklist

- [ ] Create Google Cloud project
- [ ] Create Android OAuth client with correct package and SHA-1
- [ ] Create Web OAuth client 
- [ ] Add Web client ID to code (not Android client ID)
- [ ] Generate google-services.json
- [ ] Add test users to OAuth consent screen
- [ ] Use legacy GoogleSignIn API if Credential Manager fails
- [ ] Implement activity result handling for sign-in

## Code Structure

```
MainActivity
  └── registerForActivityResult (Google Sign-In launcher)
       └── PhotolalaNavigation
            └── AuthenticationScreen
                 └── AuthenticationViewModel
                      └── IdentityManager
                           └── GoogleSignInLegacyService
```

## Error Codes Quick Fix

| Error | Fix |
|-------|-----|
| 28444 | Try legacy API, check all config |
| 10 | Create Android OAuth client |
| 12500 | Check google-services.json |
| Package already in use | Find which project has it |

## Testing

1. Always test with real Google account on emulator
2. Add test email to OAuth consent screen
3. Check Logcat for detailed errors
4. Verify both OAuth clients exist in same project
5. **IMPORTANT**: Verify provider ID uses `account.id` not `account.email`
   - Check logs for "Google User ID: 115288286590115386621"
   - S3 identity should be `/identities/google:115288286590115386621`
   - NOT `/identities/google:user@example.com`

### Issue
Android was incorrectly using email as provider ID instead of Google user ID

### Fix
```kotlin
// Correct:
providerID = account.id ?: ""

// Wrong:
providerID = account.email ?: account.id ?: ""
```

### Verification
Check S3 identity format:
- ✅ Correct: `/identities/google:115288286590115386621`
- ❌ Wrong: `/identities/google:user@example.com`
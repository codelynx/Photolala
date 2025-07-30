# Google Sign-In Keychain Error

## Issue
When linking a Google account in the Account Settings, an alert appears with "keychain error" message.

## Analysis
The error appears to be coming from the Google Sign-In SDK itself, not from Photolala's code. Google Sign-In SDK uses Keychain internally to store authentication tokens.

## Possible Causes
1. **Sandboxing**: The app is sandboxed which may restrict Google Sign-In SDK's keychain access
2. **Missing Keychain Entitlements**: Google Sign-In might need specific keychain access
3. **Code Signing**: The `/private/var/db/DetachedSignatures` error suggests code signing verification issues

## Debugging Steps Added
1. Added comprehensive logging to `GoogleAuthProvider.swift`:
   - Log when sign-in starts
   - Log configuration steps
   - Log success/failure with details
   - Log error mapping

2. Made Keychain failures non-fatal in `IdentityManager`:
   - Continue with S3 persistence if Keychain fails
   - Log but don't throw on Keychain errors

## Workaround
The app now continues to function even if Keychain access fails:
- User data is still saved to S3
- Authentication state is maintained
- Account linking completes successfully

## Potential Solutions
1. **Add Keychain Sharing Entitlement**: May need to add keychain-access-groups
2. **Disable Google's Keychain**: Look for SDK option to disable keychain storage
3. **Use Alternative Storage**: Store Google tokens in our own secure storage

## Notes
- The error doesn't prevent account linking from working
- User data persists via S3 even if local Keychain fails
- This appears to be a Google Sign-In SDK issue, not Photolala code
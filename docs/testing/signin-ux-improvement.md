# Sign-In UX Improvement - Credential Reuse

## Problem
Previously, when a user attempted to sign in but no account was found:
1. User signs in with Apple/Google
2. Authentication succeeds but "No account found" error is shown
3. User clicks "Create Account" in the dialog
4. User has to authenticate with Apple/Google AGAIN

This created a poor user experience with redundant authentication.

## Solution
We've implemented credential reuse to eliminate the double authentication:

### iOS/macOS (Apple Platforms)
- Modified `AuthError.noAccountFound` to include the `AuthCredential`
- Added `createAccount(with credential: AuthCredential)` method to IdentityManager
- Updated `AuthenticationChoiceView` to store and reuse the credential
- When user clicks "Create Account", the stored credential is used directly

### Android
- Modified `AuthException.NoAccountFound` to include the `AuthCredential`
- Added `createAccount(credential: AuthCredential)` method to IdentityManager
- Added `createAccountWithCredential` method to AuthenticationViewModel
- Updated `AuthenticationScreen` to store and reuse the credential when available

## Testing Instructions

### iOS/macOS Testing
1. Sign out if already signed in
2. Click "Sign In"
3. Choose Apple Sign In
4. Complete authentication with an Apple ID that has NO existing Photolala account
5. You should see "No Account Found" dialog
6. Click "Create Account"
7. **Expected**: Account is created immediately without re-authentication
8. **Previous behavior**: Would show Apple Sign In again

### Android Testing
1. Sign out if already signed in
2. Click "Sign In"
3. Choose Google/Apple Sign In
4. Complete authentication with an account that has NO existing Photolala account
5. You should see "No Account Found" dialog
6. Click "Create Account"
7. **Expected**: Account is created immediately without re-authentication
8. **Previous behavior**: Would launch Google/Apple Sign In again

## Implementation Details

### Key Changes:
1. `AuthError`/`AuthException` now optionally includes the credential
2. New methods to create accounts with existing credentials
3. UI components store the credential from failed sign-in attempts
4. Credential is reused when user chooses to create account

### Security Considerations:
- Credentials are only stored temporarily in memory
- Credentials are cleared after use or when dialog is cancelled
- No credentials are persisted to disk during this flow
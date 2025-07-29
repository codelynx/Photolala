# Sign-In/Sign-Up Testing Checklist

## Pre-Test Setup
- [ ] Wipe S3 bucket (remove all user data)
- [ ] Clear app data on all test devices
- [ ] Have test email accounts ready

## macOS Testing

### Sign Up Flow
- [ ] Launch app fresh (no existing user)
- [ ] Navigate to Sign Up
- [ ] Test email/password sign up
- [ ] Test Google Sign-In for new account
- [ ] Test Apple Sign-In for new account
- [ ] Verify S3 identity persistence after sign up
- [ ] Verify user can access Cloud Browser after sign up

### Sign In Flow
- [ ] Sign out from app
- [ ] Test email/password sign in
- [ ] Test Google Sign-In for existing account
- [ ] Test Apple Sign-In for existing account
- [ ] Verify S3 identity loaded correctly
- [ ] Verify Cloud Browser shows correct user data

### Edge Cases
- [ ] Test sign in with wrong password
- [ ] Test sign in with non-existent email
- [ ] Test network error handling
- [ ] Test switching between accounts

## iOS Testing

### Sign Up Flow
- [ ] Launch app fresh (no existing user)
- [ ] Navigate to Sign Up
- [ ] Test email/password sign up
- [ ] Test Google Sign-In for new account
- [ ] Test Apple Sign-In for new account
- [ ] Verify S3 identity persistence after sign up
- [ ] Verify user can access Cloud Browser after sign up

### Sign In Flow
- [ ] Sign out from app
- [ ] Test email/password sign in
- [ ] Test Google Sign-In for existing account
- [ ] Test Apple Sign-In for existing account
- [ ] Verify S3 identity loaded correctly
- [ ] Verify Cloud Browser shows correct user data

### Edge Cases
- [ ] Test sign in with wrong password
- [ ] Test sign in with non-existent email
- [ ] Test network error handling
- [ ] Test switching between accounts
- [ ] Test biometric authentication (if implemented)

## Android Testing

### Sign Up Flow
- [ ] Launch app fresh (no existing user)
- [ ] Navigate to Create Account
- [ ] Test email/password sign up
- [ ] Test Google Sign-In for new account
- [ ] Test Apple Sign-In for new account (web flow)
- [ ] Verify S3 identity persistence after sign up
- [ ] Verify Cloud Browser button enabled after sign up
- [ ] Test Cloud Browser access

### Sign In Flow
- [ ] Sign out from app
- [ ] Test email/password sign in
- [ ] Test Google Sign-In for existing account
- [ ] Test Apple Sign-In for existing account
- [ ] Verify S3 identity loaded correctly
- [ ] Verify Cloud Browser shows correct user data

### Edge Cases
- [ ] Test sign in with wrong password
- [ ] Test sign in with non-existent email
- [ ] Test network error handling
- [ ] Test switching between accounts
- [ ] Test deep link handling for Apple Sign-In callback

## Cross-Platform Testing

### Account Consistency
- [ ] Create account on Platform A, sign in on Platform B
- [ ] Verify same user ID across platforms
- [ ] Verify S3 data accessible from all platforms
- [ ] Test concurrent sign-ins on multiple devices

### Provider Linking
- [ ] Sign up with email on one platform
- [ ] Link Google account on another platform
- [ ] Link Apple account on third platform
- [ ] Verify all providers work on all platforms

## Known Issues to Watch For

### macOS/iOS
- [ ] Apple Sign-In credential state
- [ ] Keychain persistence
- [ ] AWS credential handling

### Android
- [ ] Apple Sign-In browser flow completion
- [ ] Navigation state preservation
- [ ] Google Sign-In activity result handling

## S3 Verification

### After Sign Up
- [ ] Check S3 for user identity folder: `identities/{userId}/user.json`
- [ ] Verify user.json contains correct provider information
- [ ] Check for any orphaned data

### After Sign In
- [ ] Verify identity loaded from S3
- [ ] Check credential persistence
- [ ] Verify photo access permissions

## Notes Section
(Add any issues discovered during testing here)

---

## Test Results

### macOS
- Date tested: 
- Version: 
- Issues found: 

### iOS
- Date tested: 
- Version: 
- Issues found: 

### Android
- Date tested: 
- Version: 
- Issues found: 
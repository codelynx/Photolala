# Authentication Testing Plan

## Overview
Comprehensive testing plan for the multi-provider authentication system across iOS, macOS, and Android platforms.

## Test Categories

### 1. Unit Tests

#### IdentityManager Tests
- [ ] Test user creation with valid credentials
- [ ] Test duplicate user prevention
- [ ] Test email-based account discovery
- [ ] Test provider linking logic
- [ ] Test S3 identity mapping creation
- [ ] Test secure storage encryption/decryption

#### AuthProvider Tests
- [ ] Test Apple Sign-In credential extraction
- [ ] Test Google Sign-In credential extraction
- [ ] Test provider cancellation handling
- [ ] Test invalid credential handling

#### Account Linking Tests
- [ ] Test email hashing consistency
- [ ] Test provider conflict detection
- [ ] Test unlink validation (can't unlink last)
- [ ] Test force account creation

### 2. Integration Tests

#### Authentication Flow Tests
- [ ] Sign up with Apple → Success
- [ ] Sign up with Google → Success
- [ ] Sign in with wrong provider → Correct error
- [ ] Sign up with existing email → Linking prompt
- [ ] Link providers → Both work for sign-in

#### Cross-Platform Tests
- [ ] Create account on iOS → Sign in on Android
- [ ] Create account on Android → Sign in on macOS
- [ ] Link providers on one platform → Works on all

#### S3 Integration Tests
- [ ] User folder creation on signup
- [ ] Identity mapping persistence
- [ ] Email mapping creation and lookup
- [ ] Photo backup with user context

### 3. UI Tests

#### Sign-In Flow
- [ ] Welcome screen → Sign In → Provider selection
- [ ] Provider authentication → Success navigation
- [ ] Error display and recovery
- [ ] Loading states during authentication

#### Sign-Up Flow
- [ ] Welcome screen → Create Account → Provider selection
- [ ] New account creation → Success
- [ ] Existing email → Linking prompt display
- [ ] Link vs Create Separate decision

#### Account Management
- [ ] View linked providers
- [ ] Add new provider link
- [ ] Unlink provider (not last one)
- [ ] Sign out functionality

### 4. Edge Case Tests

#### Network Issues
- [ ] No internet during sign-in
- [ ] Network timeout during S3 operations
- [ ] Partial completion recovery

#### Provider Issues
- [ ] User cancels authentication
- [ ] Invalid OAuth configuration
- [ ] Expired tokens
- [ ] Provider service down

#### Data Conflicts
- [ ] Same email, different providers
- [ ] Provider ID already linked elsewhere
- [ ] Corrupted local storage
- [ ] Missing S3 mappings

### 5. Performance Tests

#### Speed Metrics
- [ ] Time to authenticate: < 2 seconds
- [ ] Time to check email conflicts: < 500ms
- [ ] UI responsiveness during auth
- [ ] Background S3 operations don't block UI

#### Resource Usage
- [ ] Memory usage during auth
- [ ] Network bandwidth efficiency
- [ ] Battery impact of background operations

## Test Scenarios

### Scenario 1: New User Journey
1. Launch app fresh install
2. Tap "Create Account"
3. Choose Google Sign-In
4. Complete Google auth
5. Verify account created
6. Check S3 folders created
7. Sign out
8. Sign back in with Google
9. Verify same account loaded

### Scenario 2: Existing User Adds Provider
1. Sign in with Apple
2. Go to Account Settings
3. Link Google account
4. Sign out
5. Sign in with Google
6. Verify same account/data

### Scenario 3: Email Conflict Resolution
1. Create account with Apple (test@example.com)
2. Try to create account with Google (same email)
3. See linking prompt
4. Choose "Link to Existing"
5. Verify providers linked
6. Test both sign-in methods

### Scenario 4: Migration from Old Version
1. Install old version with Apple-only auth
2. Sign in and backup photos
3. Update to new version
4. Verify account still works
5. Verify can add Google as linked provider

### Scenario 5: Account Recovery
1. Sign in with provider A
2. Link provider B
3. Delete app
4. Reinstall
5. Sign in with provider B
6. Verify full account restored

## Platform-Specific Tests

### iOS
- [ ] Face ID integration with stored credentials
- [ ] iOS 16+ compatibility
- [ ] iPad layout differences
- [ ] iOS simulator limitations

### macOS
- [ ] Keychain integration
- [ ] macOS 14+ compatibility
- [ ] Window management during auth
- [ ] Safari vs in-app authentication

### Android
- [ ] Google Play Services availability
- [ ] Android 13+ compatibility
- [ ] Biometric authentication
- [ ] Chrome Custom Tabs behavior

## Test Data

### Test Accounts
```
Apple Test: apple.test@photolala.com
Google Test: google.test@photolala.com
Linked Test: linked.test@photolala.com (both providers)
```

### Test Scenarios Database
- Fresh account creation
- Existing account with photos
- Account with subscription
- Account with linked providers
- Corrupted account data

## Automation Strategy

### Unit Test Automation
- XCTest for iOS/macOS
- JUnit for Android
- Mock S3 responses
- Mock provider authentication

### UI Test Automation
- XCUITest for iOS/macOS
- Espresso for Android
- Screenshot testing
- Accessibility testing

### CI/CD Integration
- Run tests on PR
- Nightly full test suite
- Platform matrix testing
- Performance regression tests

## Success Criteria

### Functional
- 100% of auth flows work correctly
- No data loss during provider linking
- Graceful error handling
- Cross-platform compatibility

### Performance
- Authentication < 2 seconds
- No UI freezing
- Smooth animations
- Minimal battery impact

### User Experience
- Clear error messages
- Intuitive flow
- Consistent across platforms
- Accessible to all users

## Bug Tracking

### Priority Levels
- P0: Blocks authentication completely
- P1: Major functionality broken
- P2: Minor issues, workarounds exist
- P3: Polish and improvements

### Bug Report Template
```
Platform: [iOS/macOS/Android]
Version: [App version]
Provider: [Apple/Google/Both]
Steps to Reproduce:
Expected Result:
Actual Result:
Screenshots/Logs:
```

## Timeline

### Week 1
- Day 1-2: Unit test implementation
- Day 3: Integration test setup
- Day 4-5: UI test automation

### Week 2  
- Day 1-2: Edge case testing
- Day 3: Performance testing
- Day 4: Bug fixes
- Day 5: Final verification

## Sign-off Checklist

- [ ] All automated tests passing
- [ ] Manual test scenarios verified
- [ ] Performance metrics met
- [ ] No P0/P1 bugs
- [ ] Documentation updated
- [ ] Team sign-off received
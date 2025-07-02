# Authentication Implementation Plan

## Overview

This document outlines the phased implementation plan for adding explicit signup/signin flow with multi-provider support to Photolala.

## Phase 1: Refactor Apple Authentication (1-2 days)

### Goal
Update existing Sign in with Apple to use explicit signup/signin flow.

### Tasks
1. **Update Welcome Screen UI**
   - [ ] Create new `AuthenticationChoiceView` with "Sign In" and "Create Account" buttons
   - [ ] Replace existing `SignInPromptView` usage
   - [ ] Add provider selection screen

2. **Refactor IdentityManager**
   - [ ] Split `signIn()` into `signIn(provider:)` and `createAccount(provider:)`
   - [ ] Add error handling for "no account found" scenario
   - [ ] Update user lookup logic to check provider ID

3. **Update User Model**
   - [ ] Migrate from `appleUserID` to `primaryProviderID`
   - [ ] Add `primaryProvider` field
   - [ ] Add `linkedProviders` array (empty for now)
   - [ ] Create migration logic for existing users

4. **Error Handling**
   - [ ] Create specific error types for auth scenarios
   - [ ] Add user-friendly error messages
   - [ ] Implement "try another provider" suggestions

### Files to Modify
- `apple/Photolala/Views/SignInPromptView.swift`
- `apple/Photolala/Services/IdentityManager.swift`
- `apple/Photolala/Models/PhotolalaUser.swift`
- `apple/Photolala/Views/ContentView.swift`

## Phase 2: Add Google Sign-In for iOS/macOS (2-3 days)

### Goal
Add Sign in with Google as secondary option on Apple platforms.

### Tasks
1. **Setup Google Sign-In SDK**
   - [ ] Add Google Sign-In package via SPM
   - [ ] Configure OAuth client ID
   - [ ] Update Info.plist with URL schemes
   - [ ] Add required entitlements

2. **Implement Google Provider**
   - [ ] Create `GoogleAuthProvider` conforming to `AuthProviderProtocol`
   - [ ] Handle Google authentication flow
   - [ ] Extract user info from Google credentials

3. **Update UI**
   - [ ] Add Google sign-in button to authentication screens
   - [ ] Follow platform design guidelines
   - [ ] Test on iOS and macOS

4. **Integration Testing**
   - [ ] Test new user signup with Google
   - [ ] Test existing user signin with Google
   - [ ] Verify error handling

### Files to Create/Modify
- `apple/Photolala/Services/GoogleAuthProvider.swift`
- `apple/Photolala/Views/AuthenticationChoiceView.swift`
- `apple/Photolala.xcodeproj/project.pbxproj`
- `apple/Photolala/Info.plist`

## Phase 3: Implement Android Authentication (3-4 days)

### Goal
Add authentication to Android app with Google Sign-In as primary provider.

### Tasks
1. **Setup Android Project**
   - [ ] Add Google Sign-In dependencies to build.gradle
   - [ ] Configure OAuth client ID for Android
   - [ ] Update AndroidManifest.xml

2. **Create Authentication Architecture**
   - [ ] Create `AuthenticationViewModel`
   - [ ] Implement `UserRepository` with Room/DataStore
   - [ ] Create `GoogleAuthProvider` for Android
   - [ ] Implement secure credential storage

3. **Build UI Components**
   - [ ] Create `WelcomeScreen` with auth options
   - [ ] Create `AuthenticationScreen` for signin/signup
   - [ ] Implement error dialogs
   - [ ] Add loading states

4. **S3 Integration**
   - [ ] Create user folders on signup
   - [ ] Implement photo backup with user context
   - [ ] Handle authentication in S3Manager

### Files to Create
- `android/app/src/main/java/com/electricwoods/photolala/auth/`
  - `AuthenticationViewModel.kt`
  - `GoogleAuthProvider.kt`
  - `UserRepository.kt`
- `android/app/src/main/java/com/electricwoods/photolala/ui/auth/`
  - `WelcomeScreen.kt`
  - `AuthenticationScreen.kt`
- `android/app/src/main/java/com/electricwoods/photolala/data/`
  - `PhotolalaUser.kt`
  - `UserDao.kt`

## Phase 4: Account Linking (2-3 days)

### Goal
Allow users to link multiple providers to same account.

### Tasks
1. **Backend Logic**
   - [ ] Implement provider linking in IdentityManager
   - [ ] Add email-based account discovery
   - [ ] Handle provider conflicts

2. **UI Implementation**
   - [ ] Add "Link Account" option in settings
   - [ ] Create linking flow UI
   - [ ] Show linked providers list

3. **Security**
   - [ ] Verify email matches for auto-linking
   - [ ] Implement manual confirmation flow
   - [ ] Add unlink functionality

### Files to Modify
- `apple/Photolala/Services/IdentityManager.swift`
- `apple/Photolala/Views/UserAccountView.swift`
- Android equivalent files

## Phase 5: Testing & Polish (2-3 days)

### Goal
Ensure robust authentication experience across platforms.

### Tasks
1. **Comprehensive Testing**
   - [ ] Unit tests for auth flows
   - [ ] UI tests for signin/signup
   - [ ] Cross-platform testing
   - [ ] Edge case testing

2. **Migration Testing**
   - [ ] Test existing Apple users
   - [ ] Verify S3 data preservation
   - [ ] Test account recovery

3. **Polish**
   - [ ] Improve error messages
   - [ ] Add helpful animations
   - [ ] Optimize performance
   - [ ] Update documentation

## Implementation Order

### Week 1
- Monday-Tuesday: Phase 1 (Refactor Apple Auth)
- Wednesday-Friday: Phase 2 (Add Google to iOS/macOS)

### Week 2
- Monday-Thursday: Phase 3 (Android Authentication)
- Friday: Start Phase 4 (Account Linking)

### Week 3
- Monday-Tuesday: Complete Phase 4
- Wednesday-Friday: Phase 5 (Testing & Polish)

## Success Criteria

1. **Functionality**
   - Users can create accounts with Apple or Google
   - Users can sign in with correct provider
   - Clear error when using wrong provider
   - Account linking works smoothly

2. **User Experience**
   - < 3 taps to create account
   - Clear visual distinction between signin/signup
   - Helpful error messages
   - Smooth animations

3. **Security**
   - Credentials stored securely
   - Provider IDs properly validated
   - No accidental account creation
   - Secure S3 folder isolation

4. **Performance**
   - Authentication < 2 seconds
   - No UI freezing
   - Smooth transitions
   - Minimal battery impact

## Risk Mitigation

1. **Migration Issues**
   - Keep backward compatibility
   - Test thoroughly with copies
   - Have rollback plan

2. **Provider API Changes**
   - Follow latest SDK docs
   - Implement version checks
   - Have fallback options

3. **Cross-Platform Consistency**
   - Share business logic where possible
   - Document platform differences
   - Regular cross-platform testing

## Next Steps

1. Create feature branch: `feature/explicit-auth-flow`
2. Start with Phase 1 implementation
3. Daily progress updates
4. Code review after each phase
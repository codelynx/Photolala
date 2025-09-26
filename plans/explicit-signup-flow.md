# Explicit Signup Flow Implementation Plan

## Executive Summary

Transform the current automatic account creation into an explicit, consent-based signup flow that clearly distinguishes between signing in to an existing account and creating a new Photolala account.

## Problem Statement

### Current Issues
1. **Automatic Account Creation**: New users get accounts created automatically without explicit consent
2. **No Terms Acceptance**: Users never see or accept Terms of Service or Privacy Policy
3. **Poor New User Experience**: New users land directly on home screen with no onboarding
4. **Ambiguous Intent**: No clear distinction between "Sign In" and "Sign Up"

### Requirements
- Explicit user consent before account creation
- Terms of Service and Privacy Policy acceptance
- Clear communication about account status
- Proper onboarding for new users
- Ability to cancel at any step

## User Journey

### New User Flow
```
1. User taps "Sign in with Google/Apple"
   ↓
2. OAuth authentication succeeds
   ↓
3. System checks if Photolala account exists
   ↓
4. "No Account Found" screen
   - Message: "You don't have a Photolala account yet"
   - Options: [Create Account] [Cancel]
   ↓
5. Terms Acceptance screen (if Create Account)
   - Shows Terms of Service & Privacy Policy
   - Checkbox: "I accept the terms"
   - Options: [Accept] [No Thanks]
   ↓
6. Account creation (if Accept)
   - Lambda creates account
   - Returns user data and credentials
   ↓
7. Welcome screen
   - "Welcome to Photolala!"
   - Brief feature introduction
   - [Get Started]
   ↓
8. Home screen (signed in)
```

### Existing User Flow
```
1. User taps "Sign in with Google/Apple"
   ↓
2. OAuth authentication succeeds
   ↓
3. System checks if Photolala account exists
   ↓
4. Account found - sign in
   ↓
5. Home screen with "Welcome back" message
```

## Technical Architecture

### State Management

```swift
enum SignupState {
    case checking           // Checking if account exists
    case noAccount         // Account doesn't exist
    case termsReview       // Reviewing terms
    case creating          // Creating account
    case welcome           // Showing welcome screen
    case completed         // Signup complete
    case cancelled         // User cancelled
}
```

### Data Flow

#### 1. Account Check Phase
```
App → OAuth Provider → Success → Tokens
App → Lambda (check_only=true) → Account Status
```

#### 2. Account Creation Phase (if needed)
```
App → Show NoAccountView → User Confirms
App → Show TermsView → User Accepts
App → Lambda (create_account=true) → New Account
App → Show WelcomeView → Complete
```

### Lambda API Changes

#### Current Behavior
```json
// Request
{
  "id_token": "...",
  "provider": "google"
}

// Response (auto-creates if new)
{
  "user": {...},
  "credentials": {...},
  "isNewUser": true
}
```

#### New Behavior

**Check Account Exists**
```json
// Request
{
  "id_token": "...",
  "provider": "google",
  "check_only": true
}

// Response
{
  "account_exists": false,
  "provider_id": "google:12345"
}
```

**Create Account Explicitly**
```json
// Request
{
  "id_token": "...",
  "provider": "google",
  "create_account": true,
  "terms_accepted": true,
  "terms_version": "1.0"
}

// Response
{
  "user": {...},
  "credentials": {...},
  "isNewUser": true
}
```

## UI/UX Specifications

### NoAccountView

**Layout:**
- Icon: Person with question mark
- Title: "No Photolala Account"
- Subtitle: "You signed in with [Provider] but don't have a Photolala account yet."
- Body: "Would you like to create a free account to sync and backup your photos?"
- Buttons: [Create Account] [Cancel]

**Behavior:**
- Create Account → Navigate to TermsAcceptanceView
- Cancel → Return to sign-in screen

### TermsAcceptanceView

**Layout:**
- Title: "Terms & Conditions"
- Scrollable content area with:
  - Terms of Service
  - Privacy Policy
- Checkbox: "□ I have read and accept the Terms of Service and Privacy Policy"
- Buttons: [Accept] [No Thanks]

**Behavior:**
- Accept button disabled until checkbox checked
- Accept → Create account and show WelcomeView
- No Thanks → Return to sign-in screen

### WelcomeView

**Layout:**
- Animation: Confetti or celebration effect
- Icon: Photolala logo with sparkles
- Title: "Welcome to Photolala!"
- Subtitle: "Your account has been created"
- Feature highlights:
  - "✓ Unlimited cloud storage"
  - "✓ Access from all your devices"
  - "✓ AI-powered organization"
- Button: [Get Started]

**Behavior:**
- Get Started → Navigate to home screen
- Show only once per account creation

## Implementation Details

### Phase 1: Backend Changes
1. Modify Lambda to support `check_only` parameter
2. Add `create_account` explicit action
3. Track terms acceptance version
4. Return clear account status

### Phase 2: iOS/macOS Client
1. Create new view components
2. Update AccountManager with new methods
3. Implement state machine for signup flow
4. Add OAuth token caching during signup

### Phase 3: Terms Content
1. Write Terms of Service
2. Write Privacy Policy
3. Implement versioning system
4. Add update notification for changed terms

## Error Handling

### Network Failures
- Retry with exponential backoff
- Show clear error messages
- Allow manual retry
- Preserve OAuth tokens for retry

### OAuth Failures
- Clear error messages by provider
- Suggest alternatives
- Link to help documentation

### Account Creation Failures
- Specific error for existing account
- Handle rate limiting
- Show support contact option

## Testing Scenarios

### Unit Tests
- State transitions in signup flow
- Token caching and retrieval
- Error handling paths
- Terms acceptance validation

### Integration Tests
- Complete signup flow
- Cancellation at each step
- Network failure recovery
- Multiple OAuth providers

### User Acceptance Tests
1. New user creates account successfully
2. Existing user signs in without signup flow
3. User cancels at NoAccount screen
4. User cancels at Terms screen
5. Network failure during account creation
6. Terms update notification for existing users

## Success Metrics

### User Experience
- Signup completion rate >80%
- Terms acceptance rate >95%
- Average time to complete signup <60 seconds
- Support tickets related to signup <1%

### Technical
- Account check latency <500ms
- Account creation success rate >99%
- OAuth token preservation 100%
- No duplicate accounts created

### Legal/Compliance
- 100% of new accounts have accepted terms
- Terms version tracked for all users
- Audit trail for consent
- GDPR/CCPA compliant consent flow

## Migration Strategy

### Existing Users
- No impact on current users
- Continue to sign in normally
- Optional: Show updated terms on next sign-in

### Rollout Plan
1. Deploy Lambda changes (backward compatible)
2. Release iOS/macOS update with feature flag
3. Enable for small percentage of new users
4. Monitor metrics and feedback
5. Gradual rollout to 100%

### Rollback Plan
- Feature flag to disable new flow
- Revert to automatic account creation
- Preserve any accounts created during rollout

## Future Enhancements

### Phase 2
- Social login options (Facebook, Microsoft)
- Email/password authentication option
- Profile customization during signup
- Referral program integration

### Phase 3
- Progressive onboarding
- Personalization questions
- Import from other services
- Family account setup

## Terms Content Structure

### Terms of Service
```markdown
# Photolala Terms of Service
Version 1.0 - Effective Date: [Date]

## 1. Acceptance of Terms
By creating an account, you agree to these terms...

## 2. Use of Service
- Permitted uses
- Restrictions
- Account responsibilities

## 3. Privacy and Data
- Data collection
- Data usage
- User rights

## 4. Content Ownership
- User content rights
- Photolala rights
- Licensing

## 5. Termination
- Account deletion
- Data retention
- Suspension policies
```

### Privacy Policy
```markdown
# Photolala Privacy Policy
Version 1.0 - Effective Date: [Date]

## 1. Information We Collect
- Account information
- Photos and metadata
- Usage data

## 2. How We Use Information
- Service provision
- Improvements
- Communications

## 3. Data Storage
- Encryption
- Location
- Retention

## 4. Your Rights
- Access
- Deletion
- Portability
```

## Conclusion

This explicit signup flow provides clear user consent, legal compliance, and improved onboarding experience while maintaining a smooth authentication process. The implementation is backward compatible and can be rolled out gradually with minimal risk.
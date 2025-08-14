# Sign-In/Sign-Up UX Design

## Overview

This document outlines the proposed sign-in and sign-up user experience for Photolala, following industry-standard patterns that users are familiar with.

## Design Pattern

The design follows the popular "Sign In with Not a Member" pattern used by major platforms like Google, Amazon, Netflix, and Spotify. This pattern:
- Prioritizes returning users (sign-in as primary action)
- Clearly guides new users to sign-up
- Reduces cognitive load with familiar UI elements
- Works well on mobile devices

## UI Layout

### Sign-In Screen

```
                    [Photolala Logo]
                         📸
                
                Welcome to Photolala
            Backup and browse your photos
            
            
            ┌─────────────────────────────┐
            │   🍎 Sign in with Apple     │
            └─────────────────────────────┘
            
            ┌─────────────────────────────┐
            │   🔵 Sign in with Google    │
            └─────────────────────────────┘
            
            
            ─────────────────────────────────
            
                  Don't have an account?
                  
               [Create Account] (text button)
```

### Sign-Up Screen

```
                    [Photolala Logo]
                         📸
                
                Create Your Account
          Join millions backing up their memories
            
            
            ┌─────────────────────────────┐
            │   🍎 Continue with Apple    │
            └─────────────────────────────┘
            
            ┌─────────────────────────────┐
            │   🔵 Continue with Google   │
            └─────────────────────────────┘
            
            
            ─────────────────────────────────
            
              Already have an account?
                  
                   [Sign In] (text button)
```

## UI Specifications

### Logo Section
- **Icon**: 80dp/80pt app icon, centered
- **Title**: Large bold font (28sp/28pt)
- **Subtitle**: Smaller gray text (16sp/16pt)
- **Spacing**: 24dp between elements

### Provider Buttons
- **Width**: Full width with 32dp horizontal margins (max 350dp)
- **Height**: 50dp/50pt
- **Style**: 
  - Apple: Black background, white text (iOS native style)
  - Google: White/surface color with subtle border
- **Content**: Provider logo (24dp) + text, horizontally centered
- **Spacing**: 12dp between buttons

### Bottom Section
- **Divider**: 1dp gray line, 50% opacity
- **Helper Text**: Small gray text (14sp/14pt)
- **Action Button**: Text-only button in accent color
- **Padding**: 16dp around text elements

## User Interactions

### Button States

1. **Normal State**
   - Full opacity
   - Enabled appearance
   - Responds to hover (desktop)

2. **Pressed State**
   - Scale animation to 0.95
   - Opacity to 0.8
   - Haptic feedback (mobile)

3. **Loading State**
   - Button text replaced with circular progress indicator
   - Other buttons disabled (50% opacity)
   - Prevents multiple submissions

4. **Disabled State**
   - 50% opacity
   - No interaction response
   - Used during loading

### Flow Behaviors

#### Sign-In Flow
1. User taps provider button
2. Loading state activates on tapped button
3. Native authentication sheet appears
4. On success:
   - Brief success animation (checkmark)
   - Navigate to main app
5. On failure:
   - Return to normal state
   - Show error message
6. On cancel:
   - Return to normal state

#### Sign-Up Flow
1. User taps "Create Account" from sign-in
2. Smooth transition animation (fade/slide)
3. Sign-up view appears with updated text
4. Provider buttons show "Continue with" instead of "Sign in with"
5. Same authentication flow as sign-in
6. On "no account found" error:
   - Automatically proceed with account creation

### Error Handling

#### Account Not Found (Sign-In)
```
⚠️ No account found with this email
Would you like to create a new account?

[Create Account]  [Cancel]
```

#### Account Already Exists (Sign-Up)
```
ℹ️ An account already exists with this email
Would you like to sign in instead?

[Sign In]  [Cancel]
```

#### Network Error
```
❌ Unable to connect
Please check your internet connection

[Try Again]
```

## Platform-Specific Considerations

### iOS/macOS
- Use native `ASAuthorizationAppleIDButton` for Apple Sign-In
- Follow Human Interface Guidelines spacing (16pt margins)
- Use SF Pro font family
- Implement with SwiftUI

### Android
- Use Material 3 components
- Follow Material Design spacing (24dp margins)
- Use Roboto font family
- Implement with Jetpack Compose
- Handle deep links for OAuth callbacks

## Accessibility

- All buttons have clear labels for screen readers
- Minimum touch target size: 44pt (iOS) / 48dp (Android)
- Color contrast meets WCAG AA standards
- Error messages announced to screen readers
- Keyboard navigation supported (desktop)

## Implementation Notes

1. **State Management**
   - Track authentication state globally
   - Handle loading states at component level
   - Persist user preference (last used provider)

2. **Security**
   - Never store passwords locally
   - Use secure OAuth 2.0 flows
   - Implement proper PKCE for mobile OAuth

3. **Analytics**
   - Track sign-in/sign-up conversion
   - Monitor authentication errors
   - Measure time to complete auth

## Future Enhancements

1. **Remember Me** option for faster sign-in
2. **Biometric Authentication** after initial sign-in
3. **Email/Password** option for users who prefer it
4. **Social Proof** ("Join 1M+ users")
5. **Progressive Disclosure** of benefits during sign-up
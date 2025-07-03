# Authentication UI Implementation

Last Updated: July 3, 2025

## Overview

Photolala's authentication system provides platform-specific UI implementations while maintaining consistent functionality across iOS, macOS, and Android.

## Platform Differences

### iOS
- **Presentation**: Full-screen sheet modal
- **Button Styling**: Custom styled with colored backgrounds
- **Layout**: Touch-optimized with larger tap targets
- **Navigation**: Integrated with WelcomeView

### macOS
- **Presentation**: Dedicated window (600x700)
- **Button Styling**: Native macOS styles (.borderedProminent, .bordered)
- **Layout**: Desktop-optimized with standard macOS spacing
- **Access**: Menu bar and toolbar buttons

### Android
- **Presentation**: Full-screen composable with navigation
- **Button Styling**: Material3 components (ElevatedButton, OutlinedButton)
- **Layout**: Touch-optimized with Material Design spacing
- **Navigation**: Integrated with Jetpack Navigation

## UI Components

### AuthenticationChoiceView

The main authentication interface that adapts to platform conventions:

#### Initial State (Not Signed In)
```
[Logo]
Welcome to Photolala
Backup and browse your photos securely

Already have an account?
[Sign In] - Primary button

--- OR ---

New to Photolala?
[Create Account] - Secondary button

[Browse Locally Only] - Text link
```

#### Provider Selection
```
Sign in with / Create account with

[Apple Logo] Sign in with Apple - Black button
[Google Logo] Sign in with Google - White button

[Back] - Text link
```

#### Signed In State
```
[Person Icon]
Signed in as
[User Name]
[Sign Out] - Red text link

----------

[Continue to Photos] - Primary button
```

## Button Styling

### iOS Buttons
- **Primary**: White text on accent color background
- **Secondary**: Accent color text on light background
- **Provider**: Custom branded colors (black for Apple)
- **All buttons**: Rounded corners (10px), full width

### macOS Buttons
- **Primary**: `.borderedProminent` with `.controlSize(.large)`
- **Secondary**: `.bordered` with `.controlSize(.large)`
- **Provider**: `.buttonStyle(.plain)` with custom backgrounds
- **All buttons**: Fixed minimum width (200-280px)

### Android Buttons
- **Primary**: ElevatedButton with filled background
- **Secondary**: OutlinedButton with border
- **Provider**: ElevatedButton with custom colors
- **All buttons**: Full width with 56dp height

## Sign In/Out Access Points

### iOS
1. **WelcomeView**: "Sign In to Enable Backup" button
2. **AuthenticationChoiceView**: Full authentication flow
3. **Sign Out**: Available in both views when signed in

### macOS
1. **Menu Bar**: Photolala → Sign In... / Sign Out [Username]
2. **Toolbar**: Sign In button in folder browser windows
3. **AuthenticationChoiceView**: Window-based authentication
4. **Cloud Settings**: Photolala → Cloud Backup Settings...

### Android
1. **WelcomeScreen**: "Sign In" and "Create Account" buttons
2. **AuthenticationScreen**: Full authentication flow
3. **SignedInCard**: User status with sign out option
4. **Cloud Browser**: Enabled only when signed in

## Technical Implementation

### Platform-Specific Code
```swift
#if os(iOS)
    .foregroundColor(.white)
    .frame(maxWidth: .infinity)
    .frame(height: 50)
    .background(Color.accentColor)
    .cornerRadius(10)
#else
    .frame(minWidth: 200)
#endif

#if os(macOS)
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
#endif
```

### Window Management (macOS)
```swift
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
    styleMask: [.titled, .closable],
    backing: .buffered,
    defer: false
)
window.contentView = NSHostingView(
    rootView: AuthenticationChoiceView()
        .environmentObject(IdentityManager.shared)
)
```

## Error Handling

- **User Cancellation**: No error shown, returns to previous state
- **No Account Found**: Clear message with provider name
- **Account Already Exists**: Directs user to sign in instead
- **Provider Not Implemented**: Informs user feature is coming

### Android Implementation
```kotlin
// Material3 Button Styling
ElevatedButton(
    onClick = { /* action */ },
    modifier = Modifier
        .fillMaxWidth()
        .height(56.dp),
    colors = ButtonDefaults.elevatedButtonColors(
        containerColor = MaterialTheme.colorScheme.surface
    )
) {
    // Button content
}

// Navigation
navController.navigate(PhotolalaRoute.SignIn.route)
navController.popBackStack()
```

## State Persistence

### iOS/macOS
- Sign-in state saved to Keychain
- Persists across app launches
- Shared across all windows (macOS)
- Cleared on sign out

### Android
- User data encrypted with Android Keystore
- Stored in DataStore preferences
- Persists across app launches
- Cleared on sign out

## Cross-Platform Identity

All platforms use the same S3 identity mapping:
- Path: `/identities/{provider}:{providerID}`
- Content: User's serviceUserID (UUID)
- Enables sign-in from any device
- Consistent user experience across platforms
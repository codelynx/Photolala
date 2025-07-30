# Android Account Linking Implementation

## Overview

This document details the Android implementation of the account linking feature to match iOS/macOS functionality.

## Implementation Summary

### 1. IdentityManager Enhancements

Added complete account linking functionality to `IdentityManager.kt`:

- **linkProvider()**: Initiates provider linking flow
- **completeLinkProvider()**: Completes linking after authentication
- **unlinkProvider()**: Removes provider with S3 cleanup
- **handleGoogleLinkResult()**: Handles Google Sign-In for linking
- **handleAppleLinkCallback()**: Handles Apple Sign-In for linking

Key features:
- Prevents linking already-linked providers
- Checks if provider is used by another account
- Cannot unlink the last provider
- Complete S3 identity mapping deletion

### 2. S3Service Enhancement

Added `deleteObject()` method to support unlinking:
```kotlin
suspend fun deleteObject(key: String): Result<Unit>
```

### 3. UI Implementation

#### AccountSettingsScreen
Modern Material3 design matching iOS/macOS:
- User header card with avatar
- Storage usage display with progress bar
- Subscription information card
- Sign-in methods management card
- Link/unlink functionality

#### AccountSettingsViewModel
Manages UI state and coordinates with IdentityManager:
- Handles provider linking initiation
- Manages Google/Apple Sign-In flows
- Processes unlinking with confirmation
- Error handling and state management

### 4. Navigation Integration

Updated `PhotolalaNavigation.kt`:
- Added AccountSettings route
- Handle Google Sign-In launcher for linking
- Track account linking flow state
- Coordinate with MainActivity for Apple callbacks

Updated `WelcomeScreen.kt`:
- Added "Account Settings" button when signed in
- Navigate to AccountSettingsScreen

### 5. Deep Link Handling

Enhanced `MainActivity.kt`:
- Detect account linking flow for Apple Sign-In
- Route callbacks to appropriate handler
- Maintain flow state across app restarts

## Error Handling

New `AuthException` types added:
- `ProviderAlreadyLinked`: Provider is already linked to account
- `ProviderInUse`: Provider is used by another account
- `ProviderNotLinked`: Attempting to unlink non-linked provider
- `CannotUnlinkLastProvider`: Preventing removal of last sign-in method

## User Flow

### Linking a Provider
1. User navigates to Account Settings
2. Taps "Link Another Sign-In Method"
3. Selects provider (Apple/Google)
4. Completes authentication
5. Provider is linked if not already in use

### Unlinking a Provider
1. User taps "Unlink" next to provider
2. Confirmation dialog appears
3. On confirm, S3 mapping is deleted
4. Provider is removed from account

## Testing Checklist

- [ ] Link Google to Apple account
- [ ] Link Apple to Google account
- [ ] Unlink secondary provider
- [ ] Prevent unlinking last provider
- [ ] Handle provider already linked error
- [ ] Handle provider in use by another account
- [ ] Google Sign-In callback handling
- [ ] Apple Sign-In deep link handling
- [ ] UI updates after linking/unlinking
- [ ] Error message display

## Platform Parity

Android now matches iOS/macOS with:
- ✅ Multi-provider authentication
- ✅ Account linking/unlinking
- ✅ S3 identity mapping management
- ✅ Modern UI design
- ✅ Confirmation dialogs
- ✅ Complete error handling

## Code Structure

```
android/app/src/main/java/com/electricwoods/photolala/
├── services/
│   ├── IdentityManager.kt         # Enhanced with linking methods
│   └── S3Service.kt              # Added deleteObject()
├── ui/screens/
│   ├── AccountSettingsScreen.kt   # New UI component
│   └── WelcomeScreen.kt          # Updated with settings button
├── viewmodels/
│   └── AccountSettingsViewModel.kt # New view model
├── navigation/
│   └── PhotolalaNavigation.kt     # Added AccountSettings route
└── MainActivity.kt                # Enhanced deep link handling
```
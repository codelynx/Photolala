# Google Sign-In Implementation Troubleshooting Journey

## Overview
This document chronicles the complete troubleshooting process for implementing Google Sign-In in Photolala Android, including all errors encountered and their solutions.

## Initial Setup Attempt

### Phase 1: Modern Credential Manager API Implementation
**Date**: July 3, 2025

#### What we tried:
1. Implemented Google Sign-In using the modern Credential Manager API
2. Created `GoogleAuthService.kt` using:
   - `androidx.credentials.CredentialManager`
   - `com.google.android.libraries.identity.googleid.GetGoogleIdOption`
   - `GoogleIdTokenCredential` for parsing results

#### Dependencies added:
```kotlin
implementation(libs.play.services.auth)           // 21.2.0
implementation(libs.androidx.credentials)          // 1.3.0
implementation(libs.androidx.credentials.play.services.auth)
implementation(libs.googleid)                      // 1.1.1
```

### Phase 2: Initial OAuth Configuration

#### First OAuth Client Creation
1. Created OAuth client in wrong project (not the Firebase project)
   - Client ID: `105828093997-jv95r6mi34su745el9v98927768kgopq.apps.googleusercontent.com`
   - Type: Web Application
   - Project: Unknown (not photolala-4b5ed)

#### Error Encountered:
```
Error 28444: Developer console is not set up correctly
```

## Troubleshooting Steps

### Issue 1: Project Mismatch
**Problem**: OAuth client was created in a different project than Firebase project

**Discovery Process**:
1. Found Firebase project ID: `photolala-4b5ed` (Project number: 663233468053)
2. Realized OAuth client was from different project (105828093997)
3. Projects didn't match, causing authentication failure

**Solution Attempted**:
- Created new Web OAuth client in photolala-4b5ed project
- New Client ID: `663233468053-2g2it4le41amcvcven8jv7b7t2kd7795.apps.googleusercontent.com`
- Updated GoogleAuthService with new Web Client ID

**Result**: Error 28444 persisted

### Issue 2: Missing google-services.json
**Problem**: Build failed due to missing google-services.json

**Error**:
```
File google-services.json is missing. The Google Services Plugin cannot function without it.
```

**Solution**:
1. Initially disabled google-services plugin to allow building
2. Created manual google-services.json with project info
3. Re-enabled plugin after proper setup

### Issue 3: Persistent Error 28444
**Problem**: Even with correct project, error 28444 continued

**Debugging Steps**:
1. Verified SHA-1 fingerprint: `9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89`
2. Added test user (kaz.yoshikawa@gmail.com) to OAuth consent screen
3. Confirmed Google account was on emulator
4. Added extensive debug logging to GoogleAuthService

**Logs showed**:
```
Starting Google Sign-In...
Web Client ID: 663233468053-2g2it4le41amcvcven8jv7b7t2kd7795.apps.googleusercontent.com
Package name: com.electricwoods.photolala
Created GetGoogleIdOption
Created GetCredentialRequest, calling credentialManager.getCredential...
GetCredentialException during sign in: 28444, Developer console is not set up correctly.
```

**Result**: Credential Manager API consistently failed with minimal debug information

### Issue 4: Switch to Legacy API
**Problem**: Credential Manager API wasn't working despite correct configuration

**Solution**: Created `GoogleSignInLegacyService.kt` using traditional Google Sign-In API
```kotlin
// Using deprecated but stable API
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
```

**Architecture Changes**:
1. Modified IdentityManager to handle activity result flow
2. Added `GoogleSignInPending` exception to trigger activity launch
3. Updated AuthenticationViewModel with activity launcher callback
4. Modified MainActivity to register activity result launcher
5. Updated PhotolalaNavigation to connect all components

### Issue 5: Error Code 10
**Problem**: Legacy implementation failed with error code 10

**Root Cause**: Only Web OAuth client existed, but Android OAuth client was required

**Discovery**:
- Error code 10 means app's SHA-1 and package name don't match any Android OAuth client
- Google Sign-In requires BOTH:
  - Android OAuth client (for app authentication)
  - Web OAuth client (for ID token)

### Issue 6: Android OAuth Client Already Exists
**Problem**: Couldn't create Android OAuth client in photolala-4b5ed

**Error**:
```
Create failed
The request failed because the Android package name and fingerprint are already in use
Tracking number: c6274976663887829
```

**Discovery**: Found two projects:
1. `photolala` - Had the Android OAuth client
2. `photolala-4b5ed` - Firebase project without Android client

**Solution**: 
1. Decided to consolidate to single project
2. Deleted photolala-4b5ed project
3. Used photolala project for everything

## Final Working Configuration

### Project Setup
- **Google Cloud Project**: `photolala` (Project ID: photolala)
- **Project Number**: 105828093997

### OAuth Clients in photolala project:
1. **Android OAuth Client**:
   - Name: Photolala Android
   - Client ID: `105828093997-jv95r6mi34su745el9v98927768kgopq.apps.googleusercontent.com`
   - Package: `com.electricwoods.photolala`
   - SHA-1: `9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89`

2. **Web OAuth Client**:
   - Name: Photolala Web Client
   - Client ID: `105828093997-qmr9jdj3h4ia0tt2772cnrejh4k0p609.apps.googleusercontent.com`
   - Used in code for requestIdToken()

### Working Implementation
- Used GoogleSignInLegacyService with traditional API
- Activity result pattern for sign-in flow
- Both OAuth clients from same project

## Lessons Learned

1. **Project Consistency is Critical**
   - All OAuth clients must be in the same Google Cloud project
   - Firebase project must match OAuth project

2. **Both OAuth Clients Required**
   - Android client authenticates the app
   - Web client provides ID token for user identification

3. **Error Messages Can Be Misleading**
   - Error 28444 "Developer console not set up correctly" was too vague
   - Error code 10 was more specific about missing Android OAuth client

4. **Legacy APIs Sometimes More Reliable**
   - Credential Manager API failed despite correct setup
   - Traditional GoogleSignIn API worked immediately

5. **SHA-1 Fingerprint Must Match Exactly**
   - Debug keystore SHA-1 must be registered with Android OAuth client
   - Different for debug vs release builds

6. **Test User Configuration**
   - OAuth consent screen requires test users during development
   - Must add actual Google account emails, not test addresses

## Error Code Reference

| Error Code | Meaning | Solution |
|------------|---------|----------|
| 28444 | Developer console not configured | Check project setup, often too vague |
| 10 | Sign-in configuration error | Missing Android OAuth client |
| 12500 | Sign-in failed | General configuration issue |
| 12501 | User cancelled | Normal user action |
| 12502 | Network error | Check connectivity |

## File Changes Summary

### Created Files:
- `GoogleAuthService.kt` (Credential Manager approach - failed)
- `GoogleSignInLegacyService.kt` (Traditional API - working)
- `google-services.json` (multiple versions)
- `GOOGLE_SIGNIN_SETUP.md` (documentation)

### Modified Files:
- `IdentityManager.kt` (added Google auth support)
- `AuthenticationViewModel.kt` (added activity launcher)
- `MainActivity.kt` (added result launcher)
- `PhotolalaNavigation.kt` (connected components)
- `build.gradle.kts` (added dependencies)

## Time Spent
- Initial Credential Manager implementation: ~2 hours
- Troubleshooting Error 28444: ~3 hours
- Switching to Legacy API: ~1 hour
- Resolving OAuth client issues: ~2 hours
- Total: ~8 hours

## Final Status
✅ Google Sign-In working successfully with legacy API implementation
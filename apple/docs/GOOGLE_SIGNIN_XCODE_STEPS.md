# Google Sign-In Xcode Configuration Steps

## Current Status
✅ Code implementation is complete:
- GoogleAuthProvider.swift created
- IdentityManager updated to support Google
- AuthenticationChoiceView enabled for Google
- PhotolalaApp.swift configured for URL handling

## Remaining Steps in Xcode

### 1. Add Google Sign-In Package (5 minutes)
1. Open `Photolala.xcodeproj` in Xcode
2. Select the project in navigator
3. Go to "Package Dependencies" tab
4. Click "+" button
5. Enter: `https://github.com/google/GoogleSignIn-iOS`
6. Version: Up to Next Major (7.1.0)
7. Add to "Photolala" target

### 2. Create iOS OAuth Client (10 minutes)
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: `photolala`
3. APIs & Services → Credentials
4. Create Credentials → OAuth client ID
5. Type: iOS
6. Name: "Photolala iOS"
7. Bundle ID: `com.electricwoods.photolala`
8. Copy the generated Client ID

### 3. Configure Info.plist (5 minutes)
In Xcode:
1. Select the "Photolala" target
2. Go to "Info" tab
3. Add URL Types:
   - Click "+" under URL Types
   - URL Schemes: `com.googleusercontent.apps.YOUR_IOS_CLIENT_ID`
   - Role: Editor
4. Add to "Queried URL Schemes":
   - `googlechrome`
   - `googlechrome-x-callback`

### 4. Build and Test (10 minutes)
1. Build the project (⌘B)
2. Run on iOS Simulator
3. Test Google Sign-In flow
4. Verify cross-platform with Android

## Verification Checklist
- [ ] Google Sign-In SDK appears in Package Dependencies
- [ ] No build errors after adding SDK
- [ ] OAuth client created in Google Cloud Console
- [ ] Info.plist has URL scheme configured
- [ ] App launches without crashes
- [ ] Google Sign-In button is enabled
- [ ] Sign-in flow completes successfully
- [ ] User info appears after sign-in

## Troubleshooting

### Common Build Issues
1. **"No such module 'GoogleSignIn'"**
   - Ensure package is added to correct target
   - Clean build folder (⇧⌘K) and rebuild

2. **"Invalid client ID"**
   - Verify URL scheme matches OAuth client
   - Check bundle ID matches exactly

3. **Sign-in redirects don't work**
   - Ensure URL scheme is properly configured
   - Check `onOpenURL` is implemented

### Testing Tips
- Use a real Google account
- Test both sign-up and sign-in flows
- Verify the same account works on Android
- Check S3 identity mapping is created

## Time Estimate
Total time in Xcode: ~30 minutes
- Package installation: 5 minutes
- OAuth setup: 10 minutes
- Info.plist config: 5 minutes
- Build and test: 10 minutes
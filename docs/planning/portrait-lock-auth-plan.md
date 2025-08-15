# Portrait Orientation Lock for Authentication Views

## Overview
Implement portrait orientation locking for WelcomeView and AuthenticationChoiceView on iPhone devices only. This ensures a consistent and optimal user experience during onboarding and authentication flows.

## Scope
- **Affected Views**:
  - WelcomeView
  - AuthenticationChoiceView
  - Any authentication-related sheets/modals
  
- **Platform Targeting**:
  - ✅ iPhone (portrait lock)
  - ❌ iPad (no restriction - supports all orientations)
  - ❌ macOS (not applicable)

## Implementation Strategy

### 1. Add AppDelegate for iOS
Create an AppDelegate specifically for iOS to manage orientation settings:
- Add iOS-specific AppDelegate (separate from macOS AppDelegate)
- Use conditional compilation with `#if os(iOS)`
- Maintain orientation lock state
- Implement `supportedInterfaceOrientationsFor` delegate method

### 2. Create OrientationHelper
Port the OrientationHelper from the reference implementation:
- Utility functions for locking/unlocking orientation
- iOS version compatibility (iOS 16+ vs older)
- Device type detection (iPhone vs iPad)

### 3. View Modifier Pattern
Create a reusable view modifier:
```swift
.portraitOnlyForiPhone()
```
This modifier will:
- Check if device is iPhone
- Apply portrait lock if true
- Do nothing on iPad/Mac

### 4. Apply to Target Views
- WelcomeView: Lock to portrait on iPhone
- AuthenticationChoiceView: Lock to portrait on iPhone
- Restore orientation when navigating to main photo browser

## Technical Implementation

### Files to Create:
1. `apple/Photolala/Utilities/AppDelegate+iOS.swift`
   - iOS-specific AppDelegate
   - Orientation management
   - Note: Keep separate from existing macOS AppDelegate

2. `apple/Photolala/Utilities/OrientationHelper.swift`
   - Orientation utility functions
   - View modifiers
   - Device detection

### Files to Modify:
1. `apple/Photolala/PhotolalaApp.swift`
   - Add iOS AppDelegate using `@UIApplicationDelegateAdaptor` within `#if os(iOS)` block
   - Keep existing macOS AppDelegate unchanged

2. `apple/Photolala/Views/WelcomeView.swift`
   - Apply portrait lock modifier

3. `apple/Photolala/Views/AuthenticationChoiceView.swift`
   - Apply portrait lock modifier

## Implementation Details

### AppDelegate Structure (Based on Reference)
```swift
#if os(iOS)
class iOSAppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all {
        didSet {
            // Trigger orientation update when lock changes
            if #available(iOS 16.0, *) {
                UIApplication.shared.connectedScenes.forEach { scene in
                    if let windowScene = scene as? UIWindowScene {
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientationLock))
                    }
                }
            } else {
                // Fallback for older iOS versions
                if orientationLock == .portrait {
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                } else {
                    UIDevice.current.setValue(UIInterfaceOrientation.unknown.rawValue, forKey: "orientation")
                }
            }
        }
    }
    
    func application(_ application: UIApplication, 
                    supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return iOSAppDelegate.orientationLock
    }
}
#endif
```

### Device Detection
```swift
var isIPhone: Bool {
    #if os(iOS)
    return UIDevice.current.userInterfaceIdiom == .phone
    #else
    return false
    #endif
}
```

### View Modifier Implementation (Adapted from Reference)
```swift
struct PortraitOnlyForiPhone: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .onAppear {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    OrientationHelper.lockOrientation(.portrait)
                }
            }
            .onDisappear {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    OrientationHelper.lockOrientation(.all)
                }
            }
        #else
        content
        #endif
    }
}

extension View {
    func portraitOnlyForiPhone() -> some View {
        self.modifier(PortraitOnlyForiPhone())
    }
}
```

## Testing Plan

### iPhone Testing
1. Launch app on iPhone
2. Verify WelcomeView is locked to portrait
3. Rotate device - view should not rotate
4. Navigate to authentication - should remain portrait
5. Complete auth and go to photo browser - rotation should work
6. Test on various iPhone models

### iPad Testing
1. Launch app on iPad
2. Verify WelcomeView supports all orientations
3. Rotate device - view should rotate freely
4. Navigate through auth flow - all orientations supported
5. Verify no regression in functionality

### Edge Cases
- [ ] App backgrounding during auth
- [ ] Incoming calls during auth
- [ ] Control Center orientation lock
- [ ] Split screen on iPad (should not affect)

## Benefits
1. **Better UX**: Authentication forms are optimized for portrait
2. **Consistent Experience**: Users don't accidentally rotate during sign-in
3. **Professional Polish**: Matches behavior of major apps
4. **Keyboard Handling**: Portrait keyboard is more comfortable for typing

## Risks & Mitigations
- **Risk**: Users might prefer landscape
  - **Mitigation**: Only lock during auth, main app supports all orientations
  
- **Risk**: Implementation might affect iPad
  - **Mitigation**: Device-specific checks ensure iPad is unaffected

## Future Enhancements
- Consider portrait lock for other forms (settings, etc.)
- Add user preference for orientation locking
- Animate orientation changes smoothly

## Key Differences from Reference Implementation

1. **Naming**: Using `iOSAppDelegate` instead of `AppDelegate` to avoid conflict with macOS AppDelegate
2. **Default State**: Starting with `.all` instead of `.portrait` to allow normal rotation in photo browser
3. **Device Check**: Added iPhone-only check in modifier (iPad stays unlocked)
4. **Restoration**: Returns to `.all` instead of `.portrait` when leaving auth views

## Integration with PhotolalaApp.swift

The app already has:
- macOS AppDelegate for window restoration control
- Conditional compilation blocks for platform-specific code
- NavigationStack wrapper for iOS

We need to add:
```swift
#if os(iOS)
@UIApplicationDelegateAdaptor(iOSAppDelegate.self) var iOSAppDelegate
#endif
```

## References
- Reference implementation: `/untracked/view-orientation-2/`
- Specifically: `OrientationHelper.swift` and `AppDelegate.swift` from reference
- Apple HIG on Orientation
- SwiftUI orientation handling patterns
# HomeView Implementation Plan

## Overview
Implement a new `HomeView` to replace `ContentView` in Photolala2, based on the design and functionality of Photolala1's `WelcomeView`. The HomeView will serve as the main landing screen with visual consistency while initially focusing on UI structure without full functionality wiring.

## Status: ✅ COMPLETED (2025-09-23)

## Goals
1. ✅ Create a visually polished home screen based on WelcomeView's design
2. ✅ Maintain platform-specific behaviors (portrait-only on iPhone, etc.)
3. ✅ Structure the view for future functionality integration
4. ✅ Follow Photolala2's MVVM architecture with nested view models

## File Structure

### Files Created
1. ✅ `apple/Photolala/Views/HomeView.swift` - Main home view implementation
2. ✅ `apple/Photolala/Utilities/OrientationHelper.swift` - Portrait orientation helper
3. ✅ `apple/Photolala/Views/Components/EnvironmentBadgeView.swift` - Environment indicator

### Files Modified
1. ✅ `apple/Photolala/PhotolalaApp.swift` - Replaced ContentView with HomeView
2. ✅ `apple/Photolala/AppDelegate.swift` - Added orientation support for iOS
3. ✅ `apple/Photolala/Info.plist` - Added iOS orientation configuration

## Implementation Details

### 1. HomeView Structure

```swift
// apple/Photolala/Views/HomeView.swift

import SwiftUI

struct HomeView: View {
    @State private var model = Model()

    var body: some View {
        // Main content layout
    }
}

// MARK: - View Model
extension HomeView {
    @Observable
    final class Model {
        // State properties
        var showingFolderPicker = false
        var showingSignIn = false
        var showSignInSuccess = false
        var signInSuccessMessage = ""
        var showingAccountSettings = false

        // Placeholder for user state
        var isSignedIn = false
        var currentUser: PhotolalaUser?

        // UI State
        var welcomeMessage: String {
            #if os(macOS)
            if isSignedIn {
                "Welcome back! Choose how to browse your photos"
            } else {
                "Welcome! Sign in to access cloud features or browse locally"
            }
            #else
            "Choose a source to browse photos"
            #endif
        }

        // Placeholder actions (no implementation yet)
        @MainActor
        func selectFolder() {
            print("[HomeView] Select folder tapped")
        }

        @MainActor
        func openPhotoLibrary() {
            print("[HomeView] Photo library tapped")
        }

        @MainActor
        func openCloudPhotos() {
            print("[HomeView] Cloud photos tapped")
        }

        @MainActor
        func signIn() {
            print("[HomeView] Sign in tapped")
        }

        @MainActor
        func openAccountSettings() {
            print("[HomeView] Account settings tapped")
        }
    }
}
```

### 2. Visual Layout Components

#### Header Section
- App icon (80x80) with fallback to system icon
- "Photolala" title with large title font
- Welcome message that adapts to authentication state

#### Source Selection Buttons
- **Local Folder**: "Browse Local Folder" (macOS) / "Browse Folder" (iOS)
- **Apple Photos**: "Apple Photos Library"
- **Cloud Photos**: "Cloud Photos" (shown only when signed in)

#### Authentication Section
Based on state:
- **Signed Out**: Sign In button with benefits text
- **Signed In**: User avatar with checkmark, display name, Account Settings button

#### Platform-Specific Styling
- macOS: Minimum window size 600x700
- iOS: Full-width buttons, portrait-only on iPhone
- Environment badge overlay (iOS only, dev/staging builds)

### 3. OrientationHelper Implementation

```swift
// apple/Photolala/Utilities/OrientationHelper.swift

#if os(iOS)
import SwiftUI
import UIKit

struct OrientationHelper {
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        // Set the static property on AppDelegate
        AppDelegate.orientationLock = orientation

        // Force the orientation update
        UIViewController.attemptRotationToDeviceOrientation()
    }

    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation: UIInterfaceOrientation) {
        self.lockOrientation(orientation)

        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
            windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }
}

struct PortraitOnlyForiPhone: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    OrientationHelper.lockOrientation(.portrait, andRotateTo: .portrait)
                }
            }
            .onDisappear {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    OrientationHelper.lockOrientation(.all)
                }
            }
    }
}

extension View {
    func portraitOnlyForiPhone() -> some View {
        modifier(PortraitOnlyForiPhone())
    }
}
#else
// macOS implementation - just return the view unchanged
import SwiftUI

extension View {
    func portraitOnlyForiPhone() -> some View {
        self
    }
}
#endif
```

### 4. EnvironmentBadgeView

```swift
// apple/Photolala/Views/Components/EnvironmentBadgeView.swift

struct EnvironmentBadgeView: View {
    @AppStorage("environment_preference") private var environmentPreference: String?

    private var currentEnvironment: String {
        let env = environmentPreference ?? "development"
        // Return DEV/STAGE/PROD based on environment
    }

    private var badgeColor: Color {
        // Orange for dev, Yellow for staging, Blue for production
    }

    var body: some View {
        #if DEBUG || DEVELOPER
        // Show environment badge
        #else
        EmptyView()
        #endif
    }
}
```

### 5. PhotolalaApp Integration

```swift
// Modified apple/Photolala/PhotolalaApp.swift

@main
struct PhotolalaApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()  // Replaced ContentView with HomeView
                #if os(iOS)
                .portraitOnlyForiPhone()
                #endif
                #if os(macOS)
                .frame(minWidth: 600, minHeight: 700)
                #endif
        }
        // ... rest of configuration
    }
}
```

### 6. AppDelegate iOS Orientation Support

```swift
// Modified apple/Photolala/AppDelegate.swift (iOS section)

class AppDelegate: UIResponder, UIApplicationDelegate {
    // Support for orientation locking
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    // ... rest of implementation
}
```

### 7. Info.plist iOS Orientation Configuration

```xml
<!-- Added to apple/Photolala/Info.plist -->

<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
</array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

## UI Component Specifications

### Button Styles
- **Primary Actions**: `.borderedProminent` with `.controlSize(.large)`
- **Secondary Actions**: `.bordered` or `.plain`
- **Destructive**: Red foreground color for sign out

### Spacing Guidelines
- Main section spacing: 30pt
- Button spacing within sections: 12pt
- Padding around content: 40pt
- Divider width: 300pt max

### Typography
- App title: `.largeTitle` with `.fontWeight(.medium)`
- Welcome message: `.headline` with `.foregroundStyle(.secondary)`
- Benefits text: `.caption` with `.foregroundStyle(.secondary)`

### Colors
- Use system colors for adaptability to dark/light mode
- Accent color for primary actions
- Secondary color for descriptive text
- Success indicators: Green
- Environment badges: Orange (dev), Yellow (staging), Blue (production)

## Platform Differences

### macOS
- No welcome screen by default (per CLAUDE.md)
- Separate windows for different photo sources
- Window menu integration
- Keyboard shortcuts support
- SettingsLink for preferences

### iOS/iPadOS
- NavigationStack for navigation
- Full-width buttons
- Sheet presentations for pickers
- Portrait-only on iPhone
- Touch-optimized tap targets

## Implementation Phases

### Phase 1: Basic UI Structure ✅ (COMPLETED)
- ✅ Created HomeView with visual layout
- ✅ Added placeholder buttons and actions
- ✅ Implemented orientation helper
- ✅ Added environment badge
- ✅ Wired up to PhotolalaApp
- ✅ Fixed orientation lock using static property pattern

### Phase 2: Authentication Integration (Future)
- Connect to AccountManager
- Implement sign in/out flows
- Show real user data
- Handle authentication states

### Phase 3: Navigation & Actions (Future)
- Implement folder picker
- Add photo library navigation
- Cloud browser integration
- Settings sheet presentation

### Phase 4: Polish & Animations (Future)
- Success message animations
- Loading states
- Error handling
- Accessibility improvements

## Implementation Notes

### Key Fixes Applied

1. **Orientation Lock Fix**
   - Changed `orientationLock` from instance to `static` property on AppDelegate
   - Updated OrientationHelper to use `AppDelegate.orientationLock` directly
   - Added iOS orientation settings to Info.plist
   - This matches Photolala1's proven implementation pattern

2. **Platform-Specific Image Handling**
   - Used `UIImage` for iOS and `NSImage` for macOS
   - Proper conditional compilation for platform-specific code
   - Fixed background color references (UIColor.systemBackground vs NSColor.windowBackgroundColor)

3. **SwiftUI Compatibility**
   - Changed `onReceive` to `onChange` for observing model properties
   - Added proper imports for platform-specific frameworks
   - Ensured macOS extension imports SwiftUI in OrientationHelper

## Testing Considerations

1. **Visual Testing**
   - ✅ Layout verified on different screen sizes
   - ✅ Dark/light mode appearance works
   - ✅ Environment badge visible in development builds

2. **Orientation Testing (iOS)**
   - ✅ Portrait lock confirmed on iPhone
   - ✅ iPad allows all orientations

3. **Platform Testing**
   - ✅ Builds successfully on macOS
   - ✅ Builds successfully on iOS Simulator
   - ✅ Platform-specific UI differences work correctly

## Success Criteria

1. ✅ HomeView renders with similar visual style to WelcomeView
2. ✅ Portrait-only works on iPhone (fixed with static property)
3. ✅ All buttons are visible but show placeholder actions
4. ✅ Environment badge shows in development builds
5. ✅ View follows MVVM pattern with nested model
6. ✅ Platform-specific UI differences are respected
7. ✅ Code is ready for future functionality integration
8. ✅ Both macOS and iOS builds succeed

## Notes

- Successfully implemented visual structure without full functionality
- Orientation lock required static property pattern (learned from Photolala1)
- Platform-specific code properly separated with conditional compilation
- Ready for AccountManager integration when needed
- All placeholder actions log to console for debugging

## Important Considerations

### Environment Preference Changes
⚠️ **Warning**: The `environment_preference` AppStorage property is observed by multiple components including:
- `EnvironmentBadgeView` - displays current environment
- Any future services that may switch behavior based on environment
- Potential credential selection logic

**Testing Recommendation**: When implementing environment switching in diagnostics or settings:
1. Perform smoke tests on all environment-sensitive flows
2. Verify services reconnect/reinitialize properly after environment change
3. Check that any cached data is invalidated if needed
4. Ensure UI updates consistently across all observing views
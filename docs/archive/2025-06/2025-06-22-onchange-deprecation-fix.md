# onChange Deprecation Fix - 2025-06-22

## Summary

Fixed all deprecated `onChange(of:perform:)` usage across the codebase to use the new iOS 17/macOS 14 syntax.

## Changes Made

### Files Updated (8 instances in 5 files)

1. **ApplePhotosBrowserView.swift** (1 instance)
   - Changed: `onChange(of: showingInspector) { _, isShowing in`
   - To: `onChange(of: showingInspector) { oldValue, newValue in`
   - Used two-parameter version because `newValue` is used

2. **InspectorView.swift** (3 instances)
   - Changed: `onChange(of: photo.id) { _, _ in`
   - To: `onChange(of: photo.id) {`
   - Used zero-parameter version as values aren't needed

3. **PhotoPreviewView.swift** (2 instances)
   - Changed: `onChange(of: self.currentIndex) { _, _ in` and `{ _ in`
   - To: `onChange(of: self.currentIndex) {`
   - Used zero-parameter version

4. **S3PhotoBrowserView.swift** (1 instance)
   - Changed: `onChange(of: showingInspector) { _, isShowing in`
   - To: `onChange(of: showingInspector) { oldValue, newValue in`
   - Used two-parameter version because `newValue` is used

5. **SignInPromptView.swift** (1 instance)
   - Changed: `onChange(of: self.identityManager.isSignedIn) { _, isSignedIn in`
   - To: `onChange(of: self.identityManager.isSignedIn) { oldValue, newValue in`
   - Used two-parameter version because `newValue` is used

## New onChange Syntax Rules

In iOS 17/macOS 14, the onChange modifier has two forms:

1. **Zero-parameter closure** (when you don't need the values):
   ```swift
   .onChange(of: someValue) {
       // Do something
   }
   ```

2. **Two-parameter closure** (when you need old and/or new values):
   ```swift
   .onChange(of: someValue) { oldValue, newValue in
       // Use oldValue and/or newValue
   }
   ```

The old single-parameter form `{ _ in }` and ignored parameters form `{ _, _ in }` are deprecated.

## Build Status

✅ All changes compile successfully
✅ No more deprecation warnings for onChange
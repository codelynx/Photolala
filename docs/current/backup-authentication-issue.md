# S3 Backup Authentication Issue

## Problem Description

Photos fail to upload to S3 with error `credentialsNotFound`, even though AWS credentials are properly configured via credential-code.

## Root Cause Analysis

### 1. **Misleading Error Message**
The error shows as `credentialsNotFound` but the actual issues are:
- User is not signed in to the app
- `s3Service` is not initialized without a signed-in user

### 2. **Error Mapping in S3BackupManager**
```swift
// Lines 301-302 in S3BackupManager.swift
static let notSignedIn = S3BackupError.credentialsNotFound
static let serviceNotConfigured = S3BackupError.credentialsNotFound
```

Both "not signed in" and "service not configured" errors are mapped to `credentialsNotFound`, making debugging confusing.

### 3. **Authentication Flow**
The upload process requires:
1. AWS credentials (✓ provided by credential-code)
2. Signed-in user (✗ missing)
3. User ID for S3 path organization

### 4. **Code Flow**
```swift
// S3BackupManager.uploadPhoto()
guard let userId else {
    throw S3BackupError.notSignedIn  // This becomes credentialsNotFound
}

guard let s3Service else {
    throw S3BackupError.serviceNotConfigured  // This also becomes credentialsNotFound
}
```

## Current Behavior

1. User clicks star to queue photo for backup
2. BackupQueueManager tries to upload after 15 seconds
3. Upload fails because no user is signed in
4. Error shows as `credentialsNotFound` (misleading)
5. Photo status changes to failed (red exclamation mark)

## Log Evidence
```
No stored user found
[BackupQueueManager] Starting backup process...
Failed to upload #e9de5: credentialsNotFound
```

## Solution Options

### Option 1: Fix Error Messages (Recommended)
Make error messages more specific:
```swift
static let notSignedIn = S3BackupError.notAuthenticated
static let serviceNotConfigured = S3BackupError.notConfigured
```

### Option 2: Allow Anonymous Uploads
- Remove user authentication requirement
- Use device ID or anonymous ID for S3 paths
- Would require significant architecture changes

### Option 3: Auto-Create Anonymous User
- Create a default user when none exists
- Allows uploads without explicit sign-in
- Maintains current architecture

## Temporary Workaround

Sign in to the app through Settings or Sign In screen before attempting to backup photos.

## Technical Details

### Files Involved
- `/apple/Photolala/Services/S3BackupManager.swift` - Main backup manager
- `/apple/Photolala/Services/BackupQueueManager.swift` - Queue management
- `/apple/Photolala/Services/IdentityManager.swift` - User authentication
- `/apple/Photolala/Services/S3BackupService.swift` - S3 operations

### Key Methods
- `S3BackupManager.uploadPhoto()` - Checks for userId
- `S3BackupManager.checkConfiguration()` - Initializes s3Service
- `IdentityManager.currentUser` - Provides userId

## Next Steps

1. Implement proper sign-in flow
2. Update error messages to be more descriptive
3. Consider allowing uploads without sign-in for better UX
4. Add user guidance when backup fails due to authentication

## Notes

- AWS credentials ARE properly configured via credential-code
- The issue is NOT with AWS authentication
- The issue IS with app user authentication
- Star indicator correctly shows backup status (yellow = queued, red = failed)
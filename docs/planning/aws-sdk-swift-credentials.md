# AWS SDK Swift Credentials in macOS Apps

## Problem

macOS applications launched from Finder (by double-clicking or via Xcode) do not inherit shell environment variables. This means AWS credentials set in your shell (via `export AWS_ACCESS_KEY_ID=...`) are not available to the app.

## Why This Happens

1. **Different Process Trees**: 
   - Terminal apps inherit from the shell process
   - GUI apps inherit from launchd/WindowServer, not your shell

2. **Security**: 
   - macOS sandboxing limits environment variable access
   - Prevents apps from accessing potentially sensitive shell data

## Solutions

### 1. Xcode Scheme Environment Variables (Recommended for Development)

Edit Scheme → Run → Arguments → Environment Variables:
- `AWS_ACCESS_KEY_ID` = your_access_key
- `AWS_SECRET_ACCESS_KEY` = your_secret_key

**Pros**: Works immediately, easy to set up
**Cons**: Stored in xcscheme file (add to .gitignore)

### 2. AWS Credentials File

Create `~/.aws/credentials`:
```ini
[default]
aws_access_key_id = YOUR_KEY
aws_secret_access_key = YOUR_SECRET
```

**Note**: Sandboxed apps can't access this location. You need to either:
- Disable App Sandbox (development only)
- Copy to app container: `~/Library/Containers/com.electricwoods.photolala/Data/.aws/credentials`

### 3. Launch from Terminal

```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
open /path/to/Photolala.app
```

## Implementation in Photolala

The S3BackupService checks credentials in this order:

1. **Environment variables** (from Xcode scheme or terminal)
2. **AWS credentials file** (in app container for sandboxed apps)
3. **Throws error** if neither found

```swift
// S3BackupService.swift
convenience init() async throws {
    // Check environment variables first
    if let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
       let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] {
        try await self.init(accessKey: accessKey, secretKey: secretKey)
        return
    }
    
    // Check credentials file (in app container)
    let credentialsPath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".aws/credentials")
    
    // Parse and use credentials...
}
```

## Security Considerations

### Development
- Use Xcode scheme environment variables
- Add `xcshareddata/xcschemes/**` to .gitignore
- Never commit credentials

### Production
- Implement secure credential input UI
- Store in Keychain
- Use AWS STS for temporary credentials
- Consider AWS Cognito for user authentication

## Current Status

✅ **Working POC Implementation**:
- S3BackupService successfully uploads/downloads photos
- Uses MD5 for deduplication
- Environment variables work via Xcode scheme
- Test view allows photo selection and upload

**Next Steps**:
- Implement Keychain storage
- Add credential management UI
- Integrate with main photo browser
- Add progress indicators for uploads
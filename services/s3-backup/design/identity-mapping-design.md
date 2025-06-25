# Identity Mapping Design - S3 Based

## Overview

Store user identity mappings in S3 to ensure consistent service user IDs across devices without needing a backend server.

## S3 Structure

```
s3://photolala/
├── identities/
│   ├── appleid/
│   │   └── {apple-id}              # Plain text file containing UUID
│   ├── googleid/                   # Future support
│   │   └── {google-id}
│   └── fbid/                       # Future support
│       └── {facebook-id}
├── photos/
│   └── {service-user-id}/
│       └── {md5}.dat
├── thumbnails/
│   └── {service-user-id}/
│       └── {md5}.dat
└── metadata/
    └── {service-user-id}/
        └── {md5}.plist
```

## File Format

Each mapping file is a simple text file:
```
# File: identities/appleid/000062.4d7e1357f2a04a0486d31db7e8ed98f8
a7f8d93e-5c2f-4b8a-9d6e-1a2b3c4d5e6f
```

## Implementation Flow

### Sign In Flow

```swift
func getOrCreateServiceUserId(appleId: String) async throws -> String {
    let mappingKey = "identities/appleid/\(appleId)"
    
    // 1. Try to get existing mapping
    if let existingUUID = try? await s3.getObject(
        bucket: "photolala",
        key: mappingKey
    ) {
        return existingUUID
    }
    
    // 2. Create new UUID
    let newUUID = UUID().uuidString
    
    // 3. Try to put (with if-not-exists condition)
    do {
        try await s3.putObject(
            bucket: "photolala",
            key: mappingKey,
            body: newUUID,
            ifNoneMatch: "*"  // Only succeed if object doesn't exist
        )
        return newUUID
    } catch {
        // 4. If put failed (race condition), get the existing one
        if let existingUUID = try? await s3.getObject(
            bucket: "photolala",
            key: mappingKey
        ) {
            return existingUUID
        }
        throw error
    }
}
```

## Benefits

1. **Serverless**: No backend needed
2. **Cross-device sync**: Same UUID on all devices
3. **Multi-provider ready**: Can map multiple auth providers to same user
4. **Simple**: Just text files in S3
5. **Atomic**: S3's conditional puts prevent race conditions

## Security Considerations

1. **Mapping files are sensitive**: They link real identities to storage
2. **Consider encryption**: Could encrypt the mapping files
3. **Access control**: Ensure proper S3 bucket policies

## Future Enhancement: Account Linking

```
# User wants to link Google account to existing Apple account
1. Sign in with Apple -> get serviceUserId: "a7f8d93e..."
2. Sign in with Google -> create mapping:
   - identities/googleid/{google-id} -> "a7f8d93e..."
3. Both auth methods now access same photos
```

## Implementation Priority

1. **Phase 1**: Single Apple ID mapping (current need)
2. **Phase 2**: Add audit trail (who linked when)
3. **Phase 3**: Multiple provider support
4. **Phase 4**: Account unlinking/relinking

## Concerns

- **Privacy**: Mapping files reveal which Apple IDs use the service
- **GDPR**: Need ability to delete mappings on request
- **Backup**: These mappings are critical - need redundancy

## Alternative: Hash-based Approach

Instead of storing raw Apple IDs:
```
# File: identities/appleid/{sha256(apple-id + salt)}
a7f8d93e-5c2f-4b8a-9d6e-1a2b3c4d5e6f
```

This provides privacy but makes account recovery harder.
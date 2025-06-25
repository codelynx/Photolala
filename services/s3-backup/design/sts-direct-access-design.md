# STS Direct Access Design

## You're Right: AWS SDK + STS Can Work

### How STS with AWS SDK Works

```swift
// iOS App - Using AWS SDK for Swift
import AWSS3
import AWSSTS

class S3Manager {
    private var s3Client: S3Client?
    private var credentials: STSCredentials?
    private let userPrefix: String
    
    func initialize() async throws {
        // 1. Get temporary credentials from our API
        let response = try await PhotolalaAPI.getSTSCredentials()
        
        // 2. Configure AWS SDK with temporary credentials
        let credentialsProvider = STSAssumeRoleCredentialsProvider(
            roleArn: response.roleArn,
            sessionName: "photolala-user-\(userId)",
            credentialsProvider: StaticCredentialsProvider(
                accessKeyId: response.accessKey,
                secretAccessKey: response.secretKey,
                sessionToken: response.sessionToken
            )
        )
        
        // 3. Create S3 client with user-scoped credentials
        self.s3Client = try S3Client(
            region: "us-east-1",
            credentialsProvider: credentialsProvider
        )
        
        // 4. These credentials ONLY work for user's prefix
        self.userPrefix = "users/\(userId)/"
    }
    
    func uploadPhoto(data: Data, md5: String) async throws {
        // This will succeed - within user's prefix
        try await s3Client.putObject(
            bucket: "photolala",
            key: "\(userPrefix)photos/\(md5).dat",
            body: data
        )
        
        // This would fail with 403 - outside user's prefix
        // try await s3Client.putObject(
        //     bucket: "photolala",
        //     key: "users/other-user/photos/\(md5).dat",
        //     body: data
        // )
    }
}
```

## Backend STS Token Generation

```python
# Photolala API - Generates user-scoped credentials
@app.post("/api/auth/sts-credentials")
async def get_sts_credentials(user: User = Depends(get_current_user)):
    # Define exactly what this user can access
    policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject"
                ],
                "Resource": f"arn:aws:s3:::photolala/users/{user.id}/*"
            },
            {
                "Effect": "Allow",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::photolala",
                "Condition": {
                    "StringLike": {
                        "s3:prefix": f"users/{user.id}/*"
                    }
                }
            }
        ]
    }
    
    # Generate temporary credentials
    sts_client = boto3.client('sts')
    assumed_role = sts_client.assume_role(
        RoleArn='arn:aws:iam::123456789012:role/PhotolalaUserAccess',
        RoleSessionName=f'user-{user.id}',
        Policy=json.dumps(policy),
        DurationSeconds=3600  # 1 hour
    )
    
    creds = assumed_role['Credentials']
    return {
        "access_key": creds['AccessKeyId'],
        "secret_key": creds['SecretAccessKey'],
        "session_token": creds['SessionToken'],
        "expiration": creds['Expiration'].isoformat(),
        "user_prefix": f"users/{user.id}/"
    }
```

## Advantages of Direct STS Approach

### 1. Performance
```swift
// Direct multipart upload - very efficient
func uploadLargePhoto(url: URL) async throws {
    let uploadRequest = S3.CreateMultipartUploadRequest(
        bucket: "photolala",
        key: "\(userPrefix)photos/\(md5).dat"
    )
    
    let multipart = try await s3Client.createMultipartUpload(uploadRequest)
    // ... handle multipart upload directly
}
```

### 2. Offline Capability
```swift
// Can queue uploads when offline
class OfflineUploadQueue {
    func queueUpload(photo: Photo) {
        // Store locally
        queue.append(photo)
        
        // Upload when online
        if isOnline {
            processQueue()
        }
    }
}
```

### 3. Native Features
- Progress callbacks
- Retry logic
- Streaming uploads
- Parallel uploads
- Bandwidth throttling

## Comparison: STS vs Presigned URLs

| Feature | STS Direct | Presigned URLs |
|---------|------------|----------------|
| **Performance** | ⭐⭐⭐⭐⭐ Native SDK | ⭐⭐⭐ HTTP uploads |
| **Offline** | ⭐⭐⭐⭐ Queue & retry | ⭐⭐ Manual implementation |
| **Complexity** | ⭐⭐ Token refresh | ⭐⭐⭐⭐ Simple |
| **Security** | ⭐⭐⭐⭐ User-scoped | ⭐⭐⭐⭐⭐ Per-file |
| **Quota Control** | ⭐⭐ Check after | ⭐⭐⭐⭐⭐ Check before |
| **Bulk Ops** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐ One by one |

## Hybrid Approach (Best of Both)

### Use STS for:
- Bulk uploads/downloads
- Large files (multipart)
- Offline-capable features
- Power users

### Use Presigned URLs for:
- Web access
- Shared files
- Single file operations
- Casual users

### Implementation
```swift
class PhotoManager {
    enum UploadStrategy {
        case direct    // STS + AWS SDK
        case presigned // API presigned URLs
    }
    
    func uploadPhoto(data: Data, strategy: UploadStrategy) async throws {
        switch strategy {
        case .direct:
            // Use STS credentials
            try await stsManager.upload(data)
            
        case .presigned:
            // Use presigned URL
            let url = try await api.getPresignedUploadURL()
            try await httpUpload(data, to: url)
        }
    }
}
```

## Security Considerations for STS

### Token Refresh Strategy
```swift
class STSTokenManager {
    private var credentials: STSCredentials?
    private var expirationDate: Date?
    
    func getValidCredentials() async throws -> STSCredentials {
        // Refresh if expired or about to expire
        if let expiration = expirationDate,
           Date().addingTimeInterval(300) > expiration {
            credentials = try await refreshCredentials()
        }
        
        return credentials!
    }
    
    private func refreshCredentials() async throws -> STSCredentials {
        // Get new credentials from API
        let response = try await api.getSTSCredentials()
        expirationDate = response.expiration
        return response.credentials
    }
}
```

### Handling Compromised Tokens
```python
# Backend can revoke specific sessions
@app.post("/api/auth/revoke-session")
async def revoke_session(session_id: str, admin: Admin):
    # Add to blacklist
    blacklisted_sessions.add(session_id)
    
    # Future STS requests check blacklist
    # AWS will deny access for blacklisted sessions
```

## Recommendation

You're right that STS is viable! Here's my updated recommendation:

### Phase 1: Start Simple
- Use presigned URLs for MVP
- Easier to implement and debug
- Good enough for most users

### Phase 2: Add STS for Power Features
- Implement STS for desktop app
- Add bulk upload features
- Enable offline queuing

### Phase 3: Smart Selection
```swift
// Automatically choose best method
func uploadPhotos(photos: [Photo]) async throws {
    if photos.count > 10 {
        // Use STS for bulk
        try await uploadViaSTS(photos)
    } else {
        // Use presigned for small batches
        try await uploadViaPresigned(photos)
    }
}
```

The AWS SDK for Swift with STS is indeed a powerful option that shouldn't be dismissed!
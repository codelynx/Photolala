# IAM and Authentication Architecture for S3 Backup Service

## Overview

This document describes how Photolala handles AWS IAM authentication for the S3 backup service, enabling secure, scalable access to S3 storage for millions of users without creating individual IAM users.

## Current State (POC)

The POC implementation uses static AWS credentials stored in Keychain. This works for testing but isn't suitable for production.

## Production Architecture: STS Token Vending

### Core Concept

```
User → Sign in with Apple → Photolala Backend → AWS STS → Temporary S3 Credentials
```

Each user gets temporary, scoped AWS credentials that only allow access to their own data.

### Architecture Diagram

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Photolala     │────▶│   Photolala      │────▶│   AWS STS   │
│   iOS/macOS     │ (1) │   Backend API    │ (2) │             │
│   App           │◀────│                  │◀────│             │
└────────┬────────┘ (3) └──────────────────┘ (4) └─────────────┘
         │                                              
         │ (5) Direct S3 Access                        
         │ with Temporary Credentials                  
         ▼                                             
┌─────────────────────────────────────────┐
│                  AWS S3                  │
│  ┌─────────────┬──────────┬──────────┐  │
│  │photos/       │thumbnails/│metadata/ │  │
│  │ └{userId}/   │ └{userId}/│ └{userId}/│  │
│  │   └{md5}.dat │   └{md5}  │  └{md5}   │  │
│  └─────────────┴──────────┴──────────┘  │
└─────────────────────────────────────────┘

Flow:
1. App sends Apple ID token to backend
2. Backend validates user and requests STS token
3. STS returns temporary credentials
4. Backend returns credentials to app
5. App uploads directly to S3
```

### Why Not Individual IAM Users?

| Approach | Limit | Management | Security | Scalability |
|----------|-------|------------|----------|-------------|
| IAM Users | 5,000 per account | Complex | Users get permanent credentials | ❌ Doesn't scale |
| Single Service Account | No limit | Simple | All access through backend | ⚠️ Backend bottleneck |
| **STS Token Vending** | **No limit** | **Moderate** | **Temporary credentials** | **✅ Infinitely scalable** |

## Implementation Details

### 1. AWS IAM Setup (One-Time)

Create an IAM role that your backend can assume:

```json
{
  "RoleName": "PhotolalaUserAccessRole",
  "AssumeRolePolicyDocument": {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR_ACCOUNT:user/photolala-backend"
      },
      "Action": "sts:AssumeRole"
    }]
  },
  "MaxSessionDuration": 43200
}
```

The role itself needs NO policies - we'll use inline session policies for each user.

### 2. Backend Token Service

```swift
// Swift/Vapor Example
import Vapor
import AWSSTS

// Configure AWS STS client
extension Application {
    var sts: STSClient {
        STSClient(
            region: "us-east-1",
            credentialProvider: .static(
                accessKeyId: Environment.get("AWS_ACCESS_KEY_ID")!,
                secretAccessKey: Environment.get("AWS_SECRET_ACCESS_KEY")!
            )
        )
    }
}

// Token endpoint
func routes(_ app: Application) throws {
    let protected = app.grouped(UserAuthenticator())
    
    protected.post("api", "v1", "auth", "sts-token") { req async throws -> STSTokenResponse in
        // Get authenticated user
        let user = try req.auth.require(User.self)
        
        // Validate subscription
        guard user.hasActiveSubscription else {
            throw Abort(.forbidden, reason: "Active subscription required")
        }
        
        // Check storage quota
        guard user.storageUsed < user.storageLimit else {
            throw Abort(.forbidden, reason: "Storage quota exceeded")
        }
        
        let userId = user.serviceUserId // e.g., "u_3fa85f64-4567-89ab-cdef-0123456789ab"
        
        // Create user-scoped policy
        let policy = """
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "AllowUserFolderAccess",
                    "Effect": "Allow",
                    "Action": [
                        "s3:GetObject",
                        "s3:PutObject",
                        "s3:DeleteObject",
                        "s3:RestoreObject",
                        "s3:GetObjectAttributes"
                    ],
                    "Resource": [
                        "arn:aws:s3:::photolala/photos/\(userId)/*",
                        "arn:aws:s3:::photolala/thumbnails/\(userId)/*",
                        "arn:aws:s3:::photolala/metadata/\(userId)/*"
                    ]
                },
                {
                    "Sid": "AllowListingUserFolder",
                    "Effect": "Allow",
                    "Action": "s3:ListBucket",
                    "Resource": "arn:aws:s3:::photolala",
                    "Condition": {
                        "StringLike": {
                            "s3:prefix": [
                                "photos/\(userId)/*",
                                "thumbnails/\(userId)/*",
                                "metadata/\(userId)/*"
                            ]
                        }
                    }
                }
            ]
        }
        """
        
        // Request temporary credentials
        let assumeRoleRequest = AssumeRoleRequest(
            roleArn: Environment.get("PHOTOLALA_ROLE_ARN")!,
            roleSessionName: "photolala-\(userId)-\(Date().timeIntervalSince1970)",
            durationSeconds: 3600, // 1 hour
            policy: policy,
            tags: [
                Tag(key: "UserId", value: userId),
                Tag(key: "SubscriptionTier", value: user.subscriptionTier.rawValue)
            ]
        )
        
        let response = try await req.application.sts.assumeRole(assumeRoleRequest)
        
        guard let credentials = response.credentials else {
            throw Abort(.internalServerError, reason: "Failed to generate credentials")
        }
        
        // Log token generation
        try await logSTSTokenGeneration(
            userId: userId,
            tier: user.subscriptionTier,
            on: req.db
        )
        
        return STSTokenResponse(
            credentials: .init(
                accessKeyId: credentials.accessKeyId,
                secretAccessKey: credentials.secretAccessKey,
                sessionToken: credentials.sessionToken,
                expiration: credentials.expiration
            ),
            region: "us-east-1",
            bucket: "photolala"
        )
    }
}

// Response models
struct STSTokenResponse: Content {
    let credentials: Credentials
    let region: String
    let bucket: String
    
    struct Credentials: Content {
        let accessKeyId: String
        let secretAccessKey: String
        let sessionToken: String
        let expiration: Date
    }
}

// Alternative: Using Hummingbird (lighter weight Swift server)
import Hummingbird
import HummingbirdAuth
import AWSSTS

extension HBApplication {
    func addSTSRoutes() {
        router.group()
            .add(middleware: JWTAuthenticator())
            .post("/api/v1/auth/sts-token") { request async throws -> STSTokenResponse in
                let user = try request.auth.require(User.self)
                
                // Same logic as Vapor example...
                // Create policy, call STS, return credentials
            }
    }
}
```

### 3. iOS/macOS App Implementation

```swift
// S3BackupService+Authentication.swift
import Foundation
import AWSS3

extension S3BackupService {
    /// Refresh AWS credentials using STS token from backend
    func refreshCredentials() async throws {
        guard let user = IdentityManager.shared.currentUser else {
            throw S3BackupError.notSignedIn
        }
        
        // Request fresh credentials from backend
        let request = URLRequest(url: URL(string: "\(API_BASE_URL)/api/v1/auth/sts-token")!)
        request.setValue("Bearer \(user.authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw S3BackupError.credentialsRefreshFailed
        }
        
        let stsResponse = try JSONDecoder().decode(STSTokenResponse.self, from: data)
        
        // Create new S3 client with temporary credentials
        let credentialIdentity = AWSCredentialIdentity(
            accessKey: stsResponse.credentials.accessKeyId,
            secret: stsResponse.credentials.secretAccessKey,
            sessionToken: stsResponse.credentials.sessionToken,
            expiration: stsResponse.credentials.expiration
        )
        
        let credentialIdentityResolver = StaticAWSCredentialIdentityResolver(
            credentialIdentity
        )
        
        let configuration = try await S3Client.S3ClientConfiguration(
            awsCredentialIdentityResolver: credentialIdentityResolver,
            region: stsResponse.region
        )
        
        self.client = S3Client(config: configuration)
        self.credentialsExpiration = stsResponse.credentials.expiration
        
        // Store bucket name
        self.bucketName = stsResponse.bucket
    }
    
    /// Ensure credentials are valid before S3 operations
    func ensureValidCredentials() async throws {
        if let expiration = credentialsExpiration {
            let now = Date()
            let buffer = TimeInterval(300) // 5 minute buffer
            
            if now.addingTimeInterval(buffer) >= expiration {
                try await refreshCredentials()
            }
        } else {
            // No credentials yet
            try await refreshCredentials()
        }
    }
    
    /// Wrapper for S3 operations with automatic credential refresh
    func performS3Operation<T>(_ operation: () async throws -> T) async throws -> T {
        try await ensureValidCredentials()
        
        do {
            return try await operation()
        } catch {
            // If we get a 403, try refreshing credentials once
            if let awsError = error as? AWSServiceError,
               awsError.statusCode == 403 {
                try await refreshCredentials()
                return try await operation()
            }
            throw error
        }
    }
}

// Models
struct STSTokenResponse: Codable {
    let credentials: STSCredentials
    let region: String
    let bucket: String
}

struct STSCredentials: Codable {
    let accessKeyId: String
    let secretAccessKey: String
    let sessionToken: String
    let expiration: Date
}
```

### 4. Usage in Upload/Download

```swift
// Example: Upload photo with automatic credential management
func uploadPhoto(_ photoRef: PhotoReference) async throws {
    try await performS3Operation {
        let data = try Data(contentsOf: photoRef.fileURL)
        let md5 = data.md5Digest.hexadecimalString
        let key = "photos/\(userId)/\(md5).dat"
        
        let putObjectInput = PutObjectInput(
            body: .data(data),
            bucket: self.bucketName,
            key: key
        )
        
        _ = try await self.client.putObject(input: putObjectInput)
    }
}
```

## Security Considerations

### 1. Token Expiration
- Tokens expire after 1 hour (configurable up to 12 hours)
- App automatically refreshes before expiration
- Users must re-authenticate if app is offline too long

### 2. Scope Limitations
- Each token is scoped to ONE user's data only
- Cannot access other users' photos even if they guess the path
- Cannot modify bucket policies or lifecycle rules

### 3. Audit Trail
- All STS token generations are logged
- Can track which user accessed what and when
- CloudTrail logs all S3 operations with session tags

### 4. Revocation
- Can immediately revoke access by disabling user in backend
- No need to rotate AWS credentials
- Can add IP restrictions or time-based access

## Cost Implications

### STS Costs
- **Free**: No charge for STS API calls
- **Free**: No charge for temporary credentials

### Benefits
- **No proxy costs**: Direct S3 upload/download saves bandwidth
- **No compute costs**: No Lambda or EC2 for proxying
- **Efficient**: Client-side compression and optimization

## Migration from POC

### Current POC State
```swift
// Static credentials in Keychain
let credentials = KeychainManager.shared.loadAWSCredentials()
```

### Migration Steps
1. Keep POC code for testing
2. Add credential refresh logic
3. Add backend token endpoint
4. Switch to STS in production
5. Remove static credentials

### Backward Compatibility
```swift
init() async throws {
    if let staticCreds = try? KeychainManager.shared.loadAWSCredentials() {
        // Development/POC mode
        self.init(accessKey: staticCreds.accessKey, secretKey: staticCreds.secretKey)
    } else {
        // Production mode - use STS
        try await refreshCredentials()
    }
}
```

## Testing

### Unit Tests
- Mock STS responses
- Test credential expiration handling
- Test 403 retry logic

### Integration Tests
- Test full flow with test backend
- Verify S3 access restrictions
- Test token expiration scenarios

### Load Tests
- Simulate thousands of concurrent token requests
- Measure S3 upload performance
- Test credential refresh under load

## Monitoring

### Metrics to Track
1. STS token generation rate
2. Token refresh frequency
3. 403 error rate (permission denied)
4. Credential expiration misses

### Alerts
- High 403 rate (possible policy issues)
- STS API errors
- Unusual token generation patterns

## Future Enhancements

### 1. Federated Identity
- Direct Sign in with Apple → AWS federation
- Skip backend token service
- Even more scalable

### 2. Fine-Grained Permissions
- Read-only access for shared albums
- Time-limited upload windows
- Geo-restricted access

### 3. Caching
- Cache tokens in Keychain
- Reduce backend calls
- Offline resilience

## Conclusion

STS token vending provides the ideal balance of security, scalability, and simplicity for Photolala's S3 backup service. It enables direct S3 access for millions of users without the complexity of managing individual IAM users or the bottleneck of proxying all traffic through backend servers.
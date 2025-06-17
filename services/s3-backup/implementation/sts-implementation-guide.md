# STS Implementation Guide

A practical guide to implementing AWS STS token vending for Photolala.

## Quick Start

### What We're Building

```
User opens app → Signs in with Apple → Gets temporary AWS credentials → Uploads directly to S3
```

Each user can only access their own folders:
- `photos/{userId}/*`
- `thumbnails/{userId}/*`
- `metadata/{userId}/*`

## Step 1: AWS Setup (One Time)

### Create IAM Role

```bash
# 1. Create the role
aws iam create-role --role-name PhotolalaUserAccessRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }]
  }' \
  --max-session-duration 43200

# 2. Note the Role ARN returned - you'll need it
# Example: arn:aws:iam::123456789012:role/PhotolalaUserAccessRole
```

### Create Backend User

```bash
# Create an IAM user for your backend service
aws iam create-user --user-name photolala-backend

# Attach policy to allow assuming the role
aws iam put-user-policy --user-name photolala-backend \
  --policy-name AssumePhotolaUserRole \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::YOUR_ACCOUNT_ID:role/PhotolalaUserAccessRole"
    }]
  }'

# Create access key for backend
aws iam create-access-key --user-name photolala-backend
# Save these credentials for your backend!
```

## Step 2: Backend Endpoint

### Swift/Vapor Example (Recommended)

```swift
// Package.swift dependencies
dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    .package(url: "https://github.com/soto-project/soto.git", from: "6.0.0"),
],
targets: [
    .target(
        name: "App",
        dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "SotoSTS", package: "soto"),
        ]
    )
]

// Sources/App/Controllers/STSController.swift
import Vapor
import SotoSTS

struct STSController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserAuthenticator())
        protected.post("api", "v1", "auth", "sts-token", use: getSTSToken)
    }
    
    func getSTSToken(req: Request) async throws -> STSTokenResponse {
        // Get authenticated user
        let user = try req.auth.require(User.self)
        
        // Validate subscription
        guard user.hasActiveSubscription else {
            throw Abort(.forbidden, reason: "Active subscription required")
        }
        
        let userId = user.serviceUserId
        
        // Create STS client
        let sts = AWSClient(
            credentialProvider: .static(
                accessKeyId: Environment.get("AWS_ACCESS_KEY_ID")!,
                secretAccessKey: Environment.get("AWS_SECRET_ACCESS_KEY")!
            ),
            httpClientProvider: .createNew
        ).sts
        
        // Create user-scoped policy
        let policy = """
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
                    "Resource": [
                        "arn:aws:s3:::photolala/photos/\(userId)/*",
                        "arn:aws:s3:::photolala/thumbnails/\(userId)/*",
                        "arn:aws:s3:::photolala/metadata/\(userId)/*"
                    ]
                },
                {
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
        
        // Get temporary credentials
        let request = STS.AssumeRoleRequest(
            roleArn: Environment.get("PHOTOLALA_ROLE_ARN")!,
            roleSessionName: "photolala-\(userId)",
            durationSeconds: 3600,
            policy: policy
        )
        
        let response = try await sts.assumeRole(request)
        
        return STSTokenResponse(
            credentials: .init(
                accessKeyId: response.credentials!.accessKeyId,
                secretAccessKey: response.credentials!.secretAccessKey,
                sessionToken: response.credentials!.sessionToken!,
                expiration: response.credentials!.expiration!
            ),
            region: "us-east-1",
            bucket: "photolala"
        )
    }
}

// Models
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
```

### Alternative: Node.js Example

```javascript
// If you prefer Node.js for faster iteration
const AWS = require('aws-sdk');
const sts = new AWS.STS();

async function getSTSToken(req, res) {
  const userId = req.user.id;
  
  const policy = {
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        Resource: [
          `arn:aws:s3:::photolala/photos/${userId}/*`,
          `arn:aws:s3:::photolala/thumbnails/${userId}/*`,
          `arn:aws:s3:::photolala/metadata/${userId}/*`
        ]
      },
      {
        Effect: "Allow",
        Action: "s3:ListBucket",
        Resource: "arn:aws:s3:::photolala",
        Condition: {
          StringLike: {
            "s3:prefix": [
              `photos/${userId}/*`,
              `thumbnails/${userId}/*`,
              `metadata/${userId}/*`
            ]
          }
        }
      }
    ]
  };
  
  try {
    const data = await sts.assumeRole({
      RoleArn: process.env.PHOTOLALA_ROLE_ARN,
      RoleSessionName: `photolala-${userId}`,
      Policy: JSON.stringify(policy),
      DurationSeconds: 3600
    }).promise();
    
    res.json({
      credentials: {
        accessKeyId: data.Credentials.AccessKeyId,
        secretAccessKey: data.Credentials.SecretAccessKey,
        sessionToken: data.Credentials.SessionToken,
        expiration: data.Credentials.Expiration
      },
      bucket: 'photolala',
      region: 'us-east-1'
    });
  } catch (error) {
    console.error('STS Error:', error);
    res.status(500).json({ error: 'Failed to generate credentials' });
  }
}
```

## Step 3: iOS/macOS Implementation

### Add to S3BackupService

```swift
// S3BackupService+STS.swift
import Foundation
import AWSS3

extension S3BackupService {
    private struct STSResponse: Codable {
        let credentials: Credentials
        let bucket: String
        let region: String
        
        struct Credentials: Codable {
            let accessKeyId: String
            let secretAccessKey: String
            let sessionToken: String
            let expiration: String
        }
    }
    
    /// Initialize service with STS tokens
    func initializeWithSTS() async throws {
        // Get STS token from backend
        guard let user = IdentityManager.shared.currentUser else {
            throw S3BackupError.notSignedIn
        }
        
        var request = URLRequest(url: URL(string: "\(API_BASE)/api/v1/auth/sts-token")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(user.authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(STSResponse.self, from: data)
        
        // Create S3 client with temporary credentials
        let credentialIdentity = AWSCredentialIdentity(
            accessKey: response.credentials.accessKeyId,
            secret: response.credentials.secretAccessKey,
            sessionToken: response.credentials.sessionToken
        )
        
        let resolver = StaticAWSCredentialIdentityResolver(credentialIdentity)
        
        let config = try await S3Client.S3ClientConfiguration(
            awsCredentialIdentityResolver: resolver,
            region: response.region
        )
        
        self.client = S3Client(config: config)
        self.bucketName = response.bucket
        
        // Schedule refresh before expiration
        if let expDate = ISO8601DateFormatter().date(from: response.credentials.expiration) {
            let refreshTime = expDate.addingTimeInterval(-300) // 5 min before expiry
            Task {
                try await Task.sleep(until: refreshTime)
                try await self.initializeWithSTS() // Refresh
            }
        }
    }
}
```

### Update Initialization

```swift
// PhotolalaApp.swift or S3BackupManager.swift
class S3BackupManager: ObservableObject {
    private func initializeService() async {
        do {
            // Try STS first (production)
            if IdentityManager.shared.isSignedIn {
                self.s3Service = S3BackupService()
                try await self.s3Service?.initializeWithSTS()
                self.isConfigured = true
                return
            }
            
            // Fall back to static credentials (development)
            if KeychainManager.shared.hasAWSCredentials() {
                self.s3Service = try await S3BackupService()
                self.isConfigured = true
                return
            }
            
            self.isConfigured = false
        } catch {
            print("Failed to initialize S3: \(error)")
            self.isConfigured = false
        }
    }
}
```

## Step 4: Testing

### Test STS Token Generation

```bash
# Test your backend endpoint
curl -X POST https://your-api.com/api/v1/auth/sts-token \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -H "Content-Type: application/json"

# Should return:
# {
#   "credentials": {
#     "accessKeyId": "ASIA...",
#     "secretAccessKey": "...",
#     "sessionToken": "...",
#     "expiration": "2024-01-01T12:00:00Z"
#   },
#   "bucket": "photolala",
#   "region": "us-east-1"
# }
```

### Test S3 Access

```swift
// Test upload with STS credentials
func testSTSUpload() async throws {
    // Initialize with STS
    try await s3Service.initializeWithSTS()
    
    // Try to upload to user's folder - should work
    let testData = "Hello World".data(using: .utf8)!
    let md5 = testData.md5Digest.hexadecimalString
    try await s3Service.uploadPhoto(data: testData, userId: currentUserId)
    print("✅ Upload to own folder succeeded")
    
    // Try to upload to another user's folder - should fail with 403
    do {
        try await s3Service.uploadPhoto(data: testData, userId: "other-user-id")
        print("❌ SECURITY ISSUE: Upload to other user succeeded!")
    } catch {
        print("✅ Upload to other user correctly failed: \(error)")
    }
}
```

## Common Issues

### 1. "Invalid session token"
```swift
// Solution: Token might be expired, refresh it
try await initializeWithSTS()
```

### 2. "Access Denied" (403)
```swift
// Check the policy in your backend - make sure paths match
// Wrong: "users/{userId}/photos/*"  (old structure)
// Right: "photos/{userId}/*"        (new structure)
```

### 3. "The security token included in the request is expired"
```swift
// Implement automatic refresh
class S3BackupService {
    private var tokenExpiration: Date?
    
    func ensureValidToken() async throws {
        if let expiration = tokenExpiration,
           Date().addingTimeInterval(300) > expiration {
            try await initializeWithSTS()
        }
    }
}
```

## Production Checklist

- [ ] AWS IAM role created
- [ ] Backend IAM user created with AssumeRole permission
- [ ] Backend endpoint implemented and tested
- [ ] iOS/macOS app updated to use STS
- [ ] Token refresh logic implemented
- [ ] Error handling for expired tokens
- [ ] Monitoring for STS API calls
- [ ] Load tested token generation endpoint
- [ ] Security review of IAM policies
- [ ] Documentation updated

## Security Best Practices

1. **Never** include permanent credentials in the app
2. **Always** validate user authentication before generating STS tokens
3. **Use** the minimum necessary permissions in policies
4. **Monitor** unusual token generation patterns
5. **Implement** rate limiting on token endpoint
6. **Log** all token generations for audit
7. **Set** appropriate token expiration (1-12 hours)
8. **Test** that users cannot access other users' data

## Cost

- **STS API Calls**: FREE
- **S3 Operations**: Standard S3 pricing
- **Data Transfer**: Direct to S3 (no proxy costs)

## Next Steps

1. Implement token caching to reduce API calls
2. Add CloudWatch metrics for monitoring
3. Consider AWS Cognito for direct federation
4. Implement IP-based restrictions for extra security
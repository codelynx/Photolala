# Apple ID to STS Token Flow

## The Complete Flow (No Traditional Login)

### 1. First App Launch
```
User opens Photolala
       ↓
iOS: "Sign in with Apple" button
       ↓
User taps (Face ID/Touch ID)
       ↓
Apple returns token
       ↓
Photolala backend validates
       ↓
Backend returns STS credentials
       ↓
App can access S3
```

## Detailed Implementation

### Step 1: iOS App - Sign in with Apple
```swift
import AuthenticationServices
import AWSS3

class AuthManager {
    private var currentUserID: String?
    private var stsCredentials: STSCredentials?
    
    // Called on app launch
    func authenticateUser() async throws {
        // 1. Sign in with Apple
        let appleIDCredential = try await signInWithApple()
        
        // 2. Send Apple token to our backend
        let photolalaAuth = try await exchangeAppleTokenForPhotolalaAuth(
            appleToken: appleIDCredential.identityToken,
            appleUserID: appleIDCredential.user
        )
        
        // 3. Store our user ID
        self.currentUserID = photolalaAuth.userId
        
        // 4. Get STS credentials
        self.stsCredentials = photolalaAuth.stsCredentials
    }
    
    private func signInWithApple() async throws -> ASAuthorizationAppleIDCredential {
        // This shows Apple's sign in UI
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        
        // ... perform authorization ...
        return credential
    }
}
```

### Step 2: Backend - Validate Apple Token & Generate STS
```python
from jose import jwt
import boto3

@app.post("/api/auth/apple-to-sts")
async def apple_to_sts(request: AppleAuthRequest):
    # 1. Validate Apple's identity token
    apple_claims = validate_apple_token(request.identity_token)
    
    # 2. Get or create Photolala user
    apple_user_id = apple_claims['sub']  # "001234.567890.abcdef"
    
    # Check if existing user
    user = db.query(
        "SELECT user_id FROM users WHERE apple_user_id = ?",
        apple_user_id
    ).first()
    
    if not user:
        # Create new user with our UUID
        user_id = str(uuid.uuid4())  # "550e8400-e29b-41d4..."
        db.execute(
            "INSERT INTO users (user_id, apple_user_id) VALUES (?, ?)",
            user_id, apple_user_id
        )
    else:
        user_id = user.user_id
    
    # 3. Generate STS credentials for THIS user only
    sts_creds = generate_user_sts_token(user_id)
    
    return {
        "user_id": user_id,
        "sts_credentials": sts_creds,
        "photolala_token": generate_jwt(user_id)  # For API calls
    }

def generate_user_sts_token(user_id: str):
    # Create IAM policy that ONLY allows access to this user's folder
    policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
            "Resource": f"arn:aws:s3:::photolala/users/{user_id}/*"
        }]
    }
    
    # Generate temporary credentials (1 hour)
    sts = boto3.client('sts')
    response = sts.assume_role(
        RoleArn='arn:aws:iam::123456789:role/PhotolalaUsers',
        RoleSessionName=f'user-{user_id}',
        Policy=json.dumps(policy),
        DurationSeconds=3600
    )
    
    return {
        "access_key": response['Credentials']['AccessKeyId'],
        "secret_key": response['Credentials']['SecretAccessKey'],
        "session_token": response['Credentials']['SessionToken'],
        "expiration": response['Credentials']['Expiration'],
        "user_prefix": f"users/{user_id}/"
    }
```

### Step 3: iOS App - Use STS Credentials
```swift
class S3Manager {
    private var s3Client: S3Client?
    private var userPrefix: String
    
    func configure(with credentials: STSCredentials) {
        // Configure AWS SDK with user-specific credentials
        let credProvider = STSCredentialsProvider(
            accessKey: credentials.accessKey,
            secretKey: credentials.secretKey,
            sessionToken: credentials.sessionToken
        )
        
        self.s3Client = S3Client(
            region: "us-east-1",
            credentialsProvider: credProvider
        )
        
        self.userPrefix = credentials.userPrefix  // "users/550e8400.../"
    }
    
    func uploadPhoto(data: Data, md5: String) async throws {
        // This works - within user's folder
        let key = "\(userPrefix)photos/\(md5).dat"
        try await s3Client.putObject(
            bucket: "photolala",
            key: key,
            body: data
        )
        
        // This would fail - outside user's folder
        // let badKey = "users/other-user/photos/\(md5).dat"
        // 403 Forbidden
    }
}
```

## The Complete Picture

### First Time User Flow
```
1. User opens app
   ↓
2. Taps "Sign in with Apple"
   ↓
3. Apple: Returns token with ID "001234.567890"
   ↓
4. Backend: "I haven't seen 001234.567890 before"
   - Creates new user: "550e8400-e29b-41d4..."
   - Generates STS token for "users/550e8400.../*"
   ↓
5. App: Can now upload to S3 directly
```

### Returning User Flow
```
1. User opens app
   ↓
2. iOS: Auto sign-in with stored Apple credentials
   ↓
3. Apple: Returns same ID "001234.567890"
   ↓
4. Backend: "I know this user! It's 550e8400..."
   - Generates fresh STS token for "users/550e8400.../*"
   ↓
5. App: Continues where they left off
```

## Token Refresh Flow
```swift
class TokenManager {
    private var stsExpiration: Date?
    
    func getValidS3Client() async throws -> S3Client {
        // Check if token expired
        if let expiration = stsExpiration,
           Date() > expiration.addingTimeInterval(-300) {  // 5 min buffer
            
            // Refresh using stored Apple credentials
            let newCredentials = try await refreshSTSToken()
            s3Manager.configure(with: newCredentials)
        }
        
        return s3Manager.client
    }
    
    private func refreshSTSToken() async throws -> STSCredentials {
        // Use existing Photolala token to refresh
        return try await api.refreshSTSCredentials()
    }
}
```

## Why This Is Secure

1. **Apple Validates User**
   - Face ID/Touch ID required
   - Apple ensures it's the real user

2. **Backend Maps to Our User**
   - Apple ID → Photolala User ID
   - Consistent mapping

3. **STS Locks to User Folder**
   - Token ONLY works for `users/{user-id}/*`
   - Cannot access other folders

4. **Time Limited**
   - STS tokens expire in 1 hour
   - Must refresh regularly

## No Password Needed!

The beauty of Sign in with Apple:
- User never creates a password
- Apple handles authentication
- We just verify Apple's token
- STS provides the S3 access

This is actually MORE secure than passwords!
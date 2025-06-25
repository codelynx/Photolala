# Security & Privacy Architecture

## Apple ID Integration

### Overview
We need to securely associate Apple IDs with Photolala user accounts without storing sensitive Apple data.

### Apple Sign In Flow

#### 1. Initial Authentication
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Photolala     │────▶│   Apple Sign    │────▶│  Photolala API  │
│      App        │     │    In SDK       │     │    Backend      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                         │
        │ 1. Request           │ 2. Apple ID            │ 3. Create
        │    Sign In           │    Token               │    User
        │                       │                         │
        ▼                       ▼                         ▼
   User taps              Apple handles            Backend creates
   "Sign in with          authentication           unique user_id
   Apple"                 returns JWT              stores mapping
```

#### 2. Data Structure
```swift
// What Apple provides
struct AppleIDCredential {
    let userIdentifier: String     // Unique, stable, opaque
    let email: String?              // Optional, may be hidden
    let fullName: PersonNameComponents? // First time only
    let identityToken: Data         // JWT for verification
    let authorizationCode: Data     // For server validation
}

// What we store
struct PhotolalaUser {
    let userId: UUID                // Our internal ID
    let appleUserId: String        // Apple's userIdentifier
    let createdAt: Date
    let lastLoginAt: Date
    // Never store email or name unless user explicitly provides
}
```

### Backend Architecture

#### API Endpoints
```
POST /api/auth/apple
{
    "identityToken": "eyJhbGc...",
    "authorizationCode": "c424b67...",
    "userIdentifier": "001234.5678..."
}

Response:
{
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "accessToken": "plt_eyJhbGc...",
    "refreshToken": "plr_eyJhbGc...",
    "storageQuota": 200000000000,
    "creditsBalance": 50
}
```

#### Database Schema
```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apple_user_id VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP,
    subscription_tier VARCHAR(50),
    storage_used BIGINT DEFAULT 0,
    credits_balance INTEGER DEFAULT 0
);

-- Apple ID mapping (separate for security)
CREATE TABLE apple_id_mapping (
    apple_user_id VARCHAR(255) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    first_login_at TIMESTAMP NOT NULL,
    last_token_refresh TIMESTAMP
);

-- Never store email, name, or other PII
```

### Security Implementation

#### 1. Token Validation
```python
# Backend validation of Apple identity token
import jwt
import requests

def validate_apple_token(identity_token):
    # Fetch Apple's public keys
    apple_keys = requests.get(
        "https://appleid.apple.com/auth/keys"
    ).json()
    
    # Decode and verify JWT
    try:
        decoded = jwt.decode(
            identity_token,
            apple_keys,
            algorithms=["RS256"],
            audience="com.photolala.app",
            issuer="https://appleid.apple.com"
        )
        return decoded
    except:
        raise InvalidTokenError()
```

#### 2. User ID Generation
```python
def create_or_get_user(apple_user_id):
    # Check if user exists
    user = db.query(
        "SELECT user_id FROM apple_id_mapping WHERE apple_user_id = ?",
        apple_user_id
    )
    
    if user:
        return user.user_id
    
    # Create new user
    user_id = generate_uuid()
    db.execute("""
        INSERT INTO users (id, apple_user_id) 
        VALUES (?, ?)
    """, user_id, apple_user_id)
    
    db.execute("""
        INSERT INTO apple_id_mapping (apple_user_id, user_id)
        VALUES (?, ?)
    """, apple_user_id, user_id)
    
    return user_id
```

### S3 Structure with User IDs

#### Bucket Organization
```
s3://photolala/
├── users/
│   └── {user_id}/              # Our UUID, not Apple ID
│       ├── photos/
│       │   └── {md5}.dat
│       ├── thumbs/
│       │   └── {md5}.dat
│       ├── metadata/
│       │   └── {md5}.plist
│       └── catalogs/
│           └── 2024-01.plist
```

#### IAM Policy per User
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::photolala/users/${userId}/*"
            ]
        }
    ]
}
```

### Privacy Considerations

#### What We Store
✅ **Minimal Data**:
- Apple's opaque user identifier
- Our generated user ID
- Subscription status
- Storage metrics
- Login timestamps

❌ **What We Don't Store**:
- Email addresses (unless explicitly provided)
- Real names
- Apple ID email
- Device information
- Location data (except EXIF in photos)

#### GDPR/Privacy Compliance
```
Data Retention:
- Active users: Indefinite (service requirement)
- Cancelled users: 365 days (as per policy)
- Deleted accounts: 30 days (soft delete)

User Rights:
- Export all data: Via Recovery Pass
- Delete account: Self-service option
- View stored data: Privacy dashboard
- Correct data: Limited (mostly automated)
```

### Multi-Device Sync

#### Device Registration
```swift
// Each device gets a unique token
struct DeviceRegistration {
    let deviceId: UUID
    let userId: UUID
    let deviceName: String  // "John's iPhone"
    let registeredAt: Date
    let lastSyncAt: Date
}

// But all devices share same user_id
// No need to sync Apple ID across devices
```

### Implementation Security

#### 1. API Authentication
```
Client ────────────────────────▶ Backend
  │                                 │
  │ Authorization: Bearer plt_...   │
  │ X-Device-ID: 550e8400-...      │
  │                                 │
  └─────────────────────────────────┘

Backend validates:
1. Token signature
2. Token expiration  
3. User exists
4. Device registered
```

#### 2. Encryption Strategy
```
In Transit:
- TLS 1.3 minimum
- Certificate pinning on mobile
- Forward secrecy

At Rest:
- S3 SSE-S3 (AWS managed)
- No client-side encryption (Phase 1)
- Metadata encrypted

Future:
- Client-side encryption option
- User-managed keys
- Zero-knowledge architecture
```

### Session Management

#### Token Lifecycle
```
1. Sign in with Apple
   └─▶ Identity token (1 hour)
   
2. Exchange for Photolala tokens
   ├─▶ Access token (1 hour)
   └─▶ Refresh token (30 days)
   
3. Auto-refresh before expiry
   └─▶ New access token

4. Re-authenticate monthly
   └─▶ Ensures Apple ID still valid
```

#### Revocation Handling
```python
# Check with Apple if user revoked access
def verify_apple_access():
    response = requests.post(
        "https://appleid.apple.com/auth/token",
        data={
            "client_id": "com.photolala.app",
            "client_secret": generate_client_secret(),
            "grant_type": "refresh_token",
            "refresh_token": user.apple_refresh_token
        }
    )
    
    if response.status_code == 400:
        # User revoked access
        mark_user_as_inactive(user.id)
```

### Account Recovery

#### Scenarios
1. **Lost Device**: Sign in with Apple on new device
2. **Apple ID Changed**: Not supported (new account)
3. **Photolala Account Issues**: Apple ID proves ownership

#### Recovery Flow
```
User: "I can't access my photos"
     │
     ▼
Sign in with Apple
     │
     ▼
System finds existing user_id
     │
     ▼
Restore access to same photos
```

### Best Practices

1. **Never Log Apple IDs**
   - Use our user_id in all logs
   - Apple ID only in secure auth table

2. **Minimize Apple Dependencies**
   - Cache user state locally
   - Graceful degradation if Apple is down

3. **Privacy by Default**
   - No email collection unless needed
   - No tracking across Apple IDs
   - Clear data deletion options

4. **Security Auditing**
   - Log all authentication attempts
   - Monitor for suspicious patterns
   - Rate limit by IP and user_id
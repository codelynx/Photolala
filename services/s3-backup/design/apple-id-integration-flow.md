# Apple ID Integration - Simple Flow

## How Apple ID Maps to Photolala User

### First Time User
```
1. User taps "Sign in with Apple"
   ↓
2. Apple returns:
   - userIdentifier: "001234.567890.abcdef"  (stable, opaque)
   - Email: hidden or user@privaterelay.apple.com
   - Name: Optional (first time only)
   ↓
3. Photolala Backend:
   - Receives Apple userIdentifier
   - Generates UUID: "550e8400-e29b-41d4-a716-446655440000"
   - Creates mapping: Apple ID ←→ Photolala UUID
   ↓
4. S3 Storage uses Photolala UUID:
   s3://photolala/users/550e8400-e29b-41d4-a716-446655440000/
```

### Returning User
```
1. User signs in with Apple again
   ↓
2. Apple returns same userIdentifier: "001234.567890.abcdef"
   ↓
3. Backend looks up mapping:
   "001234.567890.abcdef" → "550e8400-e29b-41d4-a716-446655440000"
   ↓
4. User accesses their existing photos
```

## Key Security Points

### What Apple Provides
```swift
// This is what we get from Apple
let appleUserID = "001234.567890.abcdef"  // Stable, unique per app
// This NEVER changes for the same Apple ID + App combination
```

### What We Create
```swift
// Our internal user ID (UUID v4)
let photolalaUserID = "550e8400-e29b-41d4-a716-446655440000"
// This is what we use everywhere in our system
```

### Database Mapping
```sql
-- Simple mapping table
apple_id_mapping:
| apple_user_id              | photolala_user_id                    |
|---------------------------|--------------------------------------|
| 001234.567890.abcdef      | 550e8400-e29b-41d4-a716-446655440000 |
| 002345.678901.bcdefg      | 660f9501-f39c-52e5-b827-557766551111 |
```

## Privacy Benefits

1. **Apple Never Sees**:
   - What photos users store
   - How much storage they use
   - Their Photolala user ID

2. **We Never Store**:
   - User's real Apple ID email
   - User's real name (unless they tell us)
   - Any other Apple account info

3. **S3 Paths Use Our UUID**:
   - Even if S3 was compromised
   - Can't trace back to Apple IDs
   - Additional layer of privacy

## Implementation Code

### iOS App
```swift
// Sign in with Apple
func signInWithApple() {
    let request = ASAuthorizationAppleIDProvider().createRequest()
    request.requestedScopes = [] // Don't request email/name
    
    // ... perform request ...
    
    // On success
    let appleUserID = credential.user
    sendToBackend(appleUserID: appleUserID)
}
```

### Backend API
```python
@app.post("/auth/apple")
async def auth_apple(apple_user_id: str, identity_token: str):
    # Verify token with Apple
    if not verify_apple_token(identity_token):
        raise AuthError()
    
    # Check if existing user
    user = db.get_user_by_apple_id(apple_user_id)
    
    if not user:
        # Create new user
        user = User(
            id=generate_uuid(),
            apple_user_id=apple_user_id,
            created_at=now()
        )
        db.save_user(user)
    
    # Return our token
    return {
        "user_id": user.id,
        "access_token": generate_token(user.id),
        "is_new_user": user.created_at == now()
    }
```

### S3 Access
```python
def get_user_s3_prefix(user_id: str) -> str:
    # Always use our UUID, never Apple ID
    return f"users/{user_id}/"

# Example usage
user_prefix = get_user_s3_prefix("550e8400-e29b-41d4-a716-446655440000")
# Result: "users/550e8400-e29b-41d4-a716-446655440000/"
```

## Security Considerations

### Token Management
```
Apple Identity Token (1 hour) 
    ↓
Photolala Access Token (1 hour)
    ↓
Photolala Refresh Token (30 days)
    ↓
Periodic re-authentication with Apple
```

### Attack Scenarios Protected Against

1. **S3 Bucket Enumeration**:
   - Attacker sees: `users/550e8400-.../photos/`
   - Can't determine whose photos these are

2. **Database Breach**:
   - Mapping table has Apple's opaque IDs
   - Not useful without Apple's private keys

3. **API Token Theft**:
   - Tokens expire in 1 hour
   - Refresh requires valid session
   - Can revoke all tokens if needed

4. **Apple ID Changes**:
   - User signs in with different Apple ID
   - Gets completely new Photolala account
   - Old account remains separate

## Benefits of This Approach

1. **Simple**: One Apple ID = One Photolala ID
2. **Secure**: Multiple layers of separation
3. **Private**: Minimal data collection
4. **Reliable**: Apple handles authentication
5. **Recoverable**: Apple ID proves ownership
# Access Control Architecture

## The Problem

If the app has direct S3 access via AWS SDK:
- A hacked app could access ANY user's photos
- Client-side access control is just "security by obscurity"
- We need server-enforced boundaries

## Solution: API Gateway + STS (Recommended)

### Architecture Overview
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   iOS App   │────▶│ Photolala   │────▶│  AWS STS    │────▶│   AWS S3    │
│             │     │   API       │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
      │                    │                    │                    │
      │ 1. Request         │ 2. Validate       │ 3. Generate       │ 4. Scoped
      │    S3 access       │    user           │    temp creds     │    access
      │                    │                    │    for user       │    only
```

### Detailed Flow

#### 1. App Requests S3 Access
```swift
// iOS App
func requestS3Access() async -> S3Credentials? {
    let response = await api.post("/api/s3/access", 
        headers: ["Authorization": "Bearer \(userToken)"]
    )
    return response.credentials
}
```

#### 2. Backend Validates & Creates STS Token
```python
# Photolala API
@app.post("/api/s3/access")
async def get_s3_access(user: User = Depends(get_current_user)):
    # Create IAM policy for THIS user only
    policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                f"arn:aws:s3:::photolala/users/{user.id}/*"
            ]
        }, {
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": "arn:aws:s3:::photolala",
            "Condition": {
                "StringLike": {
                    "s3:prefix": [f"users/{user.id}/*"]
                }
            }
        }]
    }
    
    # Generate temporary credentials (1 hour)
    sts = boto3.client('sts')
    response = sts.assume_role(
        RoleArn='arn:aws:iam::123456789012:role/PhotolalaUserRole',
        RoleSessionName=f'user-{user.id}',
        Policy=json.dumps(policy),
        DurationSeconds=3600
    )
    
    return {
        "access_key": response['Credentials']['AccessKeyId'],
        "secret_key": response['Credentials']['SecretAccessKey'],
        "session_token": response['Credentials']['SessionToken'],
        "expiration": response['Credentials']['Expiration'],
        "bucket": "photolala",
        "prefix": f"users/{user.id}/"
    }
```

#### 3. App Uses Temporary Credentials
```swift
// iOS App - These credentials ONLY work for this user's prefix
func setupS3Client(credentials: S3Credentials) {
    let credentialsProvider = AWSStaticCredentialsProvider(
        accessKey: credentials.accessKey,
        secretKey: credentials.secretKey,
        sessionToken: credentials.sessionToken
    )
    
    let config = S3ClientConfig(
        credentialsProvider: credentialsProvider,
        region: "us-east-1"
    )
    
    self.s3Client = S3Client(config: config)
    self.userPrefix = credentials.prefix // "users/{userId}/"
}

// This will work
try await s3Client.getObject(
    bucket: "photolala",
    key: "users/550e8400-e29b/photos/abc123.dat"
)

// This will FAIL (403 Forbidden)
try await s3Client.getObject(
    bucket: "photolala",
    key: "users/different-user/photos/xyz789.dat"
)
```

## Family/Group Sharing Architecture

### Database Schema
```sql
-- Sharing relationships
CREATE TABLE shares (
    id UUID PRIMARY KEY,
    owner_user_id UUID NOT NULL,
    shared_with_user_id UUID NOT NULL,
    folder_path VARCHAR(255),  -- "albums/vacation-2024"
    permission ENUM('read', 'write'),
    created_at TIMESTAMP,
    expires_at TIMESTAMP
);

-- Family groups
CREATE TABLE family_groups (
    id UUID PRIMARY KEY,
    name VARCHAR(255),
    created_by UUID NOT NULL,
    created_at TIMESTAMP
);

CREATE TABLE family_members (
    family_id UUID REFERENCES family_groups(id),
    user_id UUID REFERENCES users(id),
    role ENUM('organizer', 'adult', 'child'),
    joined_at TIMESTAMP,
    PRIMARY KEY (family_id, user_id)
);
```

### Shared Folder Structure
```
s3://photolala/
├── users/
│   └── {user-id}/          # Private photos
│       ├── photos/
│       └── shared/         # Symlinks to shared content
└── shared/
    └── {share-id}/         # Actual shared photos
        ├── photos/
        └── metadata.json   # Who can access
```

### STS Policy for Shared Access
```python
def generate_policy_with_shares(user_id: str, shares: List[Share]):
    statements = [
        # User's own photos
        {
            "Effect": "Allow",
            "Action": ["s3:*"],
            "Resource": [f"arn:aws:s3:::photolala/users/{user_id}/*"]
        }
    ]
    
    # Add shared folder access
    for share in shares:
        if share.permission == "read":
            statements.append({
                "Effect": "Allow",
                "Action": ["s3:GetObject", "s3:ListBucket"],
                "Resource": [f"arn:aws:s3:::photolala/shared/{share.id}/*"]
            })
        elif share.permission == "write":
            statements.append({
                "Effect": "Allow",
                "Action": ["s3:*"],
                "Resource": [f"arn:aws:s3:::photolala/shared/{share.id}/*"]
            })
    
    return {"Version": "2012-10-17", "Statement": statements}
```

## Alternative: Pure API Approach (No Direct S3)

### Architecture
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   iOS App   │────▶│ Photolala   │────▶│   AWS S3    │
│             │     │   API       │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
      │                    │                    │
      │ 1. Upload         │ 2. Validate       │ 3. Store
      │    via API        │    & proxy        │    
```

### API Endpoints
```python
# All S3 operations go through API
@app.post("/api/photos/upload")
async def upload_photo(
    file: UploadFile,
    user: User = Depends(get_current_user)
):
    # Calculate MD5
    md5 = calculate_md5(file)
    
    # Check user's quota
    if user.storage_used + file.size > user.storage_quota:
        raise QuotaExceededError()
    
    # Upload to S3 with user's prefix
    s3_key = f"users/{user.id}/photos/{md5}.dat"
    s3.upload_fileobj(file.file, "photolala", s3_key)
    
    # Update user's storage
    user.storage_used += file.size
    db.save(user)
    
    return {"md5": md5, "size": file.size}

@app.get("/api/photos/{md5}")
async def download_photo(
    md5: str,
    user: User = Depends(get_current_user)
):
    # Check if user owns this photo
    if not db.user_owns_photo(user.id, md5):
        # Check if shared with user
        if not db.photo_shared_with_user(user.id, md5):
            raise ForbiddenError()
    
    # Generate presigned URL (15 minutes)
    url = s3.generate_presigned_url(
        'get_object',
        Params={
            'Bucket': 'photolala',
            'Key': f'users/{user.id}/photos/{md5}.dat'
        },
        ExpiresIn=900
    )
    
    return {"download_url": url}
```

## Comparison of Approaches

### Option 1: STS with Temporary Credentials
**Pros:**
- Direct S3 upload/download (fast, efficient)
- Reduced API server load
- Native AWS SDK features
- Multipart uploads work well

**Cons:**
- Complex credential management
- App refresh tokens every hour
- Harder to implement quotas
- More complex client code

### Option 2: Pure API Proxy
**Pros:**
- Complete control over access
- Easy quota enforcement
- Simple client implementation
- Better audit trail

**Cons:**
- All data through API (bandwidth cost)
- API becomes bottleneck
- Harder to do multipart uploads
- More API server resources needed

## Recommended Hybrid Approach

### Use API for:
- Authentication and authorization
- Metadata operations
- Sharing management
- Quota enforcement

### Use STS + Direct S3 for:
- Large file uploads/downloads
- Bulk operations
- Better performance

### Implementation
```python
# API provides presigned URLs for large files
@app.post("/api/photos/upload/prepare")
async def prepare_upload(
    filename: str,
    size: int,
    md5: str,
    user: User = Depends(get_current_user)
):
    # Validate
    if user.storage_used + size > user.storage_quota:
        raise QuotaExceededError()
    
    # Generate presigned POST URL
    s3_key = f"users/{user.id}/photos/{md5}.dat"
    presigned = s3.generate_presigned_post(
        Bucket='photolala',
        Key=s3_key,
        Conditions=[
            ["content-length-range", size, size],
            {"x-amz-meta-md5": md5}
        ],
        ExpiresIn=3600
    )
    
    return {
        "upload_url": presigned['url'],
        "fields": presigned['fields']
    }

# After upload, confirm and update quota
@app.post("/api/photos/upload/complete")
async def complete_upload(
    md5: str,
    size: int,
    user: User = Depends(get_current_user)
):
    # Verify upload succeeded
    if not s3.head_object(Bucket='photolala', Key=f'users/{user.id}/photos/{md5}.dat'):
        raise UploadFailedError()
    
    # Update user quota
    user.storage_used += size
    db.save(user)
    
    return {"status": "success"}
```

## Security Best Practices

1. **Never embed AWS credentials in app**
2. **Always use temporary credentials**
3. **Implement server-side validation**
4. **Use presigned URLs for large files**
5. **Audit all access patterns**
6. **Implement rate limiting**
7. **Monitor for anomalies**

## Conclusion

For Photolala, I recommend:
1. **Hybrid approach** with API + Presigned URLs
2. **STS for power users** (future feature)
3. **Strong server-side validation**
4. **Comprehensive audit logging**

This provides security without sacrificing performance or user experience.
# Access Control - Simple Explanation

## The Security Problem

```
If app has direct S3 access:
User A's App → S3 → Can access User B's photos! ❌
                     (if app is hacked/modified)
```

## The Solution: Server Controls Access

```
User A's App → Photolala API → S3
     ↓              ↓           ↓
   Token A     Validates A   Only A's photos ✅
```

## Recommended Architecture: Presigned URLs

### How It Works

#### Upload Flow
```
1. App: "I want to upload photo.jpg (5MB)"
          ↓
2. API: "OK, here's a special upload URL"
        (only works for YOUR folder)
        (expires in 1 hour)
          ↓
3. App: Uploads directly to S3 using URL
          ↓
4. App: "Upload done!"
          ↓
5. API: Updates your storage quota
```

#### Download Flow
```
1. App: "I want to download photo ABC123"
          ↓
2. API: Checks if you own ABC123
          ↓
3. API: "Here's a download URL"
        (expires in 15 minutes)
          ↓
4. App: Downloads directly from S3
```

### Code Example

#### iOS App
```swift
// Upload
func uploadPhoto(image: UIImage) async {
    // 1. Prepare with API
    let response = await api.prepareUpload(
        size: imageData.count,
        md5: imageData.md5()
    )
    
    // 2. Upload directly to S3
    await uploadToS3(
        url: response.uploadUrl,
        data: imageData,
        fields: response.fields
    )
    
    // 3. Confirm with API
    await api.confirmUpload(md5: imageData.md5())
}

// Download
func downloadPhoto(md5: String) async -> UIImage? {
    // 1. Get URL from API
    let response = await api.getDownloadUrl(md5: md5)
    
    // 2. Download from S3
    let data = await downloadFromS3(url: response.url)
    
    return UIImage(data: data)
}
```

#### Backend API
```python
@app.post("/api/photos/upload/prepare")
async def prepare_upload(size: int, md5: str, user: User):
    # Check quota
    if user.storage_used + size > user.quota:
        raise QuotaExceededError()
    
    # Generate presigned POST URL
    # This URL ONLY works for this user's folder
    url = s3.generate_presigned_post(
        Bucket='photolala',
        Key=f'users/{user.id}/photos/{md5}.dat',
        ExpiresIn=3600  # 1 hour
    )
    
    return {"upload_url": url}

@app.get("/api/photos/{md5}/download")
async def get_download_url(md5: str, user: User):
    # Check ownership
    if not user_owns_photo(user.id, md5):
        raise ForbiddenError()
    
    # Generate presigned GET URL
    url = s3.generate_presigned_url(
        'get_object',
        Params={
            'Bucket': 'photolala',
            'Key': f'users/{user.id}/photos/{md5}.dat'
        },
        ExpiresIn=900  # 15 minutes
    )
    
    return {"url": url}
```

## Family Sharing

### Simple Sharing Model
```
users/
├── user-A/
│   └── photos/
│       └── abc123.dat (private)
├── user-B/
│   └── photos/
│       └── def456.dat (private)
└── shared/
    └── share-xyz789/
        └── photos/
            └── ghi789.dat (shared between A & B)
```

### How Sharing Works
```python
# When User A shares album with User B
@app.post("/api/shares/create")
async def create_share(
    album_id: str,
    share_with: str,  # User B's email
    user: User  # User A
):
    # Create share record
    share = Share(
        id=generate_uuid(),
        owner_id=user.id,
        shared_with_id=lookup_user(share_with),
        album_id=album_id
    )
    db.save(share)
    
    # Copy photos to shared location
    for photo in get_album_photos(album_id):
        s3.copy_object(
            CopySource=f'users/{user.id}/photos/{photo.md5}.dat',
            Bucket='photolala',
            Key=f'shared/{share.id}/photos/{photo.md5}.dat'
        )
    
    return {"share_id": share.id}
```

## Security Benefits

### What This Prevents
1. **Hacked app** can't access other users' data
2. **Token theft** only affects one user
3. **Quota bypass** impossible
4. **Unauthorized sharing** blocked

### What We Log
```json
{
    "timestamp": "2024-01-20T10:30:00Z",
    "user_id": "550e8400-...",
    "action": "download",
    "photo_md5": "abc123...",
    "ip_address": "192.168.1.1",
    "user_agent": "Photolala/1.0",
    "presigned_url_expires": "2024-01-20T10:45:00Z"
}
```

## Alternative: Direct S3 with STS (Advanced)

### When to Use
- Power users with lots of uploads
- Desktop app with better security
- Trusted environments

### How It Works
```
1. App requests temporary AWS credentials
2. API creates credentials that ONLY work for user's folder
3. App uses AWS SDK directly for 1 hour
4. Repeat when credentials expire
```

### Pros and Cons
✅ More efficient for bulk operations
✅ Native AWS SDK features
❌ More complex implementation
❌ Harder to track usage in real-time

## Recommendation

**Start with Presigned URLs** because:
1. Simpler to implement
2. Complete control over access
3. Easy quota management
4. Good enough for most users

**Add STS later** for:
1. Power users
2. Desktop apps
3. Bulk operations
4. API cost reduction
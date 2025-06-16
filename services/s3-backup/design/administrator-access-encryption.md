# Administrator Access & Encryption Strategy

## Current Design: Trust-Based Model

### What Administrators CAN See
With the current S3 SSE-S3 (Server-Side Encryption):

```
Administrator Access:
✅ Can view all photos (after S3 decrypts)
✅ Can see metadata and thumbnails
✅ Can access user storage stats
✅ Can restore deleted data
✅ Can help with account recovery
```

### How S3 SSE-S3 Works
```
Upload Flow:
User → HTTPS → Photolala API → S3 (encrypts at rest)

Download Flow:
S3 (decrypts) → Photolala API → HTTPS → User

Reality: AWS manages the encryption keys
Result: Photolala admins with S3 access can view data
```

## Option 1: Current Approach (Trust Model)

### Architecture
```
Encryption: S3 SSE-S3 (AWS-managed keys)
Admin Access: Yes, with proper controls
User Trust: Policy and legal agreements
```

### Administrative Controls
```python
# Audit all admin access
@require_admin_role
@audit_log
def admin_view_user_data(admin_id: str, user_id: str, reason: str):
    # Log access
    log_admin_access(
        admin_id=admin_id,
        user_id=user_id,
        action="view_photos",
        reason=reason,
        timestamp=now()
    )
    
    # Require reason codes
    valid_reasons = [
        "user_support_request",
        "legal_compliance",
        "abuse_investigation",
        "data_recovery"
    ]
    
    if reason not in valid_reasons:
        raise UnauthorizedAccessError()
```

### Policy Framework
```
Admin Access Policy:
1. Two-person rule for sensitive data
2. All access logged and audited
3. Quarterly access reviews
4. Background checks for admins
5. Legal agreements (NDAs)
```

## Option 2: Zero-Knowledge Encryption

### How It Would Work
```
Upload Flow:
1. User's device generates encryption key
2. Photo encrypted on device
3. Encrypted blob uploaded to S3
4. Key never leaves user's control

Download Flow:
1. Download encrypted blob
2. Decrypt on user's device
3. Photolala never sees plaintext
```

### Implementation
```swift
// Client-side encryption
func uploadPhoto(photo: Data) {
    // Generate key from user's password/biometric
    let key = deriveKey(from: userSecret)
    
    // Encrypt locally
    let encryptedPhoto = AES256.encrypt(photo, key: key)
    let encryptedThumb = AES256.encrypt(thumbnail, key: key)
    
    // Upload encrypted blobs
    api.upload(encryptedPhoto, to: "photos/\(md5).enc")
    api.upload(encryptedThumb, to: "thumbs/\(md5).enc")
}
```

### Pros and Cons of Zero-Knowledge

**Pros:**
- ❌ Admins cannot view photos
- ❌ Subpoenas get encrypted data
- ✅ Maximum privacy
- ✅ Marketing advantage

**Cons:**
- ❌ No password reset (lose key = lose photos)
- ❌ No web access (need key on device)
- ❌ No server-side features (face recognition, search)
- ❌ Complex implementation
- ❌ Poor user experience
- ❌ Can't help users recover data

## Option 3: Hybrid Approach (Recommended)

### Default: Trust Model with Controls
```
Standard Users:
- S3 SSE-S3 encryption
- Admin access possible but controlled
- Full features available
- Easy recovery options
```

### Optional: Client-Side Encryption
```
Privacy-Conscious Users:
- Opt-in client-side encryption
- "Privacy Mode" toggle
- Understand the tradeoffs
- No admin access possible
```

### Implementation
```swift
// User choice in settings
enum EncryptionMode {
    case standard     // S3 SSE-S3 (default)
    case private      // Client-side (opt-in)
}

// Different paths based on mode
if user.encryptionMode == .private {
    // Client encrypts before upload
    uploadEncrypted(photo)
} else {
    // Server-side encryption
    uploadStandard(photo)
}
```

## Practical Security Measures

### 1. Administrative Access Controls
```yaml
# AWS IAM Policy for Admins
AdminPolicy:
  Version: '2012-10-17'
  Statement:
    - Effect: Allow
      Action:
        - s3:ListBucket
      Resource: 'arn:aws:s3:::photolala'
      Condition:
        IpAddress:
          aws:SourceIp:
            - "10.0.0.0/8"  # Office VPN only
        MultiFactorAuthPresent: true
```

### 2. Access Logging
```sql
-- Admin access audit table
CREATE TABLE admin_access_log (
    id UUID PRIMARY KEY,
    admin_id UUID NOT NULL,
    user_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    ip_address INET,
    accessed_at TIMESTAMP NOT NULL,
    files_accessed TEXT[],
    approved_by UUID  -- Two-person rule
);

-- Alert on suspicious patterns
CREATE INDEX idx_admin_frequency ON admin_access_log(admin_id, accessed_at);
```

### 3. Technical Controls
```python
# Rate limiting admin access
@rate_limit(max_calls=10, period="hour")
def admin_download_photo(admin_id, user_id, photo_id):
    # Prevent bulk downloads
    pass

# Require business justification
def validate_access_reason(reason: str, user_id: str):
    # Check if user filed support ticket
    # Check if legal hold exists
    # Check if abuse report filed
    return has_valid_justification()
```

## Trust Transparency

### Public Commitments
```markdown
Photolala Privacy Promise:

1. **Limited Access**: Only authorized staff
2. **Always Logged**: Every access recorded
3. **Business Need**: Valid reason required
4. **You're Notified**: Alert on admin access (future)
5. **Regular Audits**: Quarterly reviews
6. **Legal Protection**: We fight invalid requests
```

### Transparency Report
```
Quarterly Transparency Report:

Admin Access Statistics:
- Support requests resolved: 145
- Legal requests received: 2
- Legal requests fought: 1
- Abuse investigations: 8
- Unauthorized access attempts: 0

Average response time: 2.3 hours
Customer satisfaction: 94%
```

## Recommendations

### Phase 1: Launch with Trust Model
1. **S3 SSE-S3** encryption (AWS-managed)
2. **Strong admin controls** and logging
3. **Clear privacy policy**
4. **Transparent practices**

### Phase 2: Add Privacy Options
1. **Research client-side encryption**
2. **Opt-in "Privacy Mode"**
3. **Clearly explain tradeoffs**
4. **Premium feature ($$$)**

### Best Practices
1. **Minimize admin access** through automation
2. **Log everything** for accountability
3. **Regular audits** of access patterns
4. **Clear communication** with users
5. **Legal preparedness** for requests

## FAQ for Users

**Q: Can Photolala employees see my photos?**
A: Technically yes, but only with proper authorization, logging, and a valid business reason. We have strict controls and auditing.

**Q: What if I don't trust any company?**
A: We plan to offer an optional "Privacy Mode" with client-side encryption where even we can't see your photos. Coming in Phase 2.

**Q: What about government requests?**
A: We notify users when legally allowed and fight overly broad requests. See our transparency report.

**Q: How do I know you won't peek?**
A: All access is logged, audited, and reviewed. Unauthorized access leads to immediate termination and potential legal action.
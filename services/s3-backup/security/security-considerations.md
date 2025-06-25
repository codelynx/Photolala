# S3 Backup Service Security Considerations

## Overview

This document outlines security considerations for the S3 backup service, covering data protection, authentication, access control, and privacy concerns.

## Threat Model

### Assets to Protect
1. **User Photos** - Personal memories, potentially sensitive content
2. **S3 Credentials** - Access keys, secret keys
3. **Metadata** - Location data, timestamps, camera information
4. **User Privacy** - Backup patterns, folder structures

### Potential Threats
1. **Credential Theft** - Unauthorized access to S3 credentials
2. **Data Exposure** - Photos accessible to unauthorized parties
3. **Man-in-the-Middle** - Interception during upload
4. **Metadata Leakage** - Exposure of personal information
5. **Account Compromise** - S3 account takeover

## Security Measures

### 1. Credential Management

#### Storage
- **Never store credentials in**:
  - Source code
  - Configuration files
  - User defaults/preferences
  - Log files
  
- **Always store credentials in**:
  - macOS: Keychain Services
  - iOS: Keychain with proper access controls
  
#### Access
```swift
// Keychain storage example
let credentials = S3Credentials(
    accessKeyId: accessKey,
    secretAccessKey: secretKey
)

// Store with app-specific access
KeychainManager.store(
    credentials,
    service: "com.photolala.s3backup",
    account: provider.id.uuidString,
    access: .whenUnlockedThisDeviceOnly
)
```

#### Rotation
- Support credential rotation without service interruption
- Detect expired credentials and prompt for update
- Clear old credentials from keychain

### 2. Data Protection

#### Encryption at Rest
- **Server-Side Encryption (Default)**:
  - S3-SSE (AES-256)
  - SSE-KMS for key management
  - SSE-C for customer-provided keys

- **Client-Side Encryption (Optional)**:
  ```swift
  // Encryption before upload
  let encryptedData = try AES256.encrypt(
      photoData,
      key: derivedKey,
      iv: randomIV
  )
  
  // Store IV with object metadata
  metadata["x-amz-meta-client-iv"] = iv.base64Encoded
  ```

#### Encryption in Transit
- **Minimum TLS 1.2** for all connections
- **Certificate validation** enabled
- **Certificate pinning** for known providers (optional)

### 3. Access Control

#### S3 Bucket Policies
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT:user/photolala-backup"
      },
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-photos/*",
        "arn:aws:s3:::my-photos"
      ]
    }
  ]
}
```

#### IAM Permissions (Minimal)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::my-photos"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::my-photos/*"
    }
  ]
}
```

### 4. Privacy Protection

#### Metadata Handling
- **Strip sensitive EXIF data** (optional):
  - GPS coordinates
  - Camera serial numbers
  - Owner information
  
- **Anonymize filenames** (optional):
  ```swift
  // Hash-based naming
  let anonymousKey = "\(SHA256(filename))/\(timestamp).jpg"
  ```

#### Audit Logging
- Log uploads without exposing content
- Never log credentials or personal data
- Rotate logs regularly

### 5. Network Security

#### Request Signing
- Use AWS Signature Version 4
- Include timestamps to prevent replay attacks
- Validate signature on responses

#### Connection Handling
```swift
// URLSession configuration
let config = URLSessionConfiguration.default
config.tlsMinimumSupportedProtocolVersion = .TLSv12
config.tlsMaximumSupportedProtocolVersion = .TLSv13
config.requiresDNS = true
config.allowsCellularAccess = userSettings.allowCellularUploads
```

### 6. Key Management

#### Key Derivation
```swift
// Derive encryption key from user passphrase
func deriveKey(from passphrase: String, salt: Data) -> Data {
    return try PBKDF2.deriveKey(
        from: passphrase,
        salt: salt,
        iterations: 100_000,
        keyLength: 32 // 256 bits
    )
}
```

#### Key Storage
- Never store encryption keys in plain text
- Use Keychain for key storage
- Support key escrow (recovery key)

### 7. Security Headers

#### S3 Object Headers
```swift
// Security-related headers
let headers = [
    "x-amz-server-side-encryption": "AES256",
    "x-amz-acl": "private",
    "Cache-Control": "no-cache, no-store, must-revalidate",
    "x-amz-storage-class": "STANDARD_IA"
]
```

### 8. Error Handling

#### Information Disclosure
- **Don't expose**:
  - Full file paths
  - S3 bucket structure
  - Internal error details
  - Stack traces
  
- **Do provide**:
  - User-friendly error messages
  - Actionable guidance
  - Error codes for support

### 9. Compliance

#### GDPR Considerations
- **Right to Access**: Export all user's backed up data
- **Right to Delete**: Remove all data from S3
- **Data Portability**: Standard format exports
- **Privacy by Design**: Minimal data collection

#### Data Residency
- Allow users to choose S3 region
- Respect local data protection laws
- Document data locations

### 10. Security Checklist

#### Before Release
- [ ] Security audit of credential handling
- [ ] Penetration testing of upload flow
- [ ] Review of S3 bucket permissions
- [ ] Validation of encryption implementation
- [ ] Check for credential leaks in logs

#### Ongoing
- [ ] Monitor for unusual upload patterns
- [ ] Regular credential rotation
- [ ] Security update notifications
- [ ] Incident response plan

## Incident Response

### Credential Compromise
1. Immediate credential revocation
2. Audit S3 access logs
3. Generate new credentials
4. Notify affected users
5. Review security measures

### Data Breach
1. Identify scope of breach
2. Secure affected resources
3. Notify users per regulations
4. Provide remediation steps
5. Post-incident review

## Security Best Practices for Users

### Recommendations
1. **Use strong credentials** - Long, random access keys
2. **Enable MFA** - On S3 account
3. **Regular audits** - Check S3 access logs
4. **Unique buckets** - Don't share with other apps
5. **Encryption** - Enable client-side for sensitive photos
6. **Access reviews** - Regularly review IAM permissions

### Warning Signs
- Unexpected S3 charges
- Unknown files in bucket
- Failed authentication attempts
- Slow upload speeds (possible MitM)

## Future Security Enhancements

1. **Hardware Security Module (HSM)** integration
2. **Biometric authentication** for app access
3. **Zero-knowledge architecture** option
4. **Blockchain verification** of backups
5. **Homomorphic encryption** for cloud processing
# Credential Security Deep Dive

## Executive Summary

Photolala2 uses credential-code to encrypt and embed all environment credentials directly into the app binary. This approach provides strong security against casual inspection while enabling offline operation and simplified deployment.

## How Credential-Code Works

### Encryption Process

1. **Input**: Plain text credentials from `.credentials/` directory
2. **Encryption**: AES-256-GCM with generated key
3. **Output**: Swift/Kotlin source files with encrypted byte arrays
4. **Compilation**: Encrypted data becomes part of app binary

### Technical Details

```
Plain Text Credential
        ↓
   AES-256-GCM
   (Random Key + IV)
        ↓
Encrypted Bytes + Tag
        ↓
  Source Code Array
        ↓
   Compiled Binary
```

#### Encryption Components
- **Algorithm**: AES-256-GCM (Authenticated Encryption)
- **Key Size**: 256 bits (32 bytes)
- **IV/Nonce**: 96 bits (12 bytes) per credential
- **Auth Tag**: 128 bits (16 bytes) for integrity
- **Implementation**: Apple CryptoKit / Android Crypto

### Generated Code Structure

```swift
// Credentials.swift (Generated)
public struct Credentials {
    private static let encryptedData: [CredentialKey: (data: [UInt8], nonce: [UInt8], tag: [UInt8])] = [
        .AWS_ACCESS_KEY_ID_DEV: (
            data: [...],     // Encrypted credential
            nonce: [...],    // Initialization vector
            tag: [...]       // Authentication tag
        ),
        // ... more credentials
    ]

    public static func decrypt(_ key: CredentialKey) -> String? {
        // Decryption logic using CryptoKit
    }
}
```

## Why This Approach Is Secure

### 1. Defense Against Source Code Exposure

**Scenario**: GitHub repository accidentally made public

**Protection**:
- Credentials appear as meaningless byte arrays
- Without decryption key, data is cryptographically secure
- 2^256 possible keys makes brute force infeasible

**Example**:
```swift
// What an attacker sees:
data: [0x25, 0x8A, 0x82, 0xA0, ...]  // Meaningless without key
```

### 2. Binary Inspection Resistance

**Scenario**: Attacker examines app binary with hex editor

**Protection**:
- Encrypted bytes scattered throughout binary
- No obvious credential patterns
- Mixed with other binary data
- Key derivation makes extraction difficult

**Limitations**:
- Sophisticated reverse engineering could extract key
- Runtime memory inspection possible on jailbroken devices

### 3. Compile-Time Security

**Scenario**: Build process or CI/CD compromise

**Protection**:
- Credentials encrypted before build
- Build servers never see plain text
- Generated files can be public
- Only runtime has decryption capability

## Environment Selection Security

### UserDefaults Storage

```swift
// How environment is selected
let environment = UserDefaults.standard.string(forKey: "environment_preference") ?? "production"

// How credentials are chosen
switch environment {
    case "dev": useCredentials(.AWS_ACCESS_KEY_ID_DEV)
    case "stage": useCredentials(.AWS_ACCESS_KEY_ID_STAGE)
    case "prod": useCredentials(.AWS_ACCESS_KEY_ID_PROD)
}
```

### Production Safety

```swift
#if DEBUG || DEVELOPER
    // Can switch environments
    return UserDefaults.standard.string(forKey: "environment_preference")
#else
    // AppStore builds locked to production
    return "production"
#endif
```

## Credential Lifecycle

### 1. Creation
```bash
# Developer adds credential
echo "AKIAYHXTJECMPEBE6FMC" > .credentials/aws/dev/access-key.txt
```

### 2. Encryption
```bash
# credential-code encrypts all credentials
./scripts/generate-credentials.sh
# Creates: Credentials.swift with encrypted data
```

### 3. Compilation
```bash
# Xcode/Gradle compiles encrypted data into binary
xcodebuild -scheme Photolala build
```

### 4. Runtime Decryption
```swift
// App decrypts on demand
let accessKey = Credentials.decrypt(.AWS_ACCESS_KEY_ID_DEV)
// Credential exists in memory only during use
```

### 5. Memory Management
```swift
// After use, credential should be cleared
var accessKey = Credentials.decrypt(.AWS_ACCESS_KEY_ID_DEV)
// ... use credential ...
accessKey = nil  // Clear from memory
```

## Rotation Procedures

### Regular Rotation (Quarterly)

1. **Generate New Credentials**
   ```bash
   # In AWS Console, create new IAM credentials
   # Save to .credentials/aws/prod/
   ```

2. **Update Local Files**
   ```bash
   echo "NEW_ACCESS_KEY" > .credentials/aws/prod/access-key.txt
   echo "NEW_SECRET_KEY" > .credentials/aws/prod/secret-key.txt
   ```

3. **Regenerate Encrypted Files**
   ```bash
   ./scripts/generate-credentials.sh
   ```

4. **Test All Environments**
   ```bash
   # Test dev
   # Build and verify dev environment works

   # Test stage
   # Build and verify stage environment works

   # Test prod (carefully)
   # Build and verify prod environment works
   ```

5. **Deploy Update**
   - Submit to App Store
   - Deploy to Play Store
   - Monitor for issues

6. **Deactivate Old Credentials**
   - Wait for majority adoption (1-2 weeks)
   - Deactivate old IAM credentials
   - Monitor for failures

### Emergency Rotation (Compromise)

**Time Target: < 1 hour**

1. **IMMEDIATE: Disable Compromised Credentials**
   ```bash
   aws iam update-access-key --access-key-id OLD_KEY --status Inactive
   ```

2. **Create New Credentials**
   ```bash
   aws iam create-access-key --user-name photolala-prod
   ```

3. **Update and Generate**
   ```bash
   # Update credential files
   ./scripts/generate-credentials.sh
   ```

4. **Emergency Build**
   ```bash
   # Build new version
   # Test critical paths
   # Submit for expedited review
   ```

5. **Monitor and Communicate**
   - Watch CloudTrail for abuse
   - Notify users if necessary
   - Document incident

## Compromise Detection

### Indicators of Compromise

1. **AWS CloudTrail Anomalies**
   - Unusual API calls
   - Access from unknown IPs
   - Failed authentication attempts

2. **Billing Alerts**
   - Unexpected charges
   - New service usage
   - Increased data transfer

3. **Application Behavior**
   - Increased error rates
   - Authentication failures
   - Unexpected S3 operations

### Monitoring Setup

```bash
# CloudWatch Alarm for unusual activity
aws cloudwatch put-metric-alarm \
  --alarm-name UnusualS3Activity \
  --alarm-description "Alert on unusual S3 access patterns" \
  --metric-name NumberOfObjects \
  --namespace AWS/S3
```

## Security Comparison

### Our Approach vs Alternatives

| Aspect | Embedded Encrypted | Environment Variables | Secret Manager | Key Server |
|--------|-------------------|----------------------|----------------|------------|
| Offline Works | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| Rotation | 🟡 App Update | ✅ Instant | ✅ Instant | ✅ Instant |
| Complexity | ✅ Simple | ✅ Simple | 🟡 Medium | ❌ Complex |
| Cost | ✅ Free | ✅ Free | 💰 Per Secret | 💰 Server |
| Security | ✅ Good | 🟡 Medium | ✅ Good | ✅ Best |

### When to Use Our Approach

**Good Fit**:
- Mobile/desktop apps
- Offline requirement
- Simple credential needs
- Cost sensitive
- Fast startup required

**Poor Fit**:
- Web applications
- Frequent rotation needs
- Compliance requirements
- High-value targets
- Server applications

## Advanced Security Considerations

### Key Derivation

credential-code uses a deterministic key derivation:
- Prevents key extraction from binary
- Makes reverse engineering harder
- Unique per compilation

### Memory Protection

```swift
// Recommendations for sensitive operations
autoreleasepool {
    let credential = Credentials.decrypt(.AWS_SECRET_KEY)
    // Use credential
    // Automatically cleaned up after scope
}
```

### Anti-Tampering

While not implemented, consider:
- Binary signature verification
- Integrity checks
- Certificate pinning
- Jailbreak detection

## Security Audit Questions

### For Security Review

1. **Q**: How are credentials protected at rest?
   **A**: AES-256-GCM encryption in binary

2. **Q**: Can credentials be extracted from memory?
   **A**: Yes, on compromised devices with debugger access

3. **Q**: How quickly can credentials be rotated?
   **A**: 1-24 hours depending on app store review

4. **Q**: What if credential-code has a vulnerability?
   **A**: Monitor for updates, standard crypto libraries used

5. **Q**: How are different environments isolated?
   **A**: Runtime selection, production builds locked

### For Penetration Testing

Focus Areas:
1. Binary analysis resistance
2. Memory dump protection
3. Network traffic inspection
4. Environment switching exploits
5. Credential extraction attempts

## Recommendations

### Short Term
1. ✅ Implement memory clearing after credential use
2. ✅ Add CloudTrail monitoring
3. ✅ Set up billing alerts
4. ✅ Document rotation procedures

### Medium Term
1. 🔄 Consider certificate pinning
2. 🔄 Add jailbreak/root detection
3. 🔄 Implement credential use logging
4. 🔄 Create automated rotation scripts

### Long Term
1. 🔮 Evaluate AWS Secrets Manager integration
2. 🔮 Consider HSM for key storage
3. 🔮 Implement zero-knowledge architecture
4. 🔮 Add compliance certifications

## Conclusion

The credential-code approach provides a pragmatic balance between security and usability for mobile applications. While not suitable for all use cases, it offers strong protection against common threats while maintaining simplicity and offline capability.

For Photolala2's requirements, this approach provides:
- ✅ Protection against source code exposure
- ✅ Resistance to casual inspection
- ✅ Offline operation capability
- ✅ Simple deployment process
- ✅ Reasonable rotation capability

The key is understanding the trade-offs and implementing appropriate monitoring and response procedures.

---

*Technical Review: Required*
*Security Review: Required*
*Last Updated: September 2024*
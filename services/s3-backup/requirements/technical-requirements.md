# S3 Backup Service Technical Requirements (Simplified)

## Platform Requirements

### macOS Only (Phase 1)
- **Minimum OS**: macOS 14.0 (Sonoma)
- **Architecture**: Apple Silicon only
- **Frameworks**:
  - Foundation
  - Security.framework (for keychain)
  - AWS SDK for Swift

### No iOS Support (Phase 1)
- Focus on macOS first
- iOS can be added later if needed

## S3 API Requirements

### Phase 1: Basic Operations Only
- `ListBuckets` - Show user their buckets
- `PutObject` - Upload photos
- `HeadObject` - Check if photo already uploaded

### That's it!

Later phases might add:
- Multipart upload for large files
- Different storage classes
- Download capability

## Simple Requirements

### Performance
- Upload one file at a time (no concurrency yet)
- Use whatever the AWS SDK defaults to
- Don't worry about optimization in Phase 1

### Data Storage

#### No Database!
Use a simple JSON file instead:
- Location: `~/Library/Application Support/Photolala/backup-state.json`
- Human readable
- Easy to debug
- No dependencies

#### JSON Structure
```json
{
  "version": 1,
  "lastBackup": "2025-06-15T10:30:00Z",
  "files": {
    "/path/to/photo.jpg": {
      "uploadedAt": "2025-06-15T10:30:00Z",
      "size": 2048576,
      "s3Key": "photos/photo.jpg"
    }
  }
}
```

[KY] I am not confident' we can discuss later


## Security Requirements

### Credential Storage
- **macOS**: Keychain Services API
- **iOS**: Keychain with kSecAttrAccessibleAfterFirstUnlock
- **Encryption**: All credentials encrypted at rest
- **Access**: App-specific, not shared

### Network Security
- **TLS Version**: Minimum TLS 1.2
- **Certificate Pinning**: Optional for known providers
- **Request Signing**: AWS Signature Version 4

### Data Protection
- **At Rest**: Optional client-side encryption
- **In Transit**: Always encrypted (HTTPS)
- **Algorithms**: AES-256-GCM for client-side
- **Key Derivation**: PBKDF2 or Argon2

## Integration Requirements

### Photo Library Integration
- **File Watching**: FSEvents (macOS) / File Coordination (iOS)
- **Metadata Access**: Read EXIF, IPTC, XMP
- **Thumbnail Generation**: For quick previews
- **Format Support**: All formats supported by Photolala

### UI Integration
- **SwiftUI Views**: For settings and status
- **AppKit/UIKit**: For system integration
- **Notifications**: Upload completion, errors
- **Status Bar**: macOS menu bar item

## Monitoring Requirements

### Logging
- **Levels**: Error, Warning, Info, Debug
- **Rotation**: Keep last 7 days
- **Privacy**: No credentials or personal data
- **Location**: `~/Library/Logs/Photolala/`

### Metrics
- **Upload Statistics**:
  - Total bytes uploaded
  - Number of files uploaded
  - Average upload speed
  - Success/failure rates

- **Performance Metrics**:
  - Queue processing time
  - Network latency
  - Memory usage
  - CPU usage

### Health Checks
- **Connection Test**: Periodic S3 connectivity check
- **Queue Health**: Monitor for stuck uploads
- **Storage Health**: Check available disk space

## Error Handling Requirements

### Recoverable Errors
- **Network Timeouts**: Retry with backoff
- **Rate Limiting**: Honor retry-after headers
- **Temporary S3 Errors**: 503, 500 errors
- **Partial Uploads**: Resume multipart

### Non-Recoverable Errors
- **Authentication Failures**: Notify user
- **Permissions Errors**: Clear guidance
- **Corrupt Files**: Skip and log
- **Quota Exceeded**: Pause uploads

## Testing Requirements

### Unit Tests
- **Coverage**: > 80% for core logic
- **Mocking**: S3 client, network, file system
- **Edge Cases**: Large files, interruptions

### Integration Tests
- **Real S3**: Test against MinIO locally
- **Providers**: Test each supported provider
- **Scenarios**: Upload, resume, conflict

### Performance Tests
- **Load Testing**: 10,000+ files
- **Bandwidth**: Various network speeds
- **Memory**: Monitor for leaks
- **Battery**: iOS battery impact

## Compliance Requirements

### Privacy
- **User Consent**: Explicit opt-in for backup
- **Data Location**: User chooses region
- **Deletion**: Complete removal option
- **Export**: User can download all data

### Provider Compliance
- **AWS**: Understand service limits
- **GDPR**: For EU users
- **Data Residency**: Respect user choice
- **Logging**: Audit trail for actions

## Backward Compatibility

### Migration
- **Existing Photos**: Scan and queue for upload
- **Settings**: Migrate from older versions
- **Database**: Schema versioning

### Versioning
- **API Version**: Track S3 API changes
- **File Format**: Version metadata format
- **Protocol**: Handle protocol updates

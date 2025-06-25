# S3 Real Testing Guide

## Setup Steps

### 1. AWS Credentials

Set up your AWS credentials using environment variables in Xcode:

1. Edit scheme: Product → Scheme → Edit Scheme
2. Select "Run" → "Arguments" tab
3. Add environment variables:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
   - `AWS_DEFAULT_REGION`: us-east-1 (or your preferred region)

### 2. User ID Configuration

The code is currently configured to use:
- **Debug builds**: `test-user-123` (with test catalog generation)
- **Release builds**: `test-s3-user-001` (for real S3 testing)

You can change the release build userId in `S3PhotoBrowserView.swift` line 284.

### 3. Upload Test Photos

1. Build and run in **Release** mode (not Debug)
2. Open the S3 Backup Test view (from Photolala menu)
3. Upload some test photos
4. The photos will be stored at:
   - Photos: `photos/test-s3-user-001/{md5}.dat`
   - Thumbnails: `thumbnails/test-s3-user-001/{md5}.jpg`
   - Metadata: `metadata/test-s3-user-001/{md5}.plist`

### 4. Create and Upload Catalog

After uploading photos, you need to create a .photolala catalog. For now, you can:

1. Use the S3BackupTestView to list your photos
2. Manually create a catalog (we'll implement an automated catalog generator later)
3. Upload the catalog files to:
   - `catalogs/test-s3-user-001/.photolala` (manifest)
   - `catalogs/test-s3-user-001/.photolala#0` through `.photolala#f` (shards)

### 5. Test S3 Photo Browser

1. Choose "Browse Cloud Backup" from File menu (⇧⌘O)
2. The browser should:
   - Download the catalog from S3 (if changed)
   - Show your uploaded photos
   - Download thumbnails on demand
   - Show archive badges if any photos are in Deep Archive

## Testing Scenarios

### Basic Testing
1. Upload 5-10 photos
2. Create catalog with those photos
3. Verify browser shows all photos
4. Check thumbnail loading works
5. Test scrolling performance

### Archive Testing
1. Upload some photos
2. Manually change their storage class to DEEP_ARCHIVE in S3 console
3. Update catalog to reflect archive status
4. Verify archive badges appear

### Sync Testing
1. Upload new photos
2. Update catalog
3. Reopen browser - should sync changes
4. Verify new photos appear

## Troubleshooting

### AWS Credentials Not Working
- Check environment variables are set correctly
- Verify AWS credentials have S3 permissions
- Check AWS region matches your bucket location

### Photos Not Appearing
- Verify catalog files exist in S3
- Check catalog format is correct
- Look for sync errors in console output

### Thumbnails Not Loading
- Check thumbnail files exist in S3
- Verify S3DownloadService has proper credentials
- Check for download errors in console

## Next Steps

Once basic testing works:
1. Implement automated catalog generation
2. Test with larger photo collections
3. Test archive restoration flow
4. Implement batch operations
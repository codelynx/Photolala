# S3 Lifecycle Configuration Scripts

## Which Script to Use?

### For Immediate Use: `configure-s3-lifecycle-simple.sh`

This is the script you should run now. It:
- Archives all content under `users/` after 180 days
- Works with the current S3 structure
- Simple one-command setup

```bash
./configure-s3-lifecycle-simple.sh
```

**Note**: This will also archive thumbnails and metadata (not ideal, but functional).

### For Future Use: Other Scripts

1. **configure-s3-lifecycle-v2.sh**
   - Use this after modifying S3BackupService to add object tags
   - Provides more precise control over what gets archived

2. **configure-s3-lifecycle-lambda.sh**
   - Use for advanced selective archiving
   - Requires setting up AWS Lambda
   - Most flexible but complex

## Current S3 Structure

```
photolala/
  users/
    {userId}/
      photos/*.dat      # Original photos → Should archive after 180 days
      thumbs/*.dat      # Thumbnails → Should use Intelligent-Tiering
      metadata/*.plist  # Metadata → Should stay in Standard storage
```

## Limitations

S3 lifecycle rules can't use wildcards in the middle of paths (like `users/*/photos/`), which is why the simple approach archives everything under `users/`.

## Recommendations

1. **Short term**: Use `configure-s3-lifecycle-simple.sh`
2. **Long term**: Either:
   - Modify app to use different top-level prefixes (photos/, thumbnails/, metadata/)
   - Or implement object tagging in S3BackupService
   - Or deploy the Lambda-based solution
# S3 Lifecycle Future Improvements

This document outlines three approaches to improve S3 lifecycle management for Photolala, moving beyond the simple "archive everything" approach.

## Current Situation

**Problem**: All content is stored under `users/{userId}/` prefix:
- `users/{userId}/photos/*.dat` - Should archive after 180 days
- `users/{userId}/thumbs/*.dat` - Should use Intelligent-Tiering
- `users/{userId}/metadata/*.plist` - Should stay in Standard storage

S3 lifecycle rules can't distinguish between these subdirectories because they don't support wildcards in the middle of paths.

## Improvement Options

### Option 1: Object Tagging Approach

**What it is**: Modify S3BackupService to add tags when uploading objects, then use tag-based lifecycle rules.

**Implementation Steps**:

1. **Modify S3BackupService.swift**:
```swift
// When uploading photos
let putObjectInput = PutObjectInput(
    body: .data(photoData),
    bucket: bucketName,
    key: "users/\(userId)/photos/\(md5).dat",
    tagging: "Type=photo&Lifecycle=archive"  // Add this
)

// When uploading thumbnails
let putObjectInput = PutObjectInput(
    body: .data(thumbnailData),
    bucket: bucketName,
    key: "users/\(userId)/thumbs/\(md5).dat",
    tagging: "Type=thumbnail&Lifecycle=optimize"  // Add this
)

// When uploading metadata
let putObjectInput = PutObjectInput(
    body: .data(metadataData),
    bucket: bucketName,
    key: "users/\(userId)/metadata/\(md5).plist",
    tagging: "Type=metadata&Lifecycle=keep"  // Add this
)
```

2. **Configure lifecycle rules** using `configure-s3-lifecycle-v2.sh`:
```json
{
    "Rules": [
        {
            "ID": "archive-photos",
            "Status": "Enabled",
            "Filter": {
                "Tag": {
                    "Key": "Type",
                    "Value": "photo"
                }
            },
            "Transitions": [
                {
                    "Days": 180,
                    "StorageClass": "DEEP_ARCHIVE"
                }
            ]
        },
        {
            "ID": "optimize-thumbnails",
            "Status": "Enabled",
            "Filter": {
                "Tag": {
                    "Key": "Type",
                    "Value": "thumbnail"
                }
            },
            "Transitions": [
                {
                    "Days": 0,
                    "StorageClass": "INTELLIGENT_TIERING"
                }
            ]
        }
    ]
}
```

**Pros**:
- Precise control over each object type
- Works with existing path structure
- Easy to add new object types

**Cons**:
- Requires app code changes
- Tags add slight overhead to each upload
- Existing objects need to be retagged

**When to use**: Best for new deployments or when you can update all existing objects.

### Option 2: Path Restructuring Approach

**What it is**: Change the S3 structure to use top-level prefixes for each object type.

**New Structure**:
```
photolala/
  photos/
    {userId}/
      {md5}.dat
  thumbnails/
    {userId}/
      {md5}.dat
  metadata/
    {userId}/
      {md5}.plist
```

**Implementation Steps**:

1. **Update S3BackupService.swift**:
```swift
// Change from:
let key = "users/\(userId)/photos/\(md5).dat"
// To:
let key = "photos/\(userId)/\(md5).dat"

// Change from:
let key = "users/\(userId)/thumbs/\(md5).dat"
// To:
let key = "thumbnails/\(userId)/\(md5).dat"

// Change from:
let key = "users/\(userId)/metadata/\(md5).plist"
// To:
let key = "metadata/\(userId)/\(md5).plist"
```

2. **Simple lifecycle rules**:
```json
{
    "Rules": [
        {
            "ID": "archive-photos",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "photos/"
            },
            "Transitions": [
                {
                    "Days": 180,
                    "StorageClass": "DEEP_ARCHIVE"
                }
            ]
        },
        {
            "ID": "optimize-thumbnails",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "thumbnails/"
            },
            "Transitions": [
                {
                    "Days": 0,
                    "StorageClass": "INTELLIGENT_TIERING"
                }
            ]
        }
    ]
}
```

**Pros**:
- Simplest lifecycle rules
- Best performance (prefix-based rules are fastest)
- Clear organization

**Cons**:
- Requires migrating existing data
- Changes S3 structure significantly
- May affect other systems expecting current structure

**When to use**: Best for new projects or major version updates.

### Option 3: Lambda-Based Approach

**What it is**: Use AWS Lambda to periodically scan and selectively archive objects based on custom logic.

**Implementation** using `configure-s3-lifecycle-lambda.sh`:

1. **Deploy Lambda function** that:
   - Scans objects daily
   - Checks object path to determine type
   - Applies appropriate storage class changes
   - Handles edge cases and exceptions

2. **Lambda code example**:
```python
def lambda_handler(event, context):
    for obj in list_objects(prefix='users/'):
        key = obj['Key']
        age_days = get_object_age(obj)
        
        if '/photos/' in key and age_days >= 180:
            change_storage_class(key, 'DEEP_ARCHIVE')
        elif '/thumbs/' in key:
            change_storage_class(key, 'INTELLIGENT_TIERING')
        # Metadata remains in STANDARD (no action needed)
```

3. **Schedule with EventBridge**:
   - Run daily at 2 AM
   - Process in batches to avoid timeouts
   - Log all transitions for auditing

**Pros**:
- Most flexible - can implement any logic
- No app changes required
- Can handle complex rules and exceptions
- Easy to modify rules without touching app

**Cons**:
- Additional infrastructure (Lambda, CloudWatch, etc.)
- Ongoing Lambda execution costs
- More complex to monitor and debug
- Potential for Lambda timeouts on large datasets

**When to use**: Best when you need complex rules or can't modify the app.

## Comparison Matrix

| Aspect | Tagging | Restructure | Lambda |
|--------|---------|-------------|---------|
| App changes required | Yes | Yes | No |
| Data migration needed | No | Yes | No |
| Complexity | Medium | Low | High |
| Flexibility | High | Low | Very High |
| Performance | Good | Best | Good |
| Ongoing costs | None | None | Lambda execution |
| Time to implement | 1-2 days | 3-5 days | 2-3 days |

## Recommendations

### Short Term (Now)
Use the simple lifecycle rule that archives everything. It's not optimal but it works.

### Medium Term (Next Quarter)
Implement **Option 1 (Tagging)** because:
- Minimal disruption to existing system
- Can be rolled out gradually
- Provides good flexibility

### Long Term (Next Major Version)
Consider **Option 2 (Restructuring)** because:
- Cleanest architecture
- Best performance
- Simplest maintenance

### Special Cases
Use **Option 3 (Lambda)** only if:
- You need complex rules (e.g., archive based on user tier)
- You can't modify the app
- You need to process existing data without migration

## Implementation Timeline

### Phase 1: Current (Week 1)
- ✅ Deploy simple lifecycle rules
- ✅ Monitor impact
- ✅ Document for users

### Phase 2: Tagging (Month 2-3)
- [ ] Add tagging to S3BackupService
- [ ] Test with new uploads
- [ ] Create migration script for existing objects
- [ ] Deploy tag-based lifecycle rules
- [ ] Remove simple rules

### Phase 3: Optimization (Month 6+)
- [ ] Analyze storage patterns
- [ ] Consider path restructuring for v2.0
- [ ] Implement cost optimization strategies

## Cost Impact

All approaches achieve the same cost savings:
- Photos: ~95% reduction after 180 days
- Thumbnails: ~45% reduction with Intelligent-Tiering
- Metadata: No change (negligible cost)

The difference is in precision and flexibility, not cost.
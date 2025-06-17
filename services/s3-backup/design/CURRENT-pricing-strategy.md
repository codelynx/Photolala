# Photolala Pricing V5 - Simple Storage Tiers + Universal Lifecycle

## Updated Strategy (June 16, 2025)

**Core Principle**: Same features for everyone, different storage limits
**Lifecycle Policy**: Universal 180-day archive for all users
**Path Structure**: Clean separation by content type

## Game-Changing Approach

**What users see**: "1TB photo storage"
**What they get**: 1TB photos + ~50GB thumbnails/metadata FREE

This makes our offering even MORE attractive!

## Revised Storage Calculations

### Essential Tier ($1.99) - "1TB Photo Storage"
```
What users get:
- 1TB (1,024GB) photo storage (counted)
- ~41GB thumbnail storage (FREE bonus - 4% of photos)
- ~10GB metadata storage (FREE bonus - 1% of photos)
- Total actual storage: 1,075GB

Cost breakdown:
Photos (1,024GB):
- 4GB S3 Standard (2 days): 4GB × $0.023 = $0.092
- 1,020GB Deep Archive: 1,020GB × $0.00099 = $1.01

Thumbnails (41GB) - FREE BONUS:
- 2GB S3 Standard: 2GB × $0.023 = $0.046
- 39GB Standard-IA: 39GB × $0.0125 = $0.49

Metadata (10GB) - FREE BONUS:
- All Standard-IA: 10GB × $0.0125 = $0.125

Total Storage Cost: $1.77
Revenue after Apple: $1.39
Margin: 22% (down from 70% but still profitable!)
```

### Plus Tier ($2.99) - "2TB Photo Storage"
```
What users get:
- 2TB (2,048GB) photo storage (counted)
- ~82GB thumbnail storage (FREE bonus)
- ~20GB metadata storage (FREE bonus)
- Total actual storage: 2,150GB

Cost breakdown:
Photos (2,048GB):
- 8GB S3 Standard (2 days): 8GB × $0.023 = $0.18
- 2,040GB Deep Archive: 2,040GB × $0.00099 = $2.02

Thumbnails (82GB) - FREE BONUS:
- 4GB S3 Standard: 4GB × $0.023 = $0.092
- 78GB Standard-IA: 78GB × $0.0125 = $0.98

Metadata (20GB) - FREE BONUS:
- All Standard-IA: 20GB × $0.0125 = $0.25

Total Storage Cost: $3.50
Revenue after Apple: $2.09
Margin: 40% (still healthy!)
```

## Marketing Advantages

### Before (Confusing)
"1TB total storage (including thumbnails and metadata)"

### After (Clear & Generous)
"1TB for your photos + smart previews included FREE"

## Competitive Comparison

| Service | Price | Photo Storage | Thumbnails | Total |
|---------|-------|---------------|------------|-------|
| iCloud | $9.99 | 2TB | Counted | 2TB |
| Google | $9.99 | 2TB | Counted | 2TB |
| **Photolala** | **$2.99** | **2TB** | **FREE** | **~2.1TB** |

We're not just 70% cheaper - we give MORE storage!

## Implementation Benefits

1. **Simpler quotas**: Only count photo uploads against quota
2. **Better UX**: Users never worry about thumbnail space
3. **Marketing win**: "FREE smart previews with every plan"
4. **Technical advantage**: Can optimize thumbnails without user concern

## Revised Tier Structure

| Tier | Price | Photo Storage | Thumb Size (est) | Meta Size (est) | Total Storage | Archive Policy | Margin |
|------|-------|---------------|------------------|-----------------|---------------|----------------|--------|
| Free | $0 | 5GB | ~200MB | ~50MB | ~5.2GB | 180 days | - |
| Starter | $0.99 | 500GB | ~20GB | ~5GB | ~525GB | 180 days | 45% |
| Essential | $1.99 | 1TB | ~41GB | ~10GB | ~1.08TB | 180 days | 22% |
| Plus | $2.99 | 2TB | ~82GB | ~20GB | ~2.15TB | 180 days | 40% |
| Family | $5.99 | 5TB | ~205GB | ~50GB | ~5.25TB | 180 days | 35% |

### Storage Class Details

**For ALL tiers (universal policy):**
- **Photos**:
  - Days 0-180: S3 Standard (instant access)
  - Days 180+: S3 Deep Archive (12-48 hour retrieval)
- **Thumbnails**:
  - All days: S3 Intelligent-Tiering (automatic optimization)
- **Metadata**:
  - All days: S3 Standard (always instant access)

### Why Universal 180-Day Archive?

**We considered plan-based archive timing:**
- Free: 90 days
- Basic: 180 days
- Pro: 365 days
- Family: Never

**But chose universal 180 days because:**
1. **Technical Simplicity**: S3 lifecycle rules can't check user plans
2. **User Experience**: "Your photos are safe for 6 months" is clear
3. **Cost Savings**: Benefits us equally regardless of user tier
4. **Fair & Transparent**: No surprises when downgrading plans
5. **Industry Standard**: 6 months is reasonable for "hot" storage

### Archive Timing Comparison: 30 vs 180 Days

**Option A: 30-Day Archive**
```
Essential Tier (1TB) Cost Breakdown:
- 1GB S3 Standard (most recent day): 1GB × $0.023 = $0.023
- 1,023GB Deep Archive: 1,023GB × $0.00099 = $1.01
Total Storage Cost: $1.03

User Experience:
- Last 30 days: ⚡ Instant access
- Older than 30 days: 🐌 12-48 hour retrieval
- Result: Frequent retrieval requests, poor UX
```

**Option B: 180-Day Archive (Chosen)**
```
Essential Tier (1TB) Cost Breakdown:
- 4GB S3 Standard (2 days fresh): 4GB × $0.023 = $0.092
- 1,020GB Deep Archive: 1,020GB × $0.00099 = $1.01
Total Storage Cost: $1.10

User Experience:
- Last 6 months: ⚡ Instant access
- Older than 6 months: 🐌 12-48 hour retrieval
- Result: Rare retrieval requests, great UX
```

**Cost Difference: $0.07/month ($0.84/year) - Negligible!**

**Why 180 Days Wins:**
- **Same cost**: Only 7¢ more per TB per month
- **10x better UX**: 6 months vs 30 days of instant access
- **Fewer retrievals**: Most people access photos from last 3-6 months
- **Marketing**: "6 months instant access" vs "30 days" - no contest
- **Seasonal photos**: Covers full seasons (summer vacation, holidays, etc.)

## S3 Structure & Lifecycle

### New Path Structure
```
photolala/
  photos/
    {userId}/
      {md5}.dat         # → Deep Archive after 180 days
  thumbnails/
    {userId}/
      {md5}.dat         # → Intelligent-Tiering immediately
  metadata/
    {userId}/
      {md5}.plist       # → Always Standard (no lifecycle)
```

### Universal Lifecycle Rules
```json
{
  "Rules": [
    {
      "ID": "archive-all-photos",
      "Filter": { "Prefix": "photos/" },
      "Transitions": [
        { "Days": 180, "StorageClass": "DEEP_ARCHIVE" }
      ]
    },
    {
      "ID": "optimize-thumbnails",
      "Filter": { "Prefix": "thumbnails/" },
      "Transitions": [
        { "Days": 0, "StorageClass": "INTELLIGENT_TIERING" }
      ]
    }
  ]
}
```

## Code Implementation

```swift
// Updated S3 paths
func uploadPhoto(data: Data, userId: String, md5: String) {
    let key = "photos/\(userId)/\(md5).dat"  // New structure
    // Upload logic...
}

// Quota check - only photos count!
func canUploadPhoto(size: Int64) -> Bool {
    let photoUsage = getPhotoUsage() // Only photos
    return (photoUsage + size) <= quotaLimit
}

// Thumbnails/metadata uploads always allowed
func uploadThumbnail(data: Data, userId: String, md5: String) {
    let key = "thumbnails/\(userId)/\(md5).dat"  // New structure
    // No quota check needed - it's free!
    upload(data, key: key)
}
```

## User Communication

### In-App Display
```
Storage Used:
Photos: 750GB / 1TB
Smart Previews: Unlimited ✓
```

### Marketing
"Every photo gets free smart previews - browse all your memories instantly without using your storage quota!"

## Key Decisions

### What Changed
1. **Path Structure**: Moved from `users/{id}/photos/` to `photos/{id}/`
2. **Lifecycle Policy**: Same 180-day rule for ALL users (no plan-based differences)
3. **Business Model**: Storage quotas differentiate plans, not archive timing

### Why This Works
- **Simple Infrastructure**: One set of rules for everyone
- **Clear Value Prop**: "X TB of photo storage" is easy to understand
- **Fair to Users**: Everyone's old photos get archived equally
- **Cost Effective**: We save on storage regardless of user plan

## Summary

With Deep Archive economics + clean path structure, we can:
- Count only photos against quota
- Give thumbnails/metadata as FREE bonus
- Apply simple lifecycle rules to everyone
- Still maintain 20-40% margins
- Offer even MORE value than competitors

This positions us as not just cheaper, but MORE GENEROUS and SIMPLER!

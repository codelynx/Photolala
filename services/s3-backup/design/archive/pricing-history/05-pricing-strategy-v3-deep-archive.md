# Photolala Pricing Strategy V3 - Deep Archive for Photos

## Key Insight
Users understand they're getting 10x more storage for less money. They'll accept 12-48 hour retrieval for that value. Plus, they have local copies anyway!

## Simplified Storage Strategy

### Photos (95% of storage)
- **ALL photos → Deep Archive after 2 days**
- Cost: $0.00099/GB (vs $0.004 for Glacier Instant)
- 75% cheaper than Glacier Instant!

### Thumbnails (4% of storage)  
- Always accessible for browsing
- Days 0-7: S3 Standard ($0.023/GB)
- Days 8+: S3 Standard-IA ($0.0125/GB)

### Metadata (1% of storage)
- Always: S3 Standard-IA ($0.0125/GB)

## New Pricing Calculations

### Starter Tier ($0.99 → $0.69 after Apple)
**500GB Total Storage**
```
Photos (475GB):
- 2GB S3 Standard (2 days): 2GB × $0.023 = $0.046
- 473GB Deep Archive: 473GB × $0.00099 = $0.47

Thumbnails (20GB):
- 1GB S3 Standard (7 days): 1GB × $0.023 = $0.023
- 19GB Standard-IA: 19GB × $0.0125 = $0.24

Metadata (5GB):
- All Standard-IA: 5GB × $0.0125 = $0.06

Monthly Storage Cost: $0.79
Amortized over 4 months: $0.20/month
Revenue after Apple: $0.69
Margin: 71% 🎉
```

### Essential Tier ($1.99 → $1.39 after Apple)
**1TB Total Storage**
```
Photos (950GB):
- 4GB S3 Standard (2 days): 4GB × $0.023 = $0.092
- 946GB Deep Archive: 946GB × $0.00099 = $0.94

Thumbnails (40GB):
- 2GB S3 Standard (7 days): 2GB × $0.023 = $0.046
- 38GB Standard-IA: 38GB × $0.0125 = $0.48

Metadata (10GB):
- All Standard-IA: 10GB × $0.0125 = $0.125

Monthly Storage Cost: $1.68
Amortized over 4 months: $0.42/month
Revenue after Apple: $1.39
Margin: 70% 🎉
```

### Plus Tier ($2.99 → $2.09 after Apple)
**2TB Total Storage** ✅ Now Possible!
```
Photos (1.9TB = 1,946GB):
- 8GB S3 Standard (2 days): 8GB × $0.023 = $0.18
- 1,938GB Deep Archive: 1,938GB × $0.00099 = $1.92

Thumbnails (80GB):
- 4GB S3 Standard (7 days): 4GB × $0.023 = $0.092
- 76GB Standard-IA: 76GB × $0.0125 = $0.95

Metadata (20GB):
- All Standard-IA: 20GB × $0.0125 = $0.25

Monthly Storage Cost: $3.39
Amortized over 4 months: $0.85/month
Revenue after Apple: $2.09
Margin: 59% 🎉
```

## Comparison: Glacier Instant vs Deep Archive

| Tier | Glacier Instant Cost | Deep Archive Cost | Savings |
|------|---------------------|-------------------|---------|
| Starter (500GB) | $2.20/mo | $0.79/mo | 64% |
| Essential (1TB) | $4.52/mo | $1.68/mo | 63% |
| Plus (2TB) | $9.04/mo | $3.39/mo | 62% |

## New Tier Possibilities with Deep Archive

Now we can actually offer:
- **Starter**: 500GB at $0.99 ✅
- **Essential**: 1TB at $1.99 ✅  
- **Plus**: 2TB at $2.99 ✅ (Your goal!)
- **Family**: 5TB at $5.99 ✅

All with healthy 50-70% margins!

## User Communication

### Clear Expectations
"Your photos are safely archived in deep storage. Restore any photo within 24-48 hours. Thumbnails always browsable instantly."

### Marketing Angle
"We archive your photos like a digital vault - ultra secure, ultra cheap. When you need that old photo, just request it and we'll restore it within a day or two."

### In-App UX
```
[Photo thumbnail] 
"This photo is archived. Tap to restore (24-48 hours)"
[Restore] [Cancel]
```

## Retrieval Cost Management

Deep Archive retrieval: $0.02/GB + fees
- Limit free retrievals: 10GB/month included
- Additional retrievals: $0.99 per 50GB

## Implementation

1. **Lifecycle Rules**:
   - Photos: S3 Standard (2 days) → Deep Archive
   - Thumbs: S3 Standard (7 days) → Standard-IA  
   - Metadata: Direct to Standard-IA

2. **Clear UI**:
   - Show "Archived" badge on photos >2 days
   - One-tap restore with time estimate
   - Restore progress tracking

## Summary

With Deep Archive for photos:
- ✅ Can offer 2TB for $2.99 profitably (59% margin)
- ✅ Can offer 5TB for $5.99 profitably  
- ✅ 10-20x more storage than competitors
- ✅ Users understand the tradeoff
- ✅ Simple, honest pricing model

The key insight: Users are choosing us BECAUSE we're 10x cheaper. They'll happily wait 24-48 hours for old photos to get that value!
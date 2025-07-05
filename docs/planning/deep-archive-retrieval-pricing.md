# Deep Archive Retrieval Pricing Guide

## Overview

With our ultra-aggressive pricing strategy, photos automatically move to AWS Glacier Deep Archive after 14 days. This document explains the retrieval costs and options for users.

## AWS Deep Archive Retrieval Costs

### Retrieval Options

| Type | Time | Cost per GB | Request Cost | Best For |
|------|------|-------------|--------------|----------|
| **Bulk** | 48+ hours | $0.0025 | $0.025/1000 | Large batches, planning ahead |
| **Standard** | 12-48 hours | $0.02 | $0.10/1000 | Urgent needs |

### Additional Costs
- **Internet Transfer**: $0.09/GB (biggest cost component)
- **Total Cost Formula**: Retrieval fee + Transfer fee + Request fee
- **Pro tip**: Batch downloads save on transfer costs - retrieve albums, not individual photos

## Real-World Examples

### Single Photo (10MB)
```
Bulk:     $0.000025 + $0.0009 = ~$0.001
Standard: $0.0002 + $0.0009 = ~$0.001
Rounded up: $0.01 per photo
```

### Wedding Album (500 photos, 5GB)
```
Bulk (48+ hrs): $0.0125 + $0.45 = $0.46
Standard (12 hrs): $0.10 + $0.45 = $0.55
User price: $0.50-$1.00
```

### Year of Photos (5000 photos, 50GB)
```
Bulk: $0.125 + $4.50 = $4.63
Standard: $1.00 + $4.50 = $5.50
User price: $5-10
```

## User-Facing Pricing Strategy

### Simplified Pricing Tiers
- **Single photos**: $0.01 each
- **Small batches (<50)**: $0.50
- **Albums (50-500)**: $1-5
- **Large archives (500+)**: $5-50

### Monthly Retrieval Credits by Plan

| Plan | Monthly Price | Storage | Free Retrieval Credit |
|------|--------------|---------|---------------------|
| Free | $0 | 7.5GB | None |
| Starter | $0.99 | 250GB | $0.50 (50 photos) |
| Essential | $1.99 | 750GB | $2.00 (1 album) |
| Plus | $2.99 | 1.5TB | $5.00 (1 year) |
| Pro | $5.99 | 2.5TB | $10.00 (2 years) |

### Express Retrieval Option
- Not available directly from Deep Archive
- Workaround: Restore to S3 Standard first, then download
- Pricing: $0.99 flat fee for photos up to 100MB
- Larger requests: Standard retrieval recommended

## Cost Optimization Features

### 1. Smart Caching
- Retrieved photos stay accessible for 30 days
- No repeat charges during cache period
- Automatic re-archive after 30 days

### 2. Batch Retrieval Discounts
```
1-10 photos: Standard pricing
11-100 photos: 10% discount
101-1000 photos: 20% discount
1000+ photos: 30% discount
```

### 3. Predictive Retrieval (Premium Feature)
- Anniversary photos pre-retrieved automatically
- Holiday photos ready before events
- AI-based usage pattern detection
- Cost absorbed by Photolala as a premium feature
- Saves users from paying retrieval fees for predictable access

## Communication Strategy

### Clear Messaging
```
"Your photos from 2+ weeks ago are safely archived.
Retrieval options:
⚡ Express (3 hrs): $0.99 + data
⏱️ Standard (12 hrs): $0.02/GB
🐌 Economy (48 hrs): $0.0025/GB

Most users spend <$1/month on retrievals."
```

### In-App Examples
When user taps archived photo:
```
"This photo is archived for cost savings.
Retrieve just this photo ($0.01) or
the entire album of 127 photos ($0.50)?

[Single Photo] [Entire Album] [Learn More]
```

## Business Model Impact

### Break-Even Analysis
With 14-day Deep Archive strategy:
- Storage cost: $0.99/TB/month
- Average retrieval: 1-2GB/user/month
- Retrieval revenue: $0.50-$2.00/user
- Net positive for active users

### Margin Protection
1. Include base retrieval credits in paid plans
2. Bulk retrieval encouraged (better margins)
3. Cache retrieved content (reduce repeat costs)
4. Transfer via CloudFront (5% savings)

## Implementation Notes

### Technical Requirements
1. Clear archive status indicators in UI
2. Retrieval queue management system
3. Cost calculator before confirmation
4. Progress tracking for retrievals
5. Notification system for completion

### User Education
- Onboarding explains archive system
- First retrieval is guided
- Cost transparency throughout
- Savings calculator shows benefit

## Conclusion

Deep Archive retrieval adds complexity but enables our 90% cheaper pricing. By including retrieval credits, offering bulk discounts, and implementing smart caching, we can maintain excellent user experience while preserving our margins.

The key is transparency: users understand they're trading instant access for massive savings, with reasonable options when they need their older photos.

### Key Success Factors:
1. **Education**: Users understand the trade-off upfront
2. **Credits**: Included retrieval credits remove friction
3. **Batching**: Encourage album/year retrievals over single photos
4. **Caching**: 30-day cache prevents repeat charges
5. **Predictive**: Smart pre-retrieval for common access patterns
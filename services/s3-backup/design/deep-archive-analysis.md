# Analysis: Adding Deep Archive Tier for Very Old Photos

## Current Strategy
- Days 0-2: S3 Standard ($0.023/GB)
- Days 3+: Glacier Instant ($0.004/GB)

## Proposed Addition
- Days 0-2: S3 Standard ($0.023/GB)
- Days 3-365: Glacier Instant ($0.004/GB) 
- Days 366+: Deep Archive ($0.00099/GB)

## Cost Analysis

### 1TB Storage Example
Current approach (all in Glacier Instant after 2 days):
- 1000GB × $0.004 = $4.00/month

With Deep Archive for photos >1 year old:
- Assume 30% are >1 year old
- 700GB × $0.004 = $2.80 (Glacier Instant)
- 300GB × $0.00099 = $0.30 (Deep Archive)
- Total: $3.10/month
- **Savings: $0.90/month (22.5%)**

## Pros of Adding Deep Archive

1. **Cost Savings**: ~20-25% reduction in storage costs
2. **Better Margins**: Could improve profit margins significantly
3. **Logical**: Photos >1 year old are rarely accessed
4. **Scalable**: Bigger savings as users accumulate more old photos

## Cons of Adding Deep Archive

1. **UX Impact**: 
   - Glacier Instant: Millisecond retrieval
   - Deep Archive: 12-48 hour retrieval
   - Users might be frustrated waiting 2 days for old photos

2. **Complexity**:
   - More lifecycle rules to manage
   - More retrieval tiers to explain to support

3. **Retrieval Costs**:
   - Deep Archive retrieval: $0.02/GB + $0.0004/1000 requests
   - If users frequently retrieve old photos, costs add up

## User Behavior Considerations

### Likely Access Patterns
- 95% of access: Photos <30 days old
- 4% of access: Photos 30 days - 1 year old  
- 1% of access: Photos >1 year old

### But When They DO Access Old Photos
- Wedding photos from 3 years ago
- Baby's first birthday from 2 years ago
- Vacation memories from 5 years ago
- These are IMPORTANT moments - 2 day wait is painful

## Recommendation

**Option 1: Keep Current Strategy** ✅
- Simple: Everything goes to Glacier Instant
- Good UX: All photos retrievable quickly
- Profitable: Still maintaining ~20% margins

**Option 2: Add Deep Archive with Caveats**
- Only for photos >2 years old (not 1 year)
- Only for higher tiers (Essential/Plus/Family)
- Clearly communicate retrieval times

**Option 3: Intelligent Deep Archive** 
- Use ML/analytics to identify truly "cold" photos
- Photos with 0 access in 2+ years → Deep Archive
- Keep "milestone" photos (birthdays, holidays) in Glacier Instant

## Proposed Implementation (If We Proceed)

```
Starter ($0.99):
├── 0-2 days: S3 Standard
└── 3+ days: Glacier Instant (keep simple)

Essential ($1.99):
├── 0-2 days: S3 Standard  
├── 3-730 days: Glacier Instant
└── 731+ days: Deep Archive

Plus/Family ($2.99/$5.99):
├── 0-7 days: S3 Standard (longer hot period)
├── 8-730 days: Glacier Instant
└── 731+ days: Deep Archive
```

## Financial Impact

For Essential Tier (1TB):
- Current cost: $4.52/month
- With 30% in Deep Archive: $3.65/month
- Savings: $0.87/month
- New margin: 34% (up from 19%)

## Final Recommendation

**Start without Deep Archive** for MVP. Consider adding it later:
1. Launch with simple Glacier Instant only
2. Gather data on actual retrieval patterns
3. Add Deep Archive in v2 if retrieval of 2+ year photos is truly <1%
4. Market it as "Ultra Archive" for photos you rarely need

This keeps initial implementation simple while leaving room for cost optimization later.
# Deep Archive Retrieval Costs Analysis

## AWS S3 Glacier Deep Archive Pricing (us-east-1)

### Storage Cost
- **Storage**: $0.00099/GB/month (~$1/TB/month)

### Retrieval Costs
AWS charges for both the retrieval request AND data transfer:

#### Retrieval Options
1. **Standard** (12-48 hours)
   - Retrieval: $0.02/GB
   - Requests: $0.10 per 1,000 requests

2. **Bulk** (48+ hours) 
   - Retrieval: $0.0025/GB
   - Requests: $0.025 per 1,000 requests

3. **Expedited** (Not available for Deep Archive)
   - Must restore to Standard first, then retrieve

### Data Transfer Costs
- **To Internet**: $0.09/GB (first 10TB/month)
- **To EC2 in same region**: Free
- **CloudFront**: ~$0.085/GB

## Typical Use Case Calculations

### Use Case 1: Single Photo Retrieval
**Scenario**: Retrieve one 10MB photo

```
Standard Retrieval (12-48hr):
- Retrieval cost: 0.01GB × $0.02 = $0.0002
- Request cost: $0.10/1000 = $0.0001
- Transfer cost: 0.01GB × $0.09 = $0.0009
- Total: ~$0.001 (round up to $0.01 for UX)
```

**UX Display**: "$0.01"

### Use Case 2: Event Album (Wedding)
**Scenario**: 500 photos, average 10MB each = 5GB

```
Standard Retrieval:
- Retrieval cost: 5GB × $0.02 = $0.10
- Request cost: 500 × $0.0001 = $0.05
- Transfer cost: 5GB × $0.09 = $0.45
- Total: $0.60
```

**UX Display**: "$0.60"

### Use Case 3: Year of Photos
**Scenario**: 5,000 photos = 50GB

```
Bulk Retrieval (48hr, best value):
- Retrieval cost: 50GB × $0.0025 = $0.125
- Request cost: 5 × $0.025 = $0.125
- Transfer cost: 50GB × $0.09 = $4.50
- Total: $4.75

Standard Retrieval (faster):
- Retrieval cost: 50GB × $0.02 = $1.00
- Request cost: 5 × $0.10 = $0.50
- Transfer cost: 50GB × $0.09 = $4.50
- Total: $6.00
```

**UX Display**: "$4.75 (2-3 days) or $6.00 (1-2 days)"

### Use Case 4: Professional Archive
**Scenario**: Photo studio retrieving 500GB for client project

```
Bulk Retrieval:
- Retrieval cost: 500GB × $0.0025 = $1.25
- Request cost: ~$0.50
- Transfer cost: 500GB × $0.09 = $45.00
- Total: $46.75

Standard Retrieval:
- Retrieval cost: 500GB × $0.02 = $10.00
- Request cost: ~$5.00
- Transfer cost: 500GB × $0.09 = $45.00
- Total: $60.00
```

## Cost Optimization Strategies

### 1. CloudFront for Downloads
Instead of direct S3 transfer, use CloudFront:
- Reduces transfer cost by ~5%
- Provides faster global access
- Caches popular content

### 2. Batch Retrievals
Encourage users to retrieve in batches:
- Fewer API requests
- Can use Bulk tier for better rates
- More efficient processing

### 3. Temporary S3 Storage
After retrieval, keep in S3 Standard for 30 days:
- No repeated retrieval costs
- Users can download multiple times
- Auto-expire back to Deep Archive

### 4. Smart Caching
For Plus/Family tiers:
- Keep thumbnails of retrieved photos
- Cache frequently accessed metadata
- Predictive retrieval for events

## Simplified Pricing for Users

### Consumer-Friendly Pricing Model

Instead of complex AWS calculations, show simple pricing:

```
Single Photos: $0.01 each
Small Albums (< 50 photos): $0.50
Large Albums (50-500 photos): $1-5
Yearly Archives (5000+ photos): $10-50
```

### Retrieval Speed Options
```
Standard (2-3 days): Base price
Express (1-2 days): 1.5x price
Rush (12 hours): 3x price (via Standard tier)
```

### Bundle Pricing
```
Retrieve up to:
- 10 photos: $0.10
- 100 photos: $0.75 
- 500 photos: $2.50
- 1000 photos: $4.00
```

## Implementation Recommendations

### 1. Abstract the Complexity
Don't show users:
- Separate retrieval vs transfer costs
- Per-request charges
- Regional variations

Do show:
- Single, simple price
- Clear time expectations
- Bundle savings

### 2. Margin Considerations
Add 20-30% margin on retrieval costs to cover:
- Processing overhead
- Support costs
- Platform fees

### 3. Free Tier Benefits
Each paid tier includes monthly retrieval credits:
- Starter ($0.99): $0.50 credit
- Essential ($1.99): $2.00 credit  
- Plus ($3.99): $5.00 credit
- Family ($5.99): $10.00 credit

### 4. Retrieval Notifications
- Email when retrieval starts
- Push notification when ready
- Warning before re-archiving
- Monthly retrieval summary

## Example User Experience

```
Your Selection:
🖼️ Europe Trip 2018 (485 photos, 4.8GB)

Retrieval Options:
⏰ Express (24 hours) ......... $3.50
📦 Standard (2-3 days) ....... $2.00 ✓
🐌 Economy (3-5 days) ........ $1.25

Your Essential plan includes $2.00 in 
monthly credits. This retrieval is FREE!

[Retrieve Now] [Cancel]
```

## Key Takeaways

1. **Actual AWS costs are low** - Most retrievals under $5
2. **Transfer is the biggest cost** - Not the retrieval itself
3. **Batch retrievals are efficient** - Encourage album retrieval
4. **Simple pricing wins** - Hide AWS complexity from users
5. **Include credits in plans** - Makes paid tiers more attractive
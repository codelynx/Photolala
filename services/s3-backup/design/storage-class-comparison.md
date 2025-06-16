# AWS S3 Storage Class Comparison

## STANDARD vs STANDARD_IA vs DEEP_ARCHIVE

### Quick Comparison Table

| Feature | STANDARD | STANDARD_IA | DEEP_ARCHIVE |
|---------|----------|-------------|--------------|
| **Storage Cost** | $0.023/GB/mo | $0.0125/GB/mo | $0.00099/GB/mo |
| **Minimum Duration** | None | 30 days | 180 days |
| **Minimum Size** | None | 128KB | 40KB |
| **Retrieval Fee** | None | $0.01/GB | $0.02/GB + wait |
| **Access Time** | Instant | Instant | 12-48 hours |
| **Use Case** | Hot data | Cool data | Cold data |

### Detailed Breakdown

## STANDARD
**Best for**: Frequently accessed data
- **Cost**: $0.023/GB/month ($23/TB/month)
- **Access**: Milliseconds
- **Retrieval**: FREE
- **Durability**: 99.999999999% (11 9's)
- **Availability**: 99.99%
- **Minimum**: None

**When to use**:
- Thumbnails (always need instant access)
- Recent photos being actively viewed
- Catalog files
- Anything accessed multiple times per month

## STANDARD_IA (Infrequent Access)
**Best for**: Data accessed less than once a month
- **Cost**: $0.0125/GB/month ($12.50/TB/month) - 45% cheaper!
- **Access**: Milliseconds (same as STANDARD)
- **Retrieval**: $0.01/GB fee
- **Durability**: 99.999999999% (11 9's)
- **Availability**: 99.9%
- **Minimum**: 30 days charge, 128KB size

**When to use**:
- Photos 6 months to 2 years old
- Occasionally accessed archives
- Large files accessed infrequently
- Backup data you might need quickly

**Important**: You pay for 30 days minimum even if deleted earlier

## DEEP_ARCHIVE
**Best for**: Long-term retention
- **Cost**: $0.00099/GB/month ($0.99/TB/month) - 96% cheaper!
- **Access**: 12-48 hours wait
- **Retrieval**: $0.02/GB + time
- **Durability**: 99.999999999% (11 9's)
- **Availability**: 99.99% (after retrieval)
- **Minimum**: 180 days charge

**When to use**:
- Photos older than 2 years
- Compliance/legal archives
- "Backup and forget" data
- Rarely accessed memories

## Cost Examples for Photolala

### 1TB of Photos - Monthly Storage Cost
- **STANDARD**: $23.00
- **STANDARD_IA**: $12.50 (save $10.50)
- **DEEP_ARCHIVE**: $0.99 (save $22.01)

### Retrieval Costs (1GB)
- **STANDARD**: FREE
- **STANDARD_IA**: $0.01 + transfer
- **DEEP_ARCHIVE**: $0.02 + transfer + wait time

### Break-Even Analysis
**STANDARD vs STANDARD_IA**:
- Storage savings: $0.0105/GB/month
- Retrieval cost: $0.01/GB
- Break-even: Access less than once per month

**Example**: 100GB of photos
- STANDARD: $2.30/month
- STANDARD_IA: $1.25/month + retrieval fees
- If accessed < 10 times/month, IA is cheaper

## Photolala's Strategy

### Tiered Approach
1. **Thumbnails & Catalogs**: Always STANDARD
   - Need instant, frequent access
   - Small size makes cost negligible

2. **Recent Photos (< 6-12 months)**: STANDARD_IA
   - Instant access when needed
   - 45% storage savings
   - Small retrieval fee acceptable

3. **Old Photos (> 1-2 years)**: DEEP_ARCHIVE
   - 96% storage savings
   - Users rarely access old photos
   - Retrieval delay acceptable for memories

### Lifecycle Policy Example
```xml
<LifecycleConfiguration>
  <Rule>
    <ID>PhotoLifecycle</ID>
    <Status>Enabled</Status>
    <Transitions>
      <!-- After 6 months, move to IA -->
      <Transition>
        <Days>180</Days>
        <StorageClass>STANDARD_IA</StorageClass>
      </Transition>
      <!-- After 2 years, move to Deep Archive -->
      <Transition>
        <Days>730</Days>
        <StorageClass>DEEP_ARCHIVE</StorageClass>
      </Transition>
    </Transitions>
  </Rule>
</LifecycleConfiguration>
```

## Key Takeaways

1. **STANDARD_IA is the sweet spot** for photos 6-24 months old
   - 45% cheaper than STANDARD
   - Still instant access
   - Perfect for "might need it" photos

2. **Retrieval fees are minimal**
   - $0.01/GB = $0.10 for typical 10GB album
   - Much less than storage savings

3. **Lifecycle automation** reduces costs automatically
   - No manual management needed
   - Predictable cost reduction over time

4. **User experience remains good**
   - STANDARD_IA = instant (no wait)
   - Only DEEP_ARCHIVE has delays
   - Thumbnails always fast
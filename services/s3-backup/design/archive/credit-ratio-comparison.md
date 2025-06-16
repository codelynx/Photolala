# Credit Ratio Comparison

## Option A: 1 Credit = 1MB

### Monthly Credit Allocations
```
Tier Pricing & Credits:
- Starter ($0.99): 2,000 credits (2GB)
- Essential ($1.99): 5,000 credits (5GB)  
- Plus ($3.99): 10,000 credits (10GB)
- Family ($5.99): 20,000 credits (20GB)

Additional Credits (IAP):
- 1,000 credits (1GB): $0.99
- 5,000 credits (5GB): $3.99
- 10,000 credits (10GB): $6.99
- 50,000 credits (50GB): $24.99
```

### Typical Usage Examples
```
Photo Sizes & Credit Costs:
- iPhone photo (3MB): 3 credits
- DSLR JPEG (8MB): 8 credits
- RAW file (25MB): 25 credits
- Small album (500MB): 500 credits
- Wedding photos (5GB): 5,000 credits
- Year archive (50GB): 50,000 credits
```

### User Experience
```
┌─────────────────────────────────────┐
│ Retrieve Wedding Photos             │
├─────────────────────────────────────┤
│ 📸 312 photos (4,827MB)             │
│                                     │
│ Cost: 4,827 credits                 │
│ Your balance: 5,000 credits         │
│ After: 173 credits                  │
│                                     │
│ [Retrieve Now]                      │
└─────────────────────────────────────┘
```

### Pros
- Very precise billing
- Fair for all file sizes
- Easy math (1:1 ratio)
- No rounding issues

### Cons
- Large numbers (thousands)
- May feel "expensive" psychologically
- Need to explain MB to non-tech users

## Option B: 10 Credits = 1GB (Original Proposal)

### Monthly Credit Allocations
```
Tier Pricing & Credits:
- Starter ($0.99): 20 credits (2GB)
- Essential ($1.99): 50 credits (5GB)  
- Plus ($3.99): 100 credits (10GB)
- Family ($5.99): 200 credits (20GB)

Additional Credits (IAP):
- 10 credits (1GB): $0.99
- 50 credits (5GB): $3.99
- 100 credits (10GB): $6.99
- 500 credits (50GB): $24.99
```

### User Experience
```
┌─────────────────────────────────────┐
│ Retrieve Wedding Photos             │
├─────────────────────────────────────┤
│ 📸 312 photos (4.8GB)               │
│                                     │
│ Cost: 48 credits                    │
│ Your balance: 50 credits            │
│ After: 2 credits                    │
│                                     │
│ [Retrieve Now]                      │
└─────────────────────────────────────┘
```

### Pros
- Smaller, friendlier numbers
- Still GB-based (users understand)
- Clean pricing ($0.099/credit)

### Cons
- Need decimals for small retrievals
- Minimum retrieval = 1 credit (100MB)

## Option C: 1 Credit = 100MB (Hybrid)

### Monthly Credit Allocations
```
Tier Pricing & Credits:
- Starter ($0.99): 20 credits (2GB)
- Essential ($1.99): 50 credits (5GB)  
- Plus ($3.99): 100 credits (10GB)
- Family ($5.99): 200 credits (20GB)

Additional Credits (IAP):
- 10 credits (1GB): $0.99
- 50 credits (5GB): $3.99
- 100 credits (10GB): $6.99
- 500 credits (50GB): $24.99
```

### Typical Usage
```
- Single photo (5MB): 0.05 → 1 credit (minimum)
- 10 photos (50MB): 1 credit  
- Album (500MB): 5 credits
- Wedding (4.8GB): 48 credits
```

### User Experience
```
┌─────────────────────────────────────┐
│ Smart Retrieval Suggestion          │
├─────────────────────────────────────┤
│ You selected 8 photos (47MB)        │
│                                     │
│ 💡 Add 2 more photos to maximize    │
│    your 1 credit (up to 100MB)      │
│                                     │
│ [Add Suggestions] [Retrieve Now]    │
└─────────────────────────────────────┘
```

## Recommendation: 1 Credit = 100MB

### Why This Works Best

1. **Goldilocks Numbers**
   - Not too big (1MB = thousands)
   - Not too small (1GB = decimals)
   - Just right (100MB = clean math)

2. **Smart Bundling**
   - Encourage 100MB batches
   - Minimize waste
   - Natural album sizes

3. **Pricing Simplicity**
   - 1 credit = $0.099 (IAP)
   - 10 credits = $0.99
   - Clean tiers

4. **User Psychology**
   - 50 credits feels substantial
   - Single photos round up to 1
   - Albums use reasonable amounts

### Implementation Example
```swift
func calculateCredits(for bytes: Int64) -> Int {
    let megabytes = bytes / (1024 * 1024)
    let hundredMBBlocks = megabytes / 100
    
    // Round up to nearest 100MB block
    return max(1, Int(ceil(Double(megabytes) / 100.0)))
}

// Examples:
// 5MB photo → 1 credit
// 95MB album → 1 credit  
// 105MB album → 2 credits
// 4.8GB wedding → 48 credits
```

### Marketing Message
"Simple pricing: 1 credit = up to 100MB of photos. Most albums use just 5-10 credits. Your Essential plan includes 50 credits monthly - enough for 5GB of memories!"
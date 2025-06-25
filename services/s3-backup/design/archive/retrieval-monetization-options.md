# Retrieval Monetization Options

## The Challenge
- Apple subscriptions make per-retrieval charges difficult
- AWS retrieval costs are real and can add up
- Need a user-friendly system that covers costs

## Option 1: Photo Credits System (Recommended)

### How it Works
- Monthly credits included with each tier
- Credits roll over (up to 3 months)
- Purchase additional credits via IAP

### Credit Pricing
```
Subscription Credits (Monthly):
- Starter: 50 credits
- Essential: 200 credits  
- Plus: 500 credits
- Family: 1000 credits

Credit Usage:
- 1 photo = 1 credit
- Small album (< 50) = 50 credits
- Large album (50-500) = 100-500 credits
- Express delivery = 2x credits

Additional Credits (IAP):
- 100 credits: $0.99
- 500 credits: $3.99
- 1000 credits: $6.99
```

### User Experience
```
┌─────────────────────────────────────┐
│ Retrieve Europe Trip (485 photos)   │
├─────────────────────────────────────┤
│                                     │
│ Cost: 485 credits                   │
│                                     │
│ Your balance: 650 credits           │
│ After retrieval: 165 credits        │
│                                     │
│ [Retrieve Now] [Get More Credits]   │
└─────────────────────────────────────┘
```

## Option 2: Retrieval Passes

### Monthly Pass Types
- **Basic Pass**: Included with subscription
- **Premium Pass**: $4.99/month add-on
- **Unlimited Pass**: $9.99/month add-on

### Pass Benefits
```
Basic (Included):
- Standard speed only
- Up to 100GB/month
- Single album at a time

Premium ($4.99):
- Express speed available
- Up to 500GB/month
- Multiple concurrent retrievals

Unlimited ($9.99):
- Unlimited retrievals
- Fastest speed
- Bulk operations
- API access
```

## Option 3: Storage Boost Bundles

### Concept
Instead of charging for retrieval, offer "Quick Access" storage upgrades

### Bundles
```
Quick Access Boost:
- 50GB for 3 months: $2.99
- 100GB for 3 months: $4.99
- 200GB for 3 months: $7.99

How it works:
- Moves photos from Deep Archive to STANDARD_IA
- No retrieval delays for 3 months
- Auto-archives after expiration
```

### User Story
"Your wedding photos are archived. Get instant access for the next 3 months for just $2.99"

## Option 4: Smart Retrieval Tokens

### Token System
- Each retrieval requires 1 token
- Tokens included monthly, don't expire
- Batch retrievals get token discounts

### Token Distribution
```
Monthly Tokens:
- Starter: 5 tokens
- Essential: 20 tokens
- Plus: 50 tokens
- Family: Unlimited

Token Usage:
- Single photo: FREE (no token)
- Album < 50 photos: 1 token
- Album 50-500: 2 tokens
- Album 500+: 5 tokens
- Express: 2x tokens

Buy Tokens (IAP):
- 10 tokens: $1.99
- 50 tokens: $7.99
- 100 tokens: $12.99
```

## Option 5: Activity-Based Rewards

### Earn Credits Through Usage
- Upload 100 photos: +10 credits
- Share album: +5 credits
- Invite friend: +50 credits
- Write review: +100 credits
- Annual renewal: +500 credits

### Gamification
```
┌─────────────────────────────────────┐
│ 🏆 Earn Retrieval Credits           │
├─────────────────────────────────────┤
│                                     │
│ ✓ Upload this month      +10       │
│ ✓ Organize 5 albums     +25       │
│ ○ Invite 3 friends      +150      │
│ ○ Leave a review        +100      │
│                                     │
│ Your credits: 235 🪙                │
└─────────────────────────────────────┘
```

## Option 6: Hybrid Subscription Tiers

### Reframe Tiers Around Retrieval
```
Archive ($0.99/mo):
- 100GB storage
- Archive-only (no quick access)
- Pay-per-retrieval via IAP

Active ($1.99/mo):
- 200GB storage  
- 50GB quick access
- 200 retrieval credits/mo

Power ($3.99/mo):
- 500GB storage
- 200GB quick access
- Unlimited retrievals
```

## Recommended Approach: Photo Credits

### Why Credits Work Best

1. **Simple Mental Model**
   - 1 credit = 1 photo (easy to understand)
   - Albums show credit cost upfront

2. **Flexible Monetization**
   - Included credits cover normal use
   - Power users can buy more
   - Rollover prevents waste

3. **Apple Compliance**
   - Credits as consumable IAP is standard
   - Clean subscription + IAP model
   - No payment friction

4. **Predictable Costs**
   - Users control retrieval spending
   - Subscription covers typical usage
   - Clear upgrade path

### Implementation Example
```swift
// Credit costs
let creditCosts = [
    .singlePhoto: 1,
    .smallAlbum: 50,
    .largeAlbum: 200,
    .yearArchive: 1000
]

// Subscription credits
let monthlyCredits = [
    .starter: 50,
    .essential: 200,
    .plus: 500,
    .family: 1000
]

// IAP products
let creditPacks = [
    "com.photolala.credits.small": 100,    // $0.99
    "com.photolala.credits.medium": 500,   // $3.99
    "com.photolala.credits.large": 1000    // $6.99
]
```

### Marketing Angle
"Never worry about retrieval costs! Your Essential plan includes 200 photo credits monthly - enough to retrieve 4 albums or 200 individual photos. Credits roll over up to 3 months!"

## Alternative Names for Credits
- Photo Credits ✓
- Retrieval Points
- Access Tokens
- Photo Coins
- Memory Points
- Archive Keys
- Recall Credits
- Photo Passes
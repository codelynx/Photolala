# Family & Group Deep Archive UX

## Core Challenges

1. **Who pays for retrieval?** - Credit ownership
2. **Who decides to archive?** - Permission levels
3. **Notification chaos** - Multiple people thawing
4. **Credit sharing** - Family pool vs individual

## Family Structure

### Family Roles
```
👨 Dad (Organizer)
├── 👩 Mom (Adult)
├── 👦 Teen Son (Member)
└── 👧 Young Daughter (Viewer)
```

### Permissions by Role
| Action | Organizer | Adult | Member | Viewer |
|--------|-----------|--------|---------|---------|
| View archived photos | ✅ | ✅ | ✅ | ✅ |
| Thaw photos | ✅ | ✅ | ✅ | ❌ |
| Use family credits | ✅ | ✅ | ❓ | ❌ |
| Star own photos | ✅ | ✅ | ✅ | ❌ |
| Star others' photos | ❌ | ❌ | ❌ | ❌ |
| Manage settings | ✅ | ❌ | ❌ | ❌ |

## Use Case 1: Family Vacation Photos

### Scenario: 2019 Hawaii Trip (500 photos) Now Archived

#### Mom Wants to Create Photo Book
```
┌─────────────────────────────────────┐
│   Hawaii 2019 - Family Album        │
│   500 photos ❄️ (Archived)          │
├─────────────────────────────────────┤
│                                     │
│  Mom wants to thaw these photos     │
│                                     │
│  Cost: 50 credits                   │
│  Johnson Family credits: 180 🪙     │
│                                     │
│  ⚠️ This will notify all family     │
│     members when ready              │
│                                     │
│  [Use Family Credits] [Use My Own]  │
└─────────────────────────────────────┘
```

#### Family Activity Feed
```
📋 Johnson Family Activity

👩 Mom is thawing Hawaii 2019 (50 credits)
   ⏳ Ready in ~24 hours

👦 Alex starred 15 photos from Christmas 2023
   ⭐ These won't archive

👨 Dad retrieved Wedding Anniversary 2010
   ✨ Available for 28 more days
```

## Use Case 2: Preventing Duplicate Thaws

### Smart Coordination
```
Teen son tries to thaw same album:

┌─────────────────────────────────────┐
│   ℹ️ Already Thawing                │
├─────────────────────────────────────┤
│                                     │
│  Mom is already thawing these       │
│  photos (started 2 hours ago)       │
│                                     │
│  ⏱️ Ready in: ~22 hours             │
│                                     │
│  You'll be notified when ready!     │
│                                     │
│  [OK] [View Other Albums]           │
└─────────────────────────────────────┘
```

## Use Case 3: Credit Management

### Family Credit Pool
```
┌─────────────────────────────────────┐
│   Johnson Family Credits            │
├─────────────────────────────────────┤
│                                     │
│  Monthly Allowance: 200 🪙          │
│  Used this month: 145 🪙            │
│  ■■■■■■■□□□ 55 credits left        │
│                                     │
│  Recent Usage:                      │
│  👩 Mom: 50 (Hawaii photos)         │
│  👨 Dad: 80 (Old home videos)       │
│  👦 Alex: 15 (School project)       │
│                                     │
│  [Buy More] [Set Limits]            │
└─────────────────────────────────────┘
```

### Individual Limits (Optional)
```
Set Monthly Limits:
👩 Mom: Unlimited
👨 Dad: Unlimited  
👦 Alex: 50 credits/month
👧 Emma: View only (no credits)
```

## Use Case 4: Star Ownership

### Simple Rule: Only Photo Owner Can Star
```
┌─────────────────────────────────────┐
│   Hawaii Sunset.jpg                 │
├─────────────────────────────────────┤
│                                     │
│  📸 Photo by: Mom                   │
│  ⭐ Starred (won't archive)         │
│                                     │
│  Only Mom can star/unstar this      │
│                                     │
│  [View Photo]                       │
└─────────────────────────────────────┘
```

### Family Member Wants It Starred
```
┌─────────────────────────────────────┐
│   Request Star                      │
├─────────────────────────────────────┤
│                                     │
│  This is Mom's photo.               │
│  Would you like to:                 │
│                                     │
│  💬 Ask Mom to star it              │
│  📋 Copy to your library & star     │
│                                     │
│  [Send Request] [Make Copy]         │
└─────────────────────────────────────┘
```

## Use Case 5: Shared Albums

### Mixed Archive States
```
Summer BBQ 2023 (Shared with Grandparents)

Your photos: 45 ❄️ (archived)
Grandma's photos: 30 (active)
Grandpa's photos: 20 ❄️ (archived)

[Thaw All - 65 credits] [Thaw Mine - 45]
```

## Smart Family Features

### 1. Thaw Coordination
```
🎄 Dad started thawing Christmas photos!

Would you like to add your requests?
□ Christmas 2022 (30 photos)
□ Christmas 2021 (45 photos)
□ New Year 2023 (20 photos)

[Add to Dad's Request] [Thaw Separately]
```

### 2. Credit Warnings
```
⚠️ Low Family Credits

You have 10 credits left this month.
Mom is about to use 50 credits.

[Buy More] [Postpone] [Use Anyway]
```

### 3. Batch Family Events
```
📅 Upcoming: Grandma's 80th Birthday

Suggested photos to thaw:
• Grandma's 70th Party (120 photos)
• Family Reunions (340 photos)
• Grandma's Favorites (45 photos)

[Thaw All - 50 credits] [Select Items]
```

## Implementation Details

### Database Schema
```sql
-- Family thaw requests
CREATE TABLE family_thaw_requests (
    id UUID PRIMARY KEY,
    family_id UUID NOT NULL,
    initiated_by UUID NOT NULL,
    photos JSONB NOT NULL,  -- Array of MD5s
    credits_used INTEGER,
    status VARCHAR(20),
    created_at TIMESTAMP
);

-- Credit usage tracking
CREATE TABLE family_credit_usage (
    family_id UUID NOT NULL,
    user_id UUID NOT NULL,
    credits_used INTEGER,
    purpose VARCHAR(100),
    timestamp TIMESTAMP
);

-- Simple star tracking (owner only)
-- Stars are stored with the photo metadata
-- No separate star table needed!
```

### Notification Strategy
```python
def notify_family_thaw_complete(family_id, photos, initiated_by):
    family_members = get_family_members(family_id)
    initiator = get_user(initiated_by)
    
    for member in family_members:
        if member.notification_prefs.family_thaws:
            send_notification(
                to=member,
                title=f"{initiator.name}'s photos are ready!",
                body=f"{len(photos)} family photos retrieved",
                action="view_photos"
            )
```

## Best Practices

### For Families
1. **Organizer manages credits** - One person pays
2. **Coordinate big thaws** - Avoid duplicates
3. **Star family favorites** - Keep accessible
4. **Set youth limits** - Prevent credit drain

### For Groups (Friends/Clubs)
1. **Pay-per-use model** - Each pays their share
2. **Request approval** - For expensive thaws
3. **Shared starred albums** - Common favorites
4. **Activity transparency** - See who uses what

## Privacy Considerations

### What Family Can See
- ✅ Which photos are archived/thawing
- ✅ Who initiated thaws
- ✅ Credit usage by person
- ❌ Private albums (unless shared)
- ❌ Individual browsing history

This creates a collaborative yet controlled environment for families!
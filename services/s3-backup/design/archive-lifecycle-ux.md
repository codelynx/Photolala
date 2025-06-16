# Archive Lifecycle UX Design

## Photo Lifecycle Journey

### Day 0-180: Fresh Photo
```
┌─────────────┐
│    📷      │  ← Normal photo
│            │  ← Instant access
│  Beach.jpg │  ← No badges
└─────────────┘
```

### Day 181+: Auto-Archived
```
┌─────────────┐
│    📷 ❄️   │  ← Frozen badge appears
│  (dimmed)  │  ← Slightly dimmed
│  Beach.jpg │  ← Still browsable via thumbnail
└─────────────┘
```

### User Taps Frozen Photo
```
┌──────────────────────────────────────┐
│          📷 Beach.jpg               │
│                                      │
│         ❄️ Archived Photo            │
│                                      │
│   This photo was auto-archived       │
│   after 6 months to save costs.      │
│                                      │
│   ┌────────────────────────────┐     │
│   │   🔥 Thaw Photo            │     │
│   └────────────────────────────┘     │
│                                      │
│   ┌────────────────────────────┐     │
│   │   ⭐ Keep Always Available │     │
│   └────────────────────────────┘     │
└──────────────────────────────────────┘
```

## Thawing Process

### 1. User Initiates Thaw
```
┌──────────────────────────────────────┐
│      Thawing Your Photo... ❄️→🔥      │
├──────────────────────────────────────┤
│                                      │
│   Estimated time: 12-48 hours        │
│                                      │
│   ⏱️ Started: Jan 20, 2:30 PM        │
│   📅 Ready by: Jan 21, 2:30 PM       │
│                                      │
│   ✓ We'll notify you when ready     │
│                                      │
│   💡 Tip: Thaw multiple photos       │
│      together to save credits        │
│                                      │
│   [Thaw More Photos] [Done]          │
└──────────────────────────────────────┘
```

### 2. During Thaw (Grid View)
```
┌─────────────┐
│    📷 ⏳   │  ← Thawing spinner
│ (pulsing)  │  ← Gentle pulse animation
│  Beach.jpg │  ← "12h remaining" on hover
└─────────────┘
```

### 3. Ready Notification
```
🔔 Push Notification:
"Your photos are ready! Beach.jpg and 3 
others have been retrieved from archive."

📧 Email:
Subject: Your archived photos are ready!
Beach.jpg and 3 other photos have been 
retrieved. They'll remain available for 
30 days before re-archiving.
```

### 4. Retrieved State
```
┌─────────────┐
│    📷 ✨   │  ← Sparkle badge (temporary)
│            │  ← Full brightness
│  Beach.jpg │  ← "29 days left" on hover
└─────────────┘

Badge meanings:
✨ = Recently retrieved (fades after 3 days)
📍 = Pinned for 30 days
⭐ = Starred (never archives)
```

## Visual States Reference

| State | Icon | Appearance | Interaction |
|-------|------|------------|-------------|
| Fresh | None | Normal | Instant access |
| Archived | ❄️ | Dimmed 80% | Tap to thaw |
| Thawing | ⏳ | Pulsing | Show progress |
| Ready | ✨ | Bright + sparkle | Download now |
| Expiring | ⚠️ | Yellow tint | 7 days warning |
| Starred | ⭐ | Normal + star | Never archives |

## Smart Batching UI

### When User Selects Multiple Archived Photos
```
┌──────────────────────────────────────┐
│    Thaw Multiple Photos Together     │
├──────────────────────────────────────┤
│                                      │
│  Selected: 15 photos (150MB)         │
│  Cost: 15 credits                    │
│                                      │
│  💡 Smart suggestion:                │
│  You also have 8 photos from the     │
│  same event. Thaw them together?     │
│                                      │
│  □ Beach Day - Morning (8 photos)    │
│                                      │
│  Total: 23 photos (23 credits)       │
│                                      │
│  [Thaw Selected] [Add Suggested]     │
└──────────────────────────────────────┘
```

## Timeline Visualization

### Photo Info View
```
┌──────────────────────────────────────┐
│         Photo Timeline               │
├──────────────────────────────────────┤
│                                      │
│  Uploaded: Jan 20, 2024              │
│     │                                │
│     ├─── 6 months ──→ Archived      │
│     │                  Jul 20, 2024  │
│     │                                │
│     └─── Retrieved ──→ Dec 15, 2024 │
│           │                          │
│           └─ 30 days → Re-archives  │
│                        Jan 14, 2025  │
│                                      │
│  [⭐ Star to Keep Available]         │
└──────────────────────────────────────┘
```

## Settings & Preferences

```
Archive Settings:

Auto-Archive After:
○ 3 months (save more 💰)
● 6 months (default)
○ 1 year (convenience)
○ Never (costs more 💸)

Smart Archive:
☑️ Keep starred photos available
☑️ Keep recent favorites (last 10 viewed)
☐ Archive by folder rules

Notifications:
☑️ Notify when photos are archived
☑️ Notify when retrieval completes
☑️ Weekly archive summary
```

## Cost Transparency

### During Thaw Selection
```
Your Credits This Month:
■■■■■■□□□□ 32 of 50 used

This retrieval: 15 credits
After retrieval: 17 credits remaining

Need more? Buy 50 credits for $3.99
```

## Implementation Notes

### Badge Priority (Only Show One)
```swift
enum PhotoBadge {
    case starred      // ⭐ Highest priority
    case thawing      // ⏳ 
    case retrieved    // ✨ (temporary)
    case expiring     // ⚠️
    case archived     // ❄️ Lowest priority
}
```

### Animation Suggestions
- **Archived**: Subtle blue tint
- **Thawing**: Gentle pulse (0.5s)
- **Retrieved**: Sparkle fade-in
- **Expiring**: Yellow warning pulse

This creates a clear, intuitive flow that makes archiving feel like a smart feature rather than a limitation!
# Game Industry Identity Management Patterns

## Overview

The gaming industry has developed mature patterns for handling identity management across platforms, purchases, and accounts. This document examines successful approaches used by major games.

## Common Game Identity Patterns

### 1. **Supercell Model** (Clash of Clans, Clash Royale)
**Pattern**: Supercell ID with Device Transfer

```
Device → Anonymous Play → Optional Supercell ID → Linked Purchases
```

**Key Features:**
- Start playing immediately (no sign-in required)
- Create Supercell ID anytime to save progress
- Device transfer via unique code
- Purchases tied to Supercell ID once linked

**User Experience:**
```
1. Download game → Play immediately
2. After investment → "Save your village!"
3. Create Supercell ID (email-based)
4. Purchases now tied to ID, not device
```

**Handling Conflicts:**
- Shows both accounts: "Device Save" vs "Supercell ID Save"
- User chooses which to keep
- Clear warnings about overwriting

### 2. **Epic Games Model** (Fortnite)
**Pattern**: Account-First with Platform Linking

```
Epic Account (Required) → Link Platform Accounts → Merged Purchases
```

**Key Features:**
- Epic account required from start
- Link multiple platforms (PSN, Xbox, Switch, Apple)
- V-Bucks (currency) platform-specific vs shared
- Cross-progression everywhere

**Purchase Handling:**
```swift
struct EpicAccount {
    let epicID: String
    let linkedAccounts: [PlatformAccount]
    let sharedVBucks: Int      // Purchased on Epic/PC
    let platformVBucks: [Platform: Int]  // Platform-specific
}
```

### 3. **Pokémon GO Model** (Niantic)
**Pattern**: Multiple Login Providers

```
Choose Login Method → Google/Facebook/Apple/Pokemon Trainer Club
```

**Key Features:**
- Multiple auth providers
- Can link additional providers later
- One account can have multiple login methods
- Purchases follow the account

**Identity Linking:**
```
Primary: Google → Add Facebook → Add Apple ID
All three methods access same game account
```

### 4. **Genshin Impact Model** (miHoYo)
**Pattern**: Custom Account with Platform Bypass

```
miHoYo Account ←→ Platform Purchases
      ↓
Cross-Platform Progress
```

**Key Features:**
- Optional miHoYo account
- Can link after playing
- Platform purchases work without account
- Account enables cross-platform

**Smart Approach:**
- iOS purchases work without miHoYo account
- But you need account for PC/Android sync
- Gentle push towards account creation

### 5. **Call of Duty Mobile Model**
**Pattern**: Activision ID with Guest Option

```
Guest Mode → Progress at Risk → Create Activision ID → Permanent Save
```

**Implementation:**
```swift
enum PlayerState {
    case guest(deviceID: String)
    case linked(activisionID: String, platforms: [Platform])
    
    var canPurchase: Bool {
        switch self {
        case .guest: return true  // But risky!
        case .linked: return true
        }
    }
    
    var warningMessage: String? {
        switch self {
        case .guest: 
            return "⚠️ Your progress is only saved on this device"
        case .linked: 
            return nil
        }
    }
}
```

## Purchase Conflict Resolution Patterns

### Pattern 1: **Account Lock** (Supercell)
Once purchases are made, they're locked to the account that made them:

```swift
func handlePurchaseRestore(receipt: Receipt) {
    if receipt.accountID != currentUser.id {
        showError("This purchase belongs to another account")
        // No transfer possible
    }
}
```

### Pattern 2: **Platform Priority** (PlayStation)
Platform purchases stay with platform account:

```
PSN Purchase → Available on any device with PSN login
Apple Purchase → Only on Apple devices with same Apple ID
```

### Pattern 3: **Merge on First Link** (Fortnite)
When linking accounts for the first time:

```swift
func linkAccounts(primary: Account, secondary: Account) {
    if secondary.hasPurchases && primary.hasPurchases {
        showWarning("Secondary account items will be lost")
    } else {
        // Merge items to primary
        primary.items.append(contentsOf: secondary.items)
    }
}
```

## Best Practices from Games

### 1. **Progressive Account Creation**

```swift
enum UserJourney {
    case newPlayer
    case invested(hoursPlayed: Int, purchases: Bool)
    case connected(accountType: AccountType)
    
    var promptForAccount: Bool {
        switch self {
        case .newPlayer: 
            return false  // Let them play
        case .invested(let hours, let purchases):
            return hours > 2 || purchases  // Time to save
        case .connected: 
            return false  // Already done
        }
    }
}
```

### 2. **Clear Visual Communication**

**Clash Royale Example:**
```
┌─────────────────────────┐
│  ⚠️ LOAD GAME?         │
├─────────────────────────┤
│ Device:                 │
│ 👑 Level 13            │
│ 🏆 5,231 Trophies      │
│                         │
│ Supercell ID:          │
│ 👑 Level 8             │
│ 🏆 2,100 Trophies      │
├─────────────────────────┤
│ [Load Device] [Load ID] │
└─────────────────────────┘
```

### 3. **Purchase Warning System**

```swift
func showPurchaseWarning(for state: PlayerState) -> String? {
    switch state {
    case .guest:
        return """
        ⚠️ Save your game first!
        
        You're playing as a guest. Create a free 
        account to secure your purchases and progress.
        
        [Create Account] [Purchase Anyway]
        """
    case .linked:
        return nil
    }
}
```

### 4. **Recovery Mechanisms**

**Customer Support Integration:**
```swift
struct SupportTicket {
    let issueType: IssueType
    let receipts: [Receipt]
    let deviceInfo: DeviceInfo
    let accountHistory: [AccountEvent]
    
    enum IssueType {
        case lostAccount
        case purchaseOnWrongAccount
        case cannotRestore
        case accountCompromised
    }
}
```

## Implementation Recommendations for Photolala

Based on game industry patterns, here's what would work well:

### 1. **Hybrid Approach** (Supercell + Genshin)

```swift
class PhotolalaIdentityFlow {
    enum State {
        case anonymous(deviceID: String)
        case signedIn(appleID: String, serviceID: String)
    }
    
    func userFlow() {
        // 1. Allow immediate use (browse photos)
        // 2. Require sign-in for cloud features
        // 3. Progressive prompts based on usage
        // 4. Lock purchases to accounts
    }
}
```

### 2. **Visual Account State**

```
┌─────────────────────────────┐
│ 📱 Device Storage Only      │
│ ☁️ Sign in for Cloud Backup │
└─────────────────────────────┘

After Sign-in:
┌─────────────────────────────┐
│ ☁️ user@example.com         │
│ ✅ 1,234 photos backed up   │
│ 📊 2.3 GB used              │
└─────────────────────────────┘
```

### 3. **Progressive Nudges**

```swift
struct AccountPrompt {
    static func shouldPrompt(usage: AppUsage) -> Bool {
        return usage.photosViewed > 100 ||
               usage.sessionsCount > 5 ||
               usage.daysUsed > 3
    }
    
    static var message: String {
        """
        Love Photolala? ❤️
        
        Create a free account to:
        • Back up photos to cloud
        • Access from any device
        • Never lose your memories
        
        [Sign in with Apple] [Maybe Later]
        """
    }
}
```

## Lessons Learned

### DO (from successful games):
- ✅ Let users try before requiring accounts
- ✅ Show clear before/after states
- ✅ Make account benefits obvious
- ✅ Provide guest → account upgrade path
- ✅ Use visual indicators for account state

### DON'T (from game failures):
- ❌ Force sign-in immediately
- ❌ Allow purchase transfers between accounts
- ❌ Hide account state from users
- ❌ Make recovery impossible
- ❌ Overcomplicate the flow

## Conclusion

The game industry has proven that the best approach is:

1. **Start Simple**: Let users experience value first
2. **Progressive Complexity**: Add accounts when users are invested
3. **Clear Communication**: Always show what account they're using
4. **No Surprises**: Purchases stay with purchasing account
5. **Easy Recovery**: Support can help with proof of purchase

For Photolala, I recommend the **Supercell model**: anonymous start, optional account creation, with clear benefits for signing in, and purchases locked to accounts once created.
# Account Linking UX Design

## Overview

This document outlines the user experience design decisions for the account linking feature in Photolala, specifically focusing on managing multiple sign-in methods.

## User Scenarios

### 1. Switching Provider Accounts
**Scenario**: User wants to switch from work Google account to personal Google account
- **Current Solution**: Two-step process - Unlink then Link
- **Flow**:
  1. Click "Unlink" next to current Google account
  2. Confirm unlinking in dialog
  3. Click "Link Another Sign-In Method"
  4. Choose Google and sign in with different account

### 2. Security Concerns
**Scenario**: User's Google account was compromised
- **Need**: Immediately revoke access for that provider
- **Solution**: Unlink button immediately removes access
- **Result**: Can still sign in with remaining providers (e.g., Apple)

### 3. Simplification
**Scenario**: User wants only one sign-in method
- **Need**: Remove unnecessary providers
- **Solution**: Unlink all except preferred provider
- **Constraint**: Cannot unlink last remaining provider

### 4. Mistaken Account Linking
**Scenario**: User accidentally linked wrong account
- **Need**: Fix the mistake
- **Solution**: Unlink wrong account, then link correct one

## Design Decisions

### Why Not "Switch Account"?

We considered adding a "Switch Account" button but decided against it because:

1. **Clarity**: Two separate actions (unlink + link) are clearer than one combined action
2. **Flexibility**: User might want to unlink without immediately relinking
3. **Error Recovery**: If unlinking succeeds but linking fails, user state is clear
4. **Simplicity**: Reuses existing UI components without special flows

### Unlink Behavior

When a user unlinks a provider:

1. **Local State**: Remove provider from user's linked providers list
2. **S3 State**: Delete identity mapping (e.g., `identities/google:USER_ID`)
3. **Immediate Effect**: Provider cannot be used for sign-in immediately
4. **Re-linking**: Same or different account can be linked later

### UI Components

#### Current Provider Display
```
Google                    [Unlink]
Linked on Jul 30, 2024
```

#### After Unlinking
```
[Link Another Sign-In Method]
```

#### Confirmation Dialog
```
Title: "Unlink Google Account?"
Message: "You'll no longer be able to sign in with your Google 
         account (email@example.com). You can always link it 
         again later."
Actions: [Cancel] [Unlink]
```

## Implementation Requirements

### Complete Unlinking
- Remove from local user data ✓
- Delete S3 identity mapping ✓
- Update UI immediately ✓
- Show success feedback ✓

### Constraints
- Cannot unlink primary provider if it's the only one
- Must maintain at least one sign-in method
- Unlinking is immediate and complete

## Future Considerations

### Potential Enhancements
1. **Audit Trail**: Log when providers were linked/unlinked
2. **Grace Period**: Temporarily disable instead of immediate deletion
3. **Bulk Management**: Unlink multiple providers at once

### Rejected Ideas
1. **"Switch Account" Button**: Too complex, unclear
2. **"Pause" Provider**: Adds unnecessary state management
3. **Automatic Re-linking**: Could be security risk

## Best Practices

1. **Always Confirm**: Destructive actions need confirmation
2. **Clear Consequences**: Tell user exactly what will happen
3. **Immediate Feedback**: Show success/failure immediately
4. **Allow Recovery**: User can always link again if needed
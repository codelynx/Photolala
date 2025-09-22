# Account Linking Design

## Overview

Account linking allows users to add additional authentication providers to their existing account. Account merging (consolidating two existing accounts) is not supported due to complexity.

**Key Decision: No Account Merge Support**
- Users can link additional providers ONLY if those providers have no existing account
- If provider already has an account, linking is blocked
- No data migration between accounts

## Scenarios

### Scenario 1: Simple Link (No Existing Account)

**Alice's Story:**
1. Alice signs up with Apple ID → Creates Account A (UUID-1)
2. Later, Alice wants to add Google Sign-In for convenience
3. Google ID has no existing mapping in `identities/google/*`
4. System creates: `identities/google/{google-id}` → UUID-1
5. **Result**: Single account accessible via both providers

**Implementation**: Straightforward - Lambda adds new identity mapping

### Scenario 2: Blocked Link (Provider Already Has Account)

**Alice's Story:**
1. Alice signs up with Apple ID on iPhone → Account A (UUID-1)
2. Alice signs up with Google ID on Android → Account B (UUID-2)
3. Alice signs in with Apple ID, tries to link Google
4. System detects Google ID already maps to different UUID
5. **Linking is BLOCKED**

**Detection Flow:**
```
User signed in as: UUID-1 (via Apple)
Attempting to link: Google ID
Check: identities/google/{google-id} exists?
Found: Maps to UUID-2 (different account!)
Action: BLOCK LINKING - Show error message
```

**User Message:**
"This Google account is already associated with another Photolala account.
 Please use a different Google account or continue using your accounts separately."

## Why Account Linking Has Restrictions

### The Simple Rule

**Linking is allowed ONLY when:**
- The target provider (Apple/Google) has no existing account
- No UUID mapping exists for that provider ID

**Linking is blocked when:**
- The provider already has an account (different UUID)
- Would require merging data from two accounts

### Why No Merge Support

**Technical Complexity:**
- Deep Archive photos take 12-48 hours to restore
- Terabytes of data cannot be processed in Lambda (15-min timeout)
- Would require AWS Batch or similar infrastructure
- Risk of data loss during migration

**Business Decision:**
- Cost and complexity not justified
- Better to prevent duplicate accounts
- Manual photo transfer is sufficient workaround

## Recommended Approach for MVP

### Phase 1: No Merge Support (Permanent Decision)
**Rationale**: Too complex and risky even with backend infrastructure

1. **Clear Behavior**
   - Linking allowed ONLY if provider has no existing account
   - If provider already mapped: Linking blocked completely
   - Message: "This provider is already linked to another account"

2. **User Options When Blocked**
   - Use a different provider account
   - Continue with separate accounts
   - Manually transfer photos if needed
   - **Support cannot merge accounts**

3. **Why No Merge Ever**
   - Deep Archive complexity (12-48 hour delays)
   - Risk of data loss during migration
   - Terabytes of data exceed Lambda limits
   - Cost and complexity not justified
   - Better to prevent than fix

### Phase 2: Prevention Improvements (Future)
1. **Better Duplicate Prevention**
   - Implement email hashing if not already done
   - Check email during sign-up flow
   - Warn users before creating duplicates

2. **Clearer UI**
   - Show linked providers prominently
   - Guide users to link, not create new accounts
   - Better onboarding flow

3. **No Merge Plans**
   - Merge remains unsupported
   - Focus on preventing the problem
   - Manual photo transfer is the solution

## Implementation

### Linking Attempt Flow
```
if (googleID already has different UUID) {
  showDialog(
    "This Google account is already linked to another Photolala account.

     You can:
     - Use a different Google account to link
     - Continue using your accounts separately

     Note: Account merging is not supported."
  )
}
```

### Security for Linking

1. **Provider Verification**
   - Validate provider token with Apple/Google
   - Check existing mappings before creating new ones
   - Use conditional PUT to prevent race conditions

2. **Audit Trail**
   - Log all linking attempts
   - Record successful links
   - Track blocked attempts for support

## Simpler Alternative: Prevent the Problem

### Prevention Strategy
Instead of solving merge, prevent users from creating duplicate accounts:

1. **Email-Based Prevention (Coming Soon)**
   - **Implementation**: System will store email hashes in `identities/email/*`
   - **How it works**: Check for existing email hash during sign-up
   - **Warning message**: "An account with this email may already exist"
   - **Current Status**: Email hashing will be implemented soon
   - **Result**: Will help prevent duplicate accounts with same email

2. **Clear Provider Badges**
   - Show which providers are connected in settings
   - Make it obvious how to add additional providers
   - Educate users to link providers, not create new accounts

3. **Onboarding Flow**
   - First screen: "Sign in with existing account"
   - Second screen: "New to Photolala? Create account"
   - Reduces accidental duplicate accounts

## Conclusion

**Account Linking Policy:**
- Providers can be linked ONLY if they have no existing account
- If provider already has an account, linking is blocked
- Account merging is not supported and not planned

**User Experience:**
1. Clear messaging when linking is blocked
2. Guide users to link providers early
3. Prevent duplicate accounts through better UX
4. Manual photo transfer is the only merge option

---

*Last Updated: September 2024*
*Status: Design Phase*
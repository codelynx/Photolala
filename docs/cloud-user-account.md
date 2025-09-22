# Cloud User Account Design

## Overview

Photolala2 implements a serverless, S3-based user account system that provides secure, isolated cloud storage for each user's photos without requiring backend servers or AWS Cognito. The system leverages Apple Sign-In for authentication, AWS STS for temporary credentials, and S3 for both identity mapping and data storage.

## Core Principles

1. **Minimal Backend** - Lambda functions for auth only, direct S3 for user data
2. **No AWS Cognito** - Custom identity management using S3 storage
3. **Multi-Provider Authentication** - Support for Apple and Google Sign-In
4. **UUID-Based Isolation** - Each user gets unique namespace in S3
5. **Hybrid Access Model** - Lambda for identity, direct S3 (via STS) for data
6. **Environment Separation** - Distinct buckets for dev/stage/prod
7. **Provider Linking** - Users can link multiple auth providers to same account

## Architecture

### Identity Flow

```
Auth Provider (Apple/Google) → Provider User ID → S3 Identity Mapping → Internal UUID → User S3 Namespace
```

### Component Overview

```
┌──────────────────────────────────────┐
│         iOS/macOS App                │
├──────────────────────────────────────┤
│  Sign in with Apple / Google         │
│  ↓                                    │
│  Lambda: AuthenticateUser            │
│  ↓                                    │
│  Lambda: Identity Management         │
│  ↓                                    │
│  AWS STS (Temporary Credentials)      │
│  ↓                                    │
│  Direct S3 Access (User-Scoped)       │
└──────────────────────────────────────┘
```

**Hybrid Architecture:**
- **Lambda-Gated**: Identity management and STS token issuance
- **Direct S3 Access**: User data operations via STS credentials
- **App Permissions**: Can only invoke Lambda (no direct S3 permissions)
- **User Permissions**: Full S3 access to their namespace via temporary STS tokens

## Identity Management

### User Model

**User Profile Components:**
- **User ID**: Internal UUID for unique identification
- **Primary Provider**: Main authentication provider (Apple or Google)
- **Apple User ID**: Identifier from Apple Sign-In (if linked)
- **Google User ID**: Identifier from Google Sign-In (if linked)
- **Email**: Optional user email (from primary provider)
- **Display Name**: Optional user display name
- **Created Date**: Account creation timestamp
- **Linked Providers**: List of all connected auth providers

**Server-Managed Fields (Not in User-Writable Profile):**
- **Subscription Tier**: Managed by Lambda after IAP validation
- **Storage Quota**: Calculated from verified subscription
- **Environment**: Set at authentication time
- **Note**: These fields are stored separately and never exposed to client write access

**Subscription Tiers:**
- **Free**: 5GB storage
- **Basic**: 50GB storage ($0.99/mo)
- **Premium**: 500GB storage ($4.99/mo)
- **Professional**: 2TB storage ($9.99/mo)

### Identity Mapping in S3

The system stores identity mappings directly in S3 without a database:

```
photolala-{env}/
└── identities/
    ├── apple/
    │   └── {apple-user-id}         → UUID file
    ├── google/
    │   └── {google-user-id}        → UUID file
    └── email/
        └── {sha256-email-hash}     → UUID file (optional)
```

**Provider Prefixes:**
- `apple:` - Apple Sign-In identifiers
- `google:` - Google Sign-In identifiers
- Future: `microsoft:`, `facebook:`, etc.

**Identity Creation Flow:**

1. User signs in with chosen provider (Apple or Google)
2. Lambda checks S3 for existing mapping: `identities/{provider}/{provider-user-id}`
3. If not exists:
   - Generate new UUID
   - Create mapping with S3 conditional PUT (if-not-exists)
   - If PUT fails due to race, retry read to get winner's UUID
4. Return UUID for user namespace
5. Store provider as primary or linked account

**Race Condition Handling:**
- S3 conditional PUT ensures only one UUID wins for each provider ID
- Email deduplication is best-effort (not atomic across keys)
- Accept that near-simultaneous sign-ups with different providers may create separate accounts
- Users can link accounts later via account merge flow

### S3 User Namespace

Each user's data is isolated under their UUID with top-level categorization for efficient policy management:

**Access Control Design:**
- **User STS Credentials**: Access only to `{photos|thumbnails|catalogs|users}/{uuid}/*`
- **App Embedded Credentials**: Can only invoke Lambda functions (no S3 access)
- **Lambda Execution Role**: Manages `identities/` and issues STS tokens
- **Complete Isolation**: App never directly touches identity mappings

```
photolala-{env}/
├── photos/
│   └── {user-uuid}/
│       └── {photo-md5}.dat         # Photo files (can apply Deep Archive policy)
├── thumbnails/
│   └── {user-uuid}/
│       └── {photo-md5}.jpg         # PTM-256 thumbnails (Standard storage)
├── catalogs/
│   └── {user-uuid}/
│       ├── .photolala.md5          # Current catalog pointer
│       └── .photolala.{md5}.csv    # Catalog snapshots (Infrequent Access)
├── identities/
│   ├── apple/
│   │   └── {apple-user-id}         # Identity mapping to UUID
│   └── email/
│       └── {sha256-email-hash}     # Optional email mapping
└── users/
    └── {user-uuid}/
        ├── profile.json            # User profile data
        └── ...                     # Future: messages, settings, etc.
```

**Benefits of This Structure:**
- **Policy Application**: Easy to apply different lifecycle policies per data type
- **Deep Archive**: Can transition all photos under `photos/` to Deep Archive after 30 days
- **Standard Storage**: Keep thumbnails in Standard for fast access
- **Infrequent Access**: Move old catalogs to IA storage class
- **Cost Optimization**: Different retention and transition rules per prefix
- **Scalability**: Clean separation allows independent scaling per data type

## Multi-Provider Account Management

### Provider Linking

**Link Additional Provider:**

1. **Existing User Signs In**
   - User authenticated with primary provider
   - Selects "Link Account" in settings

2. **Secondary Provider Authentication**
   - User signs in with new provider (Apple/Google)
   - Receives provider credentials

3. **Account Linking Process**
   - Check if provider ID already mapped
   - If unmapped: Create new identity mapping to same UUID (success)
   - If mapped to different UUID: **Linking blocked** (no merge support)
   - Show clear error message explaining situation

4. **Benefits of Linked Accounts**
   - Sign in with any linked provider
   - Account recovery options
   - Cross-platform flexibility

### When Linking Is Blocked

**Scenario: Provider Already Has Account**

1. **Detection**
   - User signs in with Provider A
   - Attempts to link Provider B
   - System finds Provider B already has UUID

2. **Response**
   - **Linking blocked** - Cannot proceed
   - Show clear message: "This [Apple/Google] account is already associated with another Photolala account"
   - Suggest alternatives:
     - Use a different provider account
     - Continue with separate accounts
     - Manually transfer photos if needed

3. **No Merge Support**
   - Account merging not available
   - Data migration not automated
   - Users maintain separate accounts

## Lambda Functions

### Identity Management Functions

**AuthenticateUser Lambda:**
- **Input**: Provider token (Apple/Google)
- **Validates**: Token authenticity with provider
- **Checks**: Existing identity mapping in S3
- **Creates**: New user if needed
- **Returns**: STS credentials scoped to user's UUID

**CreateIdentity Lambda:**
- **Input**: Validated provider credentials
- **Generates**: New UUID for user
- **Stores**: Identity mapping in S3
- **Creates**: Initial user profile
- **Returns**: User UUID and profile

**LinkProvider Lambda:**
- **Input**: Current user UUID, new provider token
- **Validates**: New provider credentials
- **Checks**: Conflicts with existing mappings
- **Creates**: Additional identity mapping
- **Returns**: Updated user profile

**GetSTSToken Lambda:**
- **Input**: User UUID (from authenticated session)
- **Generates**: Temporary STS credentials
- **Scope**: Limited to user's namespaces
- **Duration**: 1 hour with auto-refresh
- **Returns**: AWS access credentials

### Lambda Execution Permissions

**Lambda Role Policy:**
```
- Read/Write: identities/*
- Read/Write: users/*/profile.json
- AssumeRole: photolala-user-sts-role
- No access to: photos/*, thumbnails/*, catalogs/*
```

**App Embedded Credentials Policy:**
```
- InvokeFunction: photolala-auth-*
- No S3 access whatsoever
- No STS access directly
```

## Authentication Flow

### Initial Sign-In

**Multi-Provider Sign-In Flow:**

1. **Provider Authentication**
   - User chooses Apple or Google Sign-In
   - Apple: Native iOS/macOS authentication
   - Google: OAuth 2.0 flow (SDK on iOS, web OAuth on macOS)
   - Receives provider-specific user identifier

2. **Identity Resolution**
   - Check S3 for existing mapping at `identities/{provider}/{provider-user-id}`
   - If exists: Load existing user profile
   - If not: Check email mapping for existing account
   - Return existing UUID or create new identity

3. **New User Creation**
   - Generate new UUID
   - Create user profile with provider credentials
   - Store identity mapping atomically (prevent duplicates)
   - Initialize with free tier subscription
   - Mark provider as primary

4. **Session Establishment**
   - Store user profile locally
   - Generate STS credentials for S3 access
   - Enable cloud features
   - Cache provider tokens for re-authentication

### STS Token Generation

**Temporary Credential Process:**

1. **Request Credentials**
   - App requests STS tokens for authenticated user
   - Specify user UUID and environment

2. **Policy Generation**
   - Create user-scoped IAM policy
   - Restrict access to user's data across all prefixes:
     - `photos/{uuid}/*` - User's photo files
     - `thumbnails/{uuid}/*` - User's thumbnail files
     - `catalogs/{uuid}/*` - User's catalog files
     - `users/{uuid}/*` - User's profile and general data
   - Allow read/write/delete operations within user's namespaces

3. **Token Issuance**
   - STS assumes role with user-specific policy
   - Issues temporary credentials (1 hour duration)
   - Credentials automatically expire and refresh

4. **Access Control**
   - User can only access their own data
   - No cross-user data access possible
   - Environment isolation enforced

## Provider-Specific Considerations

### Apple Sign-In

**Advantages:**
- Native integration on Apple platforms
- Biometric authentication (Face ID/Touch ID)
- Private email relay option
- Required for App Store if offering social login

**Implementation:**
- iOS/macOS: Native AuthenticationServices framework
- Android/Web: Sign in with Apple JS/REST API
- Handles: User ID, email (optional), full name (first time only)

### Google Sign-In

**Advantages:**
- Cross-platform consistency
- Large user base
- Rich profile information
- Integration with Google services

**Implementation:**
- iOS: Google Sign-In SDK
- macOS: Web-based OAuth 2.0 flow (SDK reliability issues)
- Android: Native Google Sign-In
- Web: Google OAuth 2.0
- Handles: User ID, email, profile picture, full name

**Configuration Requirements:**
- OAuth 2.0 client IDs per platform
- Redirect URIs configuration
- Bundle ID/package name registration

## Security Model

### Multi-Layer Security

1. **Authentication Layer**
   - Apple Sign-In provides identity verification
   - OAuth 2.0 + OpenID Connect standards
   - Biometric authentication on device

2. **Credential Layer**
   - AWS credentials encrypted with AES-256-GCM
   - Embedded in binary using credential-code
   - Environment-specific credentials

3. **Authorization Layer**
   - STS provides temporary, scoped credentials
   - User can only access their own namespace
   - No cross-user data access possible

4. **Network Layer**
   - All S3 communication over HTTPS/TLS
   - Certificate pinning (planned)
   - Request signing with AWS Signature V4

### Credential Management

**Embedded Credential Strategy:**

- **Encryption**: AES-256-GCM encrypted credentials in app binary
- **Environment Separation**: Different credentials per environment
- **Runtime Decryption**: Credentials decrypted only when needed
- **No External Dependencies**: Works offline, no server required
- **Production Lock**: AppStore builds locked to production environment

## Key Operations

### Identity Manager Responsibilities

**Core Functions:**
- Manage Apple Sign-In flow
- Create and retrieve user identities
- Maintain session state
- Handle keychain persistence
- Provide STS credentials for S3 access

**Session Management:**
- Restore previous sessions on app launch
- Store user profile in secure keychain
- Clear session data on sign out
- Handle session expiration

### S3 Identity Operations

**Store Identity Mapping:**
- Atomic PUT operation with conditional check
- Prevent duplicate mappings with "if-not-exists" condition
- Store UUID as plain text file in S3
- Return error if mapping already exists

**Retrieve Identity Mapping:**
- GET operation from S3 identity path
- Parse UUID from file content
- Return null if mapping doesn't exist
- Handle network errors gracefully

## Subscription Management

### In-App Purchase Integration

**Subscription Update Flow:**
1. User purchases subscription via App Store
2. App receives IAP receipt
3. Update user profile with new tier
4. Store updated profile in S3
5. Apply new storage quota immediately

**Storage Quotas:**
- **Free**: 5GB
- **Basic**: 50GB ($0.99/month)
- **Premium**: 500GB ($4.99/month)
- **Professional**: 2TB ($9.99/month)

**Quota Enforcement:**
- Check before upload operations
- Display usage in UI
- Prompt for upgrade when near limit
- Block uploads when exceeded

## Migration Strategy

### From Anonymous to Authenticated

**Local-Only Mode (Default):**
- App works without sign-in
- All data stored locally
- No cloud features available
- Full functionality for local photos

**Migration Process on Sign-In:**
1. **Catalog Assessment**
   - Scan local photo catalog
   - Calculate total size for upload
   - Estimate migration time

2. **User Confirmation**
   - Show migration summary
   - Allow selective upload
   - Provide progress estimates

3. **Upload Process**
   - Upload photos to user namespace
   - Maintain local copies
   - Track progress with UI feedback

4. **Completion**
   - Mark migration complete
   - Enable cloud features
   - Sync future changes

### Multi-Device Sync

**Device Management:**
- Each device gets unique identifier
- Track device name, model, and last sync
- Show active devices in settings
- Allow device removal/deauthorization
- Support multiple providers per device

**Cross-Platform Authentication:**
- **iOS**: Apple Sign-In native, Google Sign-In SDK
- **macOS**: Apple Sign-In native, Google OAuth web flow
- **Android**: Google Sign-In native, Apple Sign-In web
- **Web**: OAuth 2.0 for both providers

**Conflict Resolution:**
- **Photos**: MD5 deduplication prevents duplicates
- **Metadata**: Last-write-wins strategy
- **Catalogs**: Merge strategy with conflict detection
- **Preferences**: Device-specific or synced options
- **Provider Links**: Synchronized across all devices

## Privacy Considerations

### Data Minimization

- Only collect necessary data (Apple ID, email if shared)
- No tracking or analytics without consent
- User can delete account and all data
- No third-party data sharing

### Email Privacy

**Apple Private Relay Support:**
- Accept and handle private relay emails
- Use SHA-256 hashing for email lookups
- Never log or store raw email addresses
- Support email address changes

### GDPR Compliance

**Data Export:**
- Export all user data on request
- Include photos, metadata, and profile
- Provide in standard formats (ZIP/JSON)
- Complete within 30 days

**Account Deletion:**
- Delete all user data from S3
- Remove identity mappings
- Clear local device data
- Irreversible operation with confirmation

## Error Handling

### Identity Error Categories

**Authentication Errors:**
- Not signed in
- Apple Sign-In failure
- Invalid credentials
- Session expired

**Account Errors:**
- Mapping already exists
- Account not found
- Profile corruption

**Subscription Errors:**
- Subscription expired
- Quota exceeded
- Payment failure

**Network Errors:**
- Connection timeout
- S3 unavailable
- Invalid response

### Error Recovery Strategies

- **Automatic Retry**: Network and transient errors
- **User Intervention**: Authentication and payment issues
- **Fallback Mode**: Continue with local-only features
- **Error Reporting**: Log errors for debugging

## Testing Strategy

### Test Scenarios

**Authentication Tests:**
- New user sign-in creates identity
- Existing user sign-in retrieves identity
- Sign-out clears session
- Session restoration after app restart

**Identity Mapping Tests:**
- Atomic creation prevents duplicates
- Concurrent sign-ins handle correctly
- Missing mappings return null
- Corrupt mappings handled gracefully

**STS Credential Tests:**
- Credentials scoped to user namespace
- Automatic refresh before expiration
- Access denied outside namespace
- Environment isolation enforced

**Subscription Tests:**
- Quota enforcement at limits
- Tier changes apply immediately
- Receipt validation process
- Downgrade handling

## Monitoring

### Key Metrics

1. **Authentication**
   - Sign-in success/failure rates
   - Apple Sign-In availability
   - Session duration

2. **Identity Operations**
   - New user creation rate
   - Identity mapping conflicts
   - Migration success rate

3. **Storage Usage**
   - Per-user storage consumption
   - Subscription tier distribution
   - Quota violations

### CloudWatch Alarms

**Identity Monitoring:**
- High identity creation rate (>100/minute)
- Failed authentication spike
- Unusual access patterns
- Quota violation attempts

**Performance Monitoring:**
- S3 response latency
- STS token generation time
- Sign-in completion rate
- Upload/download speeds

## Future Enhancements

### Phase 2
- Microsoft Account support
- Facebook Login integration
- Family sharing with shared albums
- Web access portal
- Background sync

### Phase 3
- End-to-end encryption option
- Social features (sharing, comments)
- AI-powered photo organization
- Advanced search with S3 Select
- Enterprise SSO (SAML/OIDC)
- Custom identity provider support

## Appendix

### A. S3 Bucket Policies

**User-Scoped STS Policy:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowUserDataAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::photolala-{env}/photos/{uuid}/*",
                "arn:aws:s3:::photolala-{env}/thumbnails/{uuid}/*",
                "arn:aws:s3:::photolala-{env}/catalogs/{uuid}/*",
                "arn:aws:s3:::photolala-{env}/users/{uuid}/*"
            ]
        }
    ]
}
```

**App Embedded Credentials Policy (Lambda Only):**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "InvokeLambdaFunctionsOnly",
            "Effect": "Allow",
            "Action": "lambda:InvokeFunction",
            "Resource": [
                "arn:aws:lambda:*:*:function:photolala-auth-*",
                "arn:aws:lambda:*:*:function:photolala-identity-*"
            ]
        }
    ]
}
```

**Lambda Execution Role Policy:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ManageIdentities",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:HeadObject"
            ],
            "Resource": [
                "arn:aws:s3:::photolala-{env}/identities/*",
                "arn:aws:s3:::photolala-{env}/users/*/profile.json"
            ]
        },
        {
            "Sid": "AssumeUserRole",
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::*:role/photolala-user-sts-role"
        }
    ]
}
```

### B. IAM Role Trust Policy

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::ACCOUNT:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "photolala-app-2024"
                }
            }
        }
    ]
}
```

### C. Cost Estimates

| Tier | Storage | S3 Cost | Total Monthly |
|------|---------|---------|---------------|
| Free | 5GB | $0.12 | $0.00 (subsidized) |
| Basic | 50GB | $1.15 | $0.99 |
| Premium | 500GB | $11.50 | $4.99 |
| Professional | 2TB | $47.10 | $9.99 |

---

*Last Updated: September 2024*
*Version: 1.0*
*Status: Design Phase*
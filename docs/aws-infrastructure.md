# AWS Infrastructure Documentation

This document describes the AWS infrastructure components used by Photolala, including Lambda functions, IAM roles, policies, and S3 buckets.

## AWS Account Structure

- **Account ID**: 566372147352
- **Primary Region**: us-east-1
- **Services Used**: Lambda, S3, IAM, STS, Athena

## Lambda Functions

### Authentication Functions

#### photolala-auth (Unified Authentication)
- **Status**: Production - Successfully deployed and tested
- **Purpose**: Unified authentication handler for both Apple and Google Sign-In
- **Runtime**: Node.js 20.x
- **Handler**: index.handler
- **Role**: arn:aws:iam::566372147352:role/photolala-lambda-role
- **ARN**: arn:aws:lambda:us-east-1:566372147352:function:photolala-auth
- **Environment Variables**:
  - `APPLE_BUNDLE_ID`: com.electricwoods.photolala
  - `S3_BUCKET`: photolala-prod (default, dynamically selected based on environment parameter)
- **Functionality**:
  - Verifies Apple ID tokens using Apple's JWKS endpoint (https://appleid.apple.com/auth/keys)
  - Verifies Google ID tokens using Google's JWKS endpoint (https://www.googleapis.com/oauth2/v3/certs)
  - Creates new users or retrieves existing users from S3
  - Stores user identities in S3: `identities/{provider}:{id}`
  - Generates mock STS credentials (TODO: Implement real STS AssumeRole)
  - Returns user object with provider-specific fields and credentials
- **Input Format**: API Gateway format with body containing:
  ```json
  {
    "provider": "apple" | "google",
    "id_token": "JWT token string",
    "environment": "development" | "staging" | "production",
    "nonce": "optional nonce for Apple",
    "authorization_code": "optional for Apple"
  }
  ```
- **Output Format**:
  ```json
  {
    "user": {
      "user_id": "UUID string",
      "apple_user_id": "string or null",
      "google_user_id": "string or null",
      "email": "string or null",
      "display_name": "string",
      "created_at": "ISO8601 date",
      "updated_at": "ISO8601 date"
    },
    "credentials": {
      "access_key_id": "string",
      "secret_access_key": "string",
      "session_token": "string",
      "expiration": "ISO8601 date"
    },
    "is_new_user": boolean
  }
  ```

#### photolala-apple-auth (DEPRECATED)
- **Purpose**: Apple Sign-In authentication
- **Status**: Replaced by photolala-auth (can be removed after transition period)
- **Note**: No environment-specific versions
- **Migration**: App code updated to use photolala-auth

#### photolala-google-token-exchange (DEPRECATED)
- **Purpose**: Google OAuth token exchange
- **Status**: Replaced by photolala-auth (can be removed after transition period)
- **Note**: No environment-specific versions
- **Migration**: App code updated to use photolala-auth

#### photolala-web-auth, photolala-web-auth-dev, photolala-web-auth-stage
- **Purpose**: Web application authentication
- **Environments**:
  - `photolala-web-auth`: Production
  - `photolala-web-auth-dev`: Development
  - `photolala-web-auth-stage`: Staging

### Device Management Functions

#### photolala-device-registry-{dev|stage|prod}
- **Purpose**: Register and manage device tokens for push notifications
- **Environments**: Separate functions per environment

#### photolala-cleanup-orphaned-devices-{dev|stage|prod}
- **Purpose**: Clean up orphaned device registrations
- **Environments**: Separate functions per environment

### Catalog Functions

#### photolala-catalog-query-{dev|stage|prod}
- **Purpose**: Query photo catalog data
- **Integration**: Works with Athena for SQL queries on catalog data
- **Environments**: Separate functions per environment

### Administrative Functions

#### photolala-admin-auth
- **Purpose**: Administrative authentication and access
- **Access Level**: Admin only

#### photolala-notification-handler-dev
- **Purpose**: Handle push notifications
- **Environment**: Development only currently

#### photolala-email-sender
- **Purpose**: Send email notifications
- **Integration**: SES for email delivery

#### photolala-apple-callback
- **Purpose**: Handle Apple Sign-In callbacks
- **Usage**: OAuth flow callback handling

## IAM Roles

### Lambda Execution Roles

#### photolala-lambda-role
- **Purpose**: Primary Lambda execution role
- **Used By**: Most Lambda functions including photolala-auth
- **Trust Relationship**: lambda.amazonaws.com
- **Attached Policies**:
  - AWSLambdaBasicExecutionRole (CloudWatch Logs)
  - S3 access to photolala buckets
  - STS AssumeRole permissions

#### photolala-lambda-role-{dev|stage|prod}
- **Purpose**: Environment-specific Lambda execution roles
- **Usage**: For functions that need environment isolation

#### photolala-admin-lambda-role
- **Purpose**: Lambda execution role with elevated permissions
- **Usage**: Administrative functions only

### Application User Roles

#### PhotolalaLambdaRole-{dev|stage|prod|default}
- **Purpose**: Roles assumed by application users after authentication
- **Trust Relationship**: Federated through Lambda/STS
- **Permissions**: S3 access scoped to user's data

## IAM Users

### Application Service Users

#### photolala-app-dev
- **Purpose**: Development environment service user
- **Access**: Development S3 buckets, Lambda invocation
- **Managed Policies**: PhotolalaLambdaInvoke

#### photolala-app-stage
- **Purpose**: Staging environment service user
- **Access**: Staging S3 buckets, Lambda invocation
- **Managed Policies**: PhotolalaLambdaInvoke

#### photolala-app-prod
- **Purpose**: Production environment service user
- **Access**: Production S3 buckets, Lambda invocation
- **Managed Policies**: PhotolalaLambdaInvoke

#### photolala-app-default
- **Purpose**: Default/fallback service user
- **Usage**: Legacy support

#### photolala-app-admin
- **Purpose**: Administrative service user
- **Access**: Full access across all environments

## IAM Policies

### Managed Policies

#### PhotolalaLambdaInvoke
- **Purpose**: Allow Lambda function invocation
- **Created**: For photolala-app-{dev|stage|prod} users
- **Permissions**:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "lambda:InvokeFunction",
        "Resource": "arn:aws:lambda:*:566372147352:function:photolala-*"
      }
    ]
  }
  ```

### Inline Policies

#### S3 Access Policies
- **Purpose**: Environment-specific S3 access
- **Pattern**: Each environment user has access to their respective S3 buckets
- **Permissions**:
  - ListBucket on photolala-{env}
  - GetObject/PutObject/DeleteObject on photolala-{env}/*

## S3 Buckets

### Environment Buckets

#### photolala-dev
- **Purpose**: Development environment storage
- **Contents**:
  - User identities (identities/)
  - Photo metadata
  - Thumbnails
  - Catalog data

#### photolala-stage
- **Purpose**: Staging environment storage
- **Contents**: Same structure as development

#### photolala-prod
- **Purpose**: Production environment storage
- **Contents**: Same structure as development
- **Backup**: Cross-region replication enabled

### Storage Structure

```
photolala-{env}/
├── identities/
│   ├── apple:{user_id}         # Maps Apple ID to internal user ID
│   ├── google:{user_id}        # Maps Google ID to internal user ID
│   └── email:{email_hash}      # Maps email hash to internal user ID
├── users/
│   └── {user_id}/
│       ├── metadata.json       # User profile and settings
│       ├── photos/            # Photo storage
│       └── thumbnails/        # Generated thumbnails
└── catalogs/
    └── {catalog_hash}/        # Catalog SQLite files
```

## Environment Configuration

### Environment Detection
- Mobile apps use UserDefaults key `environment_preference`
- Values: "development", "staging", "production"
- Production builds are locked to production environment

### Lambda Function Naming Convention
- Most functions follow pattern: `photolala-{function}-{env}`
- Environment suffixes:
  - Development: `-dev`
  - Staging: `-stage`
  - Production: No suffix or `-prod`
- Exceptions (no environment suffix):
  - `photolala-auth` (new unified function)
  - `photolala-apple-auth` (legacy)
  - `photolala-google-token-exchange` (legacy)

## Security Considerations

### Token Verification
- Apple tokens verified against Apple's JWKS endpoint
- Google tokens verified against Google's JWKS endpoint
- Nonce validation for replay attack prevention
- Audience validation to ensure tokens are for our app

### Data Isolation
- Each environment has separate S3 buckets
- IAM policies enforce environment boundaries
- User data scoped by user ID in S3 paths

### Credential Management
- App credentials stored encrypted in binary (see credential-security.md)
- STS temporary credentials for user sessions
- No long-lived credentials in client applications

## Migration Notes

### Completed Migration: Unified Authentication (September 2025)
- **From**: Separate photolala-apple-auth and photolala-google-token-exchange
- **To**: Unified photolala-auth function
- **Status**: ✅ Completed and tested across all environments
- **Benefits Achieved**:
  - Single codebase for both providers
  - Consistent error handling and response format
  - Simplified maintenance
  - Environment-aware without multiple functions
  - Reduced Lambda cold starts
- **Testing Results**:
  - Apple Sign-In: Dev ✅ Stage ✅ Prod ✅
  - Google Sign-In: Dev ✅ Stage ✅ Prod ✅

### Future Improvements
1. **STS Credentials**: Replace mock credentials with real STS AssumeRole implementation
2. **Cleanup**: Remove deprecated functions (photolala-apple-auth, photolala-google-token-exchange) after monitoring period
3. **Infrastructure as Code**: Implement CloudFormation/CDK for Lambda deployments
4. **Monitoring**: Add CloudWatch dashboard for authentication metrics
5. **Rate Limiting**: Implement rate limiting per user/IP
6. **Caching**: Add caching layer for user lookups to reduce S3 calls

## Monitoring and Logs

### CloudWatch Logs
- Log Group Pattern: `/aws/lambda/{function-name}`
- Retention: 30 days for dev/stage, 90 days for production
- Key Metrics:
  - Authentication success/failure rates
  - New user creation
  - Token validation errors

### Alarms
- Lambda error rate > 1%
- Lambda duration > 10 seconds
- S3 access denied errors

## Testing

### Test Environments
- Development: Full access for testing
- Staging: Production-like with test data
- Production: Limited test accounts only

### Test Tools
- **Identity Provider Diagnostics** (in-app): Tests OAuth flow only
- **Photolala Account Diagnostics** (in-app): Full authentication testing with Lambda
- **AWS CLI**: Direct Lambda invocation for debugging

### Test Coverage (as of September 2025)
- ✅ Apple Sign-In via photolala-auth (all environments)
- ✅ Google Sign-In via photolala-auth (all environments)
- ✅ API Gateway response format handling
- ✅ Swift model compatibility (underscore field names)
- ✅ ISO8601 date format without milliseconds
- ✅ New user creation and existing user retrieval

## Contact and Support

- **AWS Account Owner**: Electric Woods LLC
- **Technical Contact**: Development Team
- **Documentation**: This file and related docs in /docs directory
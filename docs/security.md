# Security Architecture

## Overview

Photolala2 implements a defense-in-depth security strategy with embedded encrypted credentials, runtime environment selection, and platform-native security features. This document outlines our security architecture, threat model, and best practices.

## Core Security Principles

### 1. Embedded Credential Security
- **Approach**: All credentials are encrypted and embedded in the app binary
- **Tool**: credential-code with AES-256 encryption
- **Benefit**: No runtime credential fetching required
- **Trade-off**: Credentials cannot be rotated without app update

### 2. Single Binary, Multiple Environments
- **Design**: One build contains dev/stage/prod credentials
- **Selection**: Environment chosen via UserDefaults at runtime
- **Safety**: Production builds locked to production environment
- **Benefit**: Simplified deployment and testing

### 3. No External Dependencies
- **Storage**: No credential servers or external config files
- **Configuration**: All settings stored in UserDefaults/SharedPreferences
- **Network**: Credentials work offline
- **Benefit**: Reduced attack surface

## Threat Model

### What We Protect Against

#### 1. Source Code Exposure
- **Threat**: GitHub repository compromise or accidental public exposure
- **Mitigation**: Credentials never stored in plain text in source
- **Response**: If source exposed, credentials remain encrypted

#### 2. Casual Inspection
- **Threat**: Developer browsing code or binary
- **Mitigation**: AES-256 encryption prevents reading credentials
- **Response**: Encrypted values meaningless without decryption key

#### 3. Configuration Errors
- **Threat**: Wrong environment used in production
- **Mitigation**: AppStore builds hardcoded to production
- **Response**: Automatic environment selection based on build type

#### 4. Network Interception
- **Threat**: Man-in-the-middle attacks
- **Mitigation**: All AWS/API calls use HTTPS/TLS
- **Response**: Credentials never transmitted over network

### What We Accept as Risks

#### 1. Sophisticated Binary Analysis
- **Risk**: Determined attacker with reverse engineering tools
- **Acceptance**: Cost/benefit trade-off for our use case
- **Mitigation**: Regular credential rotation
- **Monitor**: AWS CloudTrail for unusual activity

#### 2. Device Compromise
- **Risk**: Jailbroken/rooted devices could extract credentials
- **Acceptance**: Platform responsibility
- **Mitigation**: iOS/Android platform security
- **Monitor**: Unusual usage patterns

#### 3. Update Requirement for Rotation
- **Risk**: Cannot instantly revoke compromised credentials
- **Acceptance**: Trade-off for offline capability
- **Mitigation**: Quick app store review process
- **Plan**: Emergency update procedures

## Security Boundaries

### Trust Boundaries
```
┌─────────────────────────────────────┐
│         App Binary (Trusted)         │
│  ┌─────────────────────────────┐    │
│  │   Encrypted Credentials     │    │
│  │   (credential-code)         │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │   Runtime Selection         │    │
│  │   (UserDefaults)           │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
             ↓ HTTPS/TLS
┌─────────────────────────────────────┐
│       AWS Services (External)        │
│  • S3 Buckets                       │
│  • Lambda Functions                 │
│  • Athena Queries                   │
└─────────────────────────────────────┘
```

### Data Classification

| Data Type | Classification | Storage | Encryption |
|-----------|---------------|---------|------------|
| AWS Credentials | SECRET | App Binary | AES-256 |
| Apple Sign-In Key | SECRET | App Binary | AES-256 |
| User Photos | PRIVATE | S3/Device | At Rest |
| Environment Config | INTERNAL | UserDefaults | None |
| User Preferences | INTERNAL | UserDefaults | None |

## Incident Response

### Credential Compromise Procedure

#### Detection
1. Monitor AWS CloudTrail for unusual activity
2. Set up billing alerts for unexpected charges
3. Regular audit of S3 access logs
4. Monitor for app behavior anomalies

#### Response (Within 1 Hour)
1. **Immediate**: Disable compromised AWS IAM credentials
2. **Immediate**: Create new IAM credentials
3. **Quick**: Update `.credentials/` with new values
4. **Quick**: Run `./scripts/generate-credentials.sh`
5. **Quick**: Test new build in development

#### Recovery (Within 24 Hours)
1. **Build**: Create new app version with updated credentials
2. **Test**: Verify all environments work correctly
3. **Submit**: Emergency app store review
4. **Notify**: Alert users to update immediately
5. **Revoke**: Fully delete old IAM credentials

#### Post-Incident
1. **Analyze**: Determine root cause
2. **Document**: Update incident log
3. **Improve**: Enhance monitoring
4. **Review**: Update procedures

### Security Audit Checklist

#### Daily
- [ ] Check AWS billing for anomalies
- [ ] Review CloudTrail for errors
- [ ] Monitor app crash reports

#### Weekly
- [ ] Audit S3 bucket permissions
- [ ] Review Lambda function logs
- [ ] Check for security updates

#### Monthly
- [ ] Rotate development credentials
- [ ] Review access patterns
- [ ] Update security documentation

#### Quarterly
- [ ] Full credential rotation
- [ ] Security dependency updates
- [ ] Penetration testing (if applicable)

## Development Security Guidelines

### DO's
✅ **Always** use `generate-credentials.sh` after credential changes
✅ **Always** validate credentials with `validate-credentials.sh`
✅ **Always** use HTTPS for all network requests
✅ **Always** keep `.credentials/` in .gitignore
✅ **Always** use different credentials per environment
✅ **Always** test credential changes in development first

### DON'Ts
❌ **Never** commit `.credentials/` directory
❌ **Never** hardcode credentials in source code
❌ **Never** log credential values
❌ **Never** transmit credentials over network
❌ **Never** store credentials in plain text
❌ **Never** share credentials via email/chat

### Code Review Requirements

Before merging credential-related changes:
1. Verify no plain text credentials in code
2. Check `.gitignore` includes credential directories
3. Ensure proper error handling for credential failures
4. Validate encryption is properly implemented
5. Test all environment configurations

## Platform-Specific Security

### iOS/macOS
- **Keychain**: Consider for user-specific secrets
- **Secure Enclave**: Not used (overkill for our needs)
- **App Transport Security**: Enforced for all connections
- **Code Signing**: Required for distribution

### Android
- **SharedPreferences**: Used for environment config
- **Android Keystore**: Consider for future enhancements
- **Network Security Config**: Enforces HTTPS
- **App Signing**: Required for Play Store

## Compliance Considerations

### Data Privacy
- User photos never leave device without consent
- Credentials never include user data
- Environment selection is local only
- No tracking or analytics in credentials

### GDPR/CCPA
- Credentials are app-level, not user-level
- No personal data in credential system
- User can delete all local data
- Right to erasure supported

## Security Updates

### Monitoring
- Subscribe to credential-code security updates
- Monitor AWS security bulletins
- Track iOS/Android security releases
- Review dependency vulnerabilities

### Update Process
1. Evaluate security severity
2. Test updates in development
3. Deploy to staging
4. Production release if critical
5. Document changes

## Emergency Contacts

### Security Issues
- **Internal**: Create issue in private repo
- **AWS**: AWS Support Console
- **Apple**: developer.apple.com/contact
- **Google**: Google Cloud Console

### Credential Recovery
- **Primary**: Team password manager
- **Backup**: Encrypted backup drive
- **Emergency**: Team leads have access

## Appendix: Security Tools

### Validation
```bash
# Validate all credentials present
./scripts/validate-credentials.sh

# Check for exposed secrets in git
git secrets --scan
```

### Monitoring
```bash
# AWS CLI for CloudTrail
aws cloudtrail lookup-events --max-items 100

# Check S3 access
aws s3api get-bucket-logging --bucket photolala-prod
```

### Rotation
```bash
# Generate new credentials
./scripts/generate-credentials.sh

# Test in development
./scripts/switch-env.sh dev
```

---

*Last Updated: September 2024*
*Next Review: December 2024*
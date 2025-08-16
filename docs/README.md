# Photolala Documentation

Welcome to the Photolala documentation. This guide will help you navigate the project documentation and find the information you need.

## Quick Links

- [Project Status](./PROJECT_STATUS.md) - Current implementation status
- [Architecture Overview](./architecture/overview.md) - System design and architecture
- [Build Commands](./development/build-commands.md) - How to build the project
- [Authentication](./features/authentication/overview.md) - Authentication system

## Documentation Structure

### 📐 Architecture
Core system architecture and design decisions.

- [System Overview](./architecture/overview.md) - High-level architecture
- [Navigation Patterns](./architecture/navigation.md) - Platform navigation flows
- [Data Flow](./architecture/data-flow.md) - Data management architecture
- [Platform Differences](./architecture/platform-differences.md) - iOS vs Android

### 🚀 Features
Documentation for implemented features.

#### Authentication
- [Overview](./features/authentication/overview.md) - Authentication system design
- [Apple Sign In](./features/authentication/apple-signin.md) - Apple Sign In implementation
- [Google Sign In](./features/authentication/google-signin.md) - Google Sign In setup
- [Account Linking](./features/authentication/account-linking.md) - Multi-provider accounts

#### Catalog System
- [Overview](./features/catalog/overview.md) - Photo catalog architecture
- [Implementation](./features/catalog/implementation.md) - Current implementation (v2)
- [API Reference](./features/catalog/api-reference.md) - Catalog API documentation

#### Photo Browsers
- [Local Browser](./features/browsers/local-browser.md) - File system browser
- [Apple Photos](./features/browsers/apple-photos.md) - Photos app integration
- [Cloud Browser](./features/browsers/cloud-browser.md) - S3 cloud storage
- [Google Photos](./features/browsers/google-photos.md) - Google Photos integration

#### Backup & Sync
- [Star System](./features/backup/star-system.md) - Star-based backup queue
- [S3 Upload](./features/backup/s3-upload.md) - Cloud upload implementation
- [Queue Management](./features/backup/queue-management.md) - Backup queue handling

#### UI Components
- [PhotoDigest System](./current/photodigest-system.md) - Two-level cache architecture
- [Photo Preview System](./current/photo-preview-system.md) - Full-screen photo viewer
- [Selection System](./features/ui-components/selection-system.md) - Multi-selection
- [Bookmark System](./features/ui-components/bookmark-system.md) - Photo bookmarking

### 🛠 Development
Developer guides and setup instructions.

#### Setup Guides
- [macOS Setup](./development/setup/macos.md) - macOS development setup
- [iOS Setup](./development/setup/ios.md) - iOS development setup
- [Android Setup](./development/setup/android.md) - Android development setup

#### Guides
- [Build Commands](./development/build-commands.md) - Build instructions
- [Testing Guide](./development/testing-guide.md) - Testing procedures
- [Release Process](./development/release-process.md) - Release workflow

#### Troubleshooting
- [Build Issues](./development/troubleshooting/build-issues.md) - Common build problems
- [Auth Issues](./development/troubleshooting/auth-issues.md) - Authentication troubleshooting
- [Xcode Issues](./development/troubleshooting/xcode-issues.md) - Xcode-specific problems

### 🔌 API Documentation
Backend API references.

- [Backend API](./api/backend-api.md) - Main API endpoints
- [S3 Operations](./api/s3-operations.md) - S3 integration
- [Auth Endpoints](./api/auth-endpoints.md) - Authentication APIs

### 💼 Business
Business and deployment documentation.

- [Pricing Strategy](./business/pricing-strategy.md) - Current pricing model
- [IAP Setup](./business/iap-setup.md) - In-app purchase configuration
- [TestFlight Guide](./business/testflight-guide.md) - TestFlight deployment

### 📋 Planning
Future features and roadmap.

- [Roadmap](./planning/roadmap.md) - Feature roadmap
- [Android MVP](./planning/android-mvp.md) - Android minimum viable product
- [Feature Requests](./planning/feature-requests/) - User requested features

### 📦 Archive
Historical documentation and old versions.

- [2025-06](./archive/2025-06/) - June 2025 archives
- [2025-07](./archive/2025-07/) - July 2025 archives
- [Design Decisions](./archive/design-decisions/) - Original design documents
- [Old Versions](./archive/old-versions/) - Superseded documentation

## Getting Started

### For New Developers
1. Read the [Architecture Overview](./architecture/overview.md)
2. Follow the setup guide for your platform
3. Review [Build Commands](./development/build-commands.md)
4. Check [Project Status](./PROJECT_STATUS.md) for current state

### For Contributors
1. Check [Planning](./planning/) for upcoming features
2. Review relevant feature documentation
3. Follow the [Testing Guide](./development/testing-guide.md)
4. Submit PRs with documentation updates

## Documentation Standards

### File Naming
- Use lowercase with hyphens: `feature-name.md`
- Be descriptive but concise
- Include version numbers when relevant: `catalog-v2.md`

### Content Structure
- Start with a clear title and overview
- Use headers to organize sections
- Include code examples where helpful
- Link to related documentation

### Maintenance
- Keep documentation up-to-date with code
- Archive outdated documents
- Update links when moving files
- Add to relevant index files

## Recent Updates

See [PROJECT_STATUS.md](./PROJECT_STATUS.md) for the latest implementation updates and changes.

---

Last updated: July 31, 2025
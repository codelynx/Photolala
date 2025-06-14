# Photolala Documentation

## Quick Links

📊 **[PROJECT_STATUS.md](./PROJECT_STATUS.md)** - Current implementation status and recent changes

## Documentation Structure

### Current State
Documents describing the current architecture and implementation:

- **[current/architecture.md](./current/architecture.md)** - System architecture and component overview
- **[current/navigation-flow.md](./current/navigation-flow.md)** - Platform-specific navigation patterns
- **[current/thumbnail-system.md](./current/thumbnail-system.md)** - Thumbnail generation and caching
- **[current/selection-system.md](./current/selection-system.md)** - Selection management and UI

### History
Historical design documents and implementation notes:

#### Design Decisions
- **[history/design-decisions/](./history/design-decisions/)** - Original design documents
  - `photo-browser-design.md` - Initial photo browser architecture
  - `selection-and-preview-design.md` - Selection and preview feature design
  - `thumbnail-*.md` - Various thumbnail system designs
  - `swiftdata-thumbnail-metadata-design.md` - SwiftData integration plans

#### Implementation Notes  
- **[history/implementation-notes/](./history/implementation-notes/)** - Development journey
  - `implementation-phase1-details.md` - Phase 1 implementation
  - `photo-preview-implementation.md` - Preview feature implementation
  - `navigation-architecture.md` - Original navigation design

### Planning
- *Currently empty - future roadmap documents will go here*

## About This Structure

This documentation is organized to separate:
- **Current state** - What's actually implemented and how it works today
- **History** - Design decisions, discussions, and implementation journey
- **Planning** - Future features and roadmap (when needed)

This makes it easy for:
- New developers to understand the current system
- Team members to reference historical decisions
- Everyone to track what's been implemented vs. planned

## Contributing

When adding documentation:
1. **Current features** → Add to `current/` or update existing docs
2. **Design proposals** → Start in `planning/`, move to `history/` after implementation
3. **Implementation notes** → Add to `history/implementation-notes/`
4. **Status updates** → Update `PROJECT_STATUS.md`

Last updated: June 14, 2025
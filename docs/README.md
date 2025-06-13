# Documentation Directory

This directory contains planning and design documents for the Photolala project.

## Current Status

📊 **See [`project-status.md`](./project-status.md) for the latest implementation status and recent changes.**

## Purpose

Before implementing major features, we will:
1. Document the requirements and design decisions here
2. Review and discuss the plans
3. Once approved, proceed with the actual implementation

## Document Structure

### Status & Planning
- [`project-status.md`](./project-status.md) - Current implementation status and recent changes
- [`implementation-roadmap.md`](./implementation-roadmap.md) - Overall project roadmap
- [`development-plan-2025-06.md`](./development-plan-2025-06.md) - Current development plan

### Architecture & Design
- [`photo-browser-design.md`](./photo-browser-design.md) - Core photo browser architecture
- [`window-per-folder-architecture.md`](./window-per-folder-architecture.md) - macOS window management
- [`native-collection-view-design.md`](./native-collection-view-design.md) - Native collection view implementation
- [`cross-platform-folder-selection-design.md`](./cross-platform-folder-selection-design.md) - Folder selection across platforms

### Implementation Notes
- [`phase1-implementation-notes.md`](./phase1-implementation-notes.md) - Phase 1 implementation details
- [`phase2-implementation-notes.md`](./phase2-implementation-notes.md) - Phase 2 implementation details
- [`implementation-notes-phase3-4.md`](./implementation-notes-phase3-4.md) - Phase 3 & 4 implementation

### Technical Specifications
- [`photolala-footprint-design.md`](./photolala-footprint-design.md) - .photolala file format
- [`thumbnail-manager-design.md`](./thumbnail-manager-design.md) - **PhotoManager implementation** ✅
- [`thumbnail-system-architecture.md`](./thumbnail-system-architecture.md) - Thumbnail generation system
- [`loading-system-implementation-notes.md`](./loading-system-implementation-notes.md) - Loading and priority system
- [`security-scoped-resources-implementation.md`](./security-scoped-resources-implementation.md) - Security and permissions

## Recent Major Updates (June 13, 2025)

### PhotoManager Implementation Complete ✅
- Dual caching system (memory + disk)
- Proper thumbnail scaling (256px short side, 512px max)
- EXIF orientation handling
- Thread-safe with priority inversion fixes
- Collection views now use thumbnails instead of full images

See [`project-status.md`](./project-status.md) for full details.
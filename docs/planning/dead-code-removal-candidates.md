# Dead Code Removal Candidates

Last Updated: June 22, 2025

## Overview

This document tracks potentially dead code in the Photolala codebase that can be removed to improve maintainability and reduce complexity. Each candidate is marked with its status and rationale.

## Quick Summary

### Confirmed Dead Code (Safe to Remove)
1. `S3CatalogSyncService.swift` - Replaced by V2
2. `PhotolalaCatalogServiceTests.swift` - Tests for legacy service
3. Test files in production code (5 files)

### Likely Dead (Needs Verification)
1. `PhotolalaCatalogService.swift` - Keep until migration complete
2. Various TODO comments (37 total)

### Actually In Use (Keep)
1. V2 services (PhotolalaCatalogServiceV2, S3CatalogSyncServiceV2)
2. SwiftDataCatalog models
3. DirectoryPhotoProvider

## Status Legend

- 🔴 **Confirmed Dead**: Safe to remove
- 🟡 **Likely Dead**: Probably safe to remove, needs verification
- 🟢 **In Use**: Actually being used, keep
- ❓ **Unknown**: Needs investigation

## Candidates by Category

### 1. Legacy Catalog Services

#### PhotolalaCatalogService (CSV-based)
- **Status**: 🟡 Likely Dead
- **Location**: `Photolala/Services/PhotolalaCatalogService.swift`
- **Rationale**: Replaced by PhotolalaCatalogServiceV2 (SwiftData)
- **Dependencies**: 
  - Used by CatalogAwarePhotoLoader
  - Migration code in V2 service references it
  - DirectoryPhotoProvider might use it
- **Action**: Keep until migration from CSV to SwiftData is complete

#### S3CatalogSyncService (Original)
- **Status**: 🔴 Confirmed Dead
- **Location**: `Photolala/Services/S3CatalogSyncService.swift`
- **Rationale**: Replaced by S3CatalogSyncServiceV2
- **Dependencies**: S3PhotoProvider now uses V2
- **Action**: Can be removed

#### PhotolalaCatalogServiceV2 and S3CatalogSyncServiceV2
- **Status**: 🟢 In Use
- **Location**: `Photolala/Services/`
- **Rationale**: Actively used by S3PhotoProvider
- **Action**: Keep - these are the current implementations

### 2. Test Files

#### PhotolalaCatalogServiceTests
- **Status**: 🔴 Confirmed Dead
- **Location**: `photolalaTests/PhotolalaCatalogServiceTests.swift`
- **Rationale**: Tests for legacy CSV service, already disabled
- **Action**: Can be removed

#### Test Files in Production Code
- **Status**: 🔴 Confirmed Dead
- **Location**: `Photolala/Services/` and `Photolala/Views/`
- **Files**:
  - `TestCatalogGenerator.swift` - Test utility
  - `IAPTestView.swift` - IAP testing view
  - `ReceiptValidationTestView.swift` - Receipt testing
  - `ResourceTestView.swift` - Resource testing
  - `S3BackupTestView.swift` - S3 backup testing
- **Rationale**: Test code should not be in production
- **Action**: Move to debug-only target or remove

#### Partial/Incomplete Tests
- **Status**: ❓ Unknown
- **Files**: 
  - `SwiftDataCatalogTests.swift` - Check if tests are meaningful
- **Action**: Review test coverage and update or remove

### 3. Unused Models

#### PhotoReference
- **Status**: 🟢 Already Removed
- **Location**: N/A (was `Photolala/Models/PhotoReference.swift`)
- **Rationale**: Already removed, replaced by PhotoFile
- **Action**: None needed

#### SwiftDataCatalog.swift
- **Status**: 🟢 In Use
- **Location**: `Photolala/Models/SwiftDataCatalog.swift`
- **Rationale**: Contains SwiftData models used by V2 services
- **Dependencies**: PhotolalaCatalogServiceV2, S3CatalogSyncServiceV2
- **Action**: Keep

### 4. Duplicate/Redundant Code

#### Photo Loading Services
- **Status**: 🟢 Resolved
- **Finding**: Only `DirectoryPhotoProvider` exists (no `LocalPhotoProvider`)
- **Action**: No duplicates found

#### Catalog Services
- **Status**: 🟡 Technical Debt
- **Candidates**:
  - `PhotolalaCatalogService` (CSV) vs `PhotolalaCatalogServiceV2` (SwiftData)
  - Both are needed during migration period
- **Action**: Remove V1 after migration complete

#### Thumbnail Loading
- **Status**: ❓ Unknown
- **Candidates**:
  - Direct thumbnail loading in cells vs PhotoManager
  - Old thumbnail caching logic
- **Action**: Ensure all code uses PhotoManager

### 5. Platform-Specific Dead Code

#### tvOS Support
- **Status**: ❓ Unknown
- **Location**: `Platform/tvOS/`
- **Rationale**: Is tvOS actually supported/tested?
- **Action**: Verify if tvOS is a supported platform

### 6. Commented-Out Code

#### TODO/FIXME Comments
- **Status**: 🟡 Technical Debt
- **Count**: 37 occurrences found
- **Notable areas**:
  - S3 shard checksum verification
  - Metadata URL implementation
  - Archive date retrieval
  - Photo pinning feature
  - EXIF data loading
  - Help navigation
- **Action**: Create tickets for important TODOs, remove obsolete ones

### 7. Unused Utilities

#### Potential Candidates
- Old date formatting utilities (if using new ones)
- Unused extensions
- Debug/test helpers in production code

### 8. Migration-Related Dead Code

#### After SwiftData Migration Complete
- **Future Removal**:
  - CSV parsing in PhotolalaCatalogService
  - CSV catalog generation (non-S3)
  - Legacy catalog loading logic

## Investigation Commands

```bash
# Find unused Swift files
find . -name "*.swift" -type f | while read f; do
  basename=$(basename "$f" .swift)
  count=$(grep -r "$basename" . --include="*.swift" | grep -v "$f:" | wc -l)
  if [ $count -eq 0 ]; then
    echo "Potentially unused: $f"
  fi
done

# Find TODO/FIXME comments
grep -r "TODO\|FIXME\|HACK" . --include="*.swift"

# Find commented-out code blocks
grep -r "^[[:space:]]*//.*{" . --include="*.swift"

# Find files not imported anywhere
for f in Photolala/**/*.swift; do
  name=$(basename "$f" .swift)
  if ! grep -q "import.*$name\|$name\." Photolala/**/*.swift; then
    echo "Check: $f"
  fi
done
```

## Removal Process

1. **Identify**: Mark code as candidate in this document
2. **Verify**: Check all dependencies and usages
3. **Test**: Ensure tests pass without the code
4. **Remove**: Delete in a separate commit
5. **Document**: Update this file with removal date

## Completed Removals

### June 22, 2025
- (None yet)

## Next Steps

1. Run investigation commands
2. Review each candidate's actual usage
3. Start with confirmed dead code
4. Create individual commits for each removal
5. Update documentation as needed

## Notes

- Always err on the side of caution
- Keep code that might be needed for upcoming features
- Consider keeping examples/reference implementations
- Document why code was removed in commit messages
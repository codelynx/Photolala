# Photo Basket Star (Upload) Implementation Plan

## Goal
Enable the "Star" action from the basket browser so users can stage photos (local folders + Apple Photos) for upload to S3. “Starring” keeps the S3 catalog and object store in sync: any MD5 present in the catalog is considered starred, and removing it (unstar) clears the state. Implementation must support resume/retry, show progress, and remain backward compatible with existing catalogs.

## High-Level Workflow
```
User selects items → BasketActionService.starItems()
    → BasketUploadCoordinator orchestrates
         • ApplePhotoExporter (for Apple assets)
         • MD5 calculator / digest cache
         • LocalCatalogCache (CSV mirror + metadata cache)
         • S3Service uploads (photos, metadata, catalog)
         • CatalogDatabase.addOrUpdateEntry() / removeEntry()
    → Progress updates → BasketActionSheet UI
    → Checkpoint state for resume
```

Star state is derived purely from catalog membership: if a photo’s MD5 appears in the catalog, it’s starred; otherwise it is not. No additional Boolean column is persisted.

## Phase Breakdown

### Phase 1 – Data Model & Catalog Updates (Days 1-2)
1. **CatalogEntry helpers**
   - Provide convenience methods to check presence by MD5 (`contains(md5:)`).
2. **CatalogDatabase updates**
   - Add methods:
     - `upsertEntry(_ entry: CatalogEntry)` – adds or replaces a row for the MD5.
     - `removeEntry(md5:)` – removes catalog rows for unstar.
     - `entry(for md5:)` and `contains(md5:)` to query star status.
   - Keep CSV header unchanged (`photo_head_md5,file_size,photo_md5,photo_date,format`).
   - Parsing remains backward compatible (no new columns required).
3. **CatalogService extensions**
   - Expose public APIs to add/update/remove entries and to query star state.
   - Integrate with existing snapshot/merge logic.
4. **Metadata cache**
   - Ensure add/remove operations update any auxiliary metadata caches as needed.

### Phase 2 – Services (Days 3-4)
1. **`BasketActionService` (new)**
   - Public API: `func starItems(_ items: [BasketItem]) async throws` and future `unstarItems`.
   - Validates allowed sources (local, Apple; cloud is noop) and delegates to coordinator.
   - Emits structured progress updates (Combine publisher or async sequence).
2. **`BasketUploadCoordinator` (new actor)**
   - Responsibilities:
     - Apple photo export via `ApplePhotoExporter` (full image + metadata + optional thumbnail cached).
     - MD5 computation (reuse digest pipeline or implement streaming hasher).
     - Catalog preflight: ensure local CSV mirror matches S3 pointer (download if not).
     - Upload queue management (skip duplicates already in catalog by MD5).
     - Update catalog entries by adding/updating rows for each MD5.
     - Upload refreshed catalog and pointer file.
     - Checkpoint progress to disk for resume.
3. **`ApplePhotoExporter` helper**
   - Exports selected `PHAsset` to temporary directory (careful with sandbox scope).
   - Produces metadata struct used by upload coordinator.
   - Handles cleanup of temp files (after success or resume).
4. **`LocalCatalogCache` enhancements**
   - Store last-known catalog hash/location (`~/Library/Caches/Photolala/catalogs/s3/…`).
   - Provide merge/rebuild operations that rebuild the CSV without additional columns.

### Phase 3 – UI Integration (Days 5-6)
1. **PhotoCellView**
   - Optional: star overlay/indicator when catalog reports the MD5 as starred (can be deferred).
2. **PhotoBrowserView**
   - Add toolbar actions for `Star Selection` / `Unstar Selection` (enabled based on source).
   - Keyboard shortcuts: e.g., `S` (star), `⌥S` (unstar) – optional depending on UX.
   - Show toast/progress summary while star workflow runs.
3. **PhotoBasketHostView**
   - Hook existing star/unstar buttons to `BasketActionService`.
   - Display progress sheet with ability to cancel/pause.
4. **Menu commands**
   - Update `PhotolalaApp` (macOS) to include star/unstar commands (respecting context).

### Phase 4 – Upload & Catalog Sync (Week 2)
1. **MD5 computation pipeline**
   - Reuse existing digest service where possible (Photolala1 had digest queue).
   - Cache digests per photo to avoid recomputing.
2. **S3 integration**
   - Use `S3Service` to HEAD check existing objects (`photos/<userId>/<md5>.dat`) before uploading.
   - Upload new photo objects to `photos/<userId>/<md5>.dat` (multipart for large files).
   - Upload metadata/thumbnail payloads to their respective prefixes if required (e.g., `metadata/`, `thumbnails/`).
   - Upload optional thumbnail preview if available.
   - Update pointer `.photolala.md5` after CSV is refreshed.
3. **Catalog update**
   - After each batch, call `upsertEntry` for starred items and (later) `removeEntry` for unstar.
   - Regenerate CSV (preserve ordering defined in Photolala1, e.g., newest first).
   - Upload CSV and pointer atomically (ensure pointer updated last).
4. **Checkpoint/resume**
   - Persist queue state (items remaining, progress index, md5 cache, exported Apple temp paths) to disk.
   - On app launch, detect pending upload -> offer resume UI (re-export Apple assets if temp files expired).

### Phase 5 – Testing & Polish (Week 2-3)
1. **Unit tests**
   - Catalog parsing/writing remains compatible with legacy CSV (no extra columns).
   - `upsertEntry`/`removeEntry` operations update the CSV correctly.
   - `BasketUploadCoordinator` logic for duplicates, resume, Apple exports.
2. **Integration tests**
   - Mixed selection (local + Apple) -> ensure MD5 computed, uploads skipped when already on S3.
   - Offline failure/resume path.
   - Catalog conflict resolution when S3 updated externally (last action wins by overwriting row).
3. **Performance tuning**
   - Determine concurrency (e.g., 2–4 uploads at a time).
   - Provide accurate progress (count + bytes).
4. **UX refinements**
   - Confirm star indicators (if added) match catalog state.
   - Optional star filter in photo browser (deferred until after unstar).

## Key Considerations
- **Star state equals catalog membership**: no extra boolean field; catalog is the single source of truth.
- **Backward compatibility**: since the CSV format stays unchanged, legacy catalogs continue to load.
- **Conflict handling**: adopt “last action wins” when catalog changes are pushed to S3.
- **Apple Photos**: manage sandbox access to exported files (temp directory, cleanup).
- **Upload throttling**: avoid saturating network; reuse existing S3Service throttling if available.

## Open Questions
- Where exactly is the canonical catalog pointer file stored (confirm from docs)?
- How to detect/resume partially uploaded Apple Photos exports whose temp files were cleaned? (May require re-export on resume.)
- Do we need a star filter in UI for this phase or wait until post-unstar?

## Next Steps
- Confirm catalog pointer location + metadata format.
- Implement Phase 1 catalog helpers with unit tests.
- Prototype `BasketActionService` & coordinator skeleton, including Apple Photos export stub.
- Integrate uploads in Phase 4 after plumbing is stable.

# Photo Basket Implementation Plan (Photolala2)

## Overview
Bring the Photolala1 “basket” workflow into Photolala2 so users can collect photos from any source (local, cloud, Apple Photos) and run long-lived actions (starring, album membership, retrieval, deep archive, etc.) in batches. The feature must respect Photolala2’s dependency-injected browser architecture (`PhotoBrowserHostView` + providers), work on both macOS and iOS, and avoid regressing existing selection flows.

## Goals
- Support transient, multi-source photo collection with minimal UI friction.
- Reuse the existing photo browser UI (host + simplified view) via dependency injection rather than forked code.
- Provide a dedicated basket browser surface with batch actions and status.
- Keep security-scoped/local access working (re-use bookmark handling).
- Ensure actions run asynchronously with visible progress and error handling.

## Non-Goals
- Persisting basket contents across app launches (nice-to-have, optional extension).
- Implementing brand-new actions (e.g., export); focus on hooking into existing star/archive/album flows.
- Replacing current selection UI; the basket supplements it.

## Plan of Record

### Phase 0 – Research & Alignment (completed separately)
- ✅ Review Photolala1 basket model/views.
- ✅ Document current Photolala2 DI/browser architecture.

### Phase 1 – Core Basket Model (Week 1)
1. **Implement `PhotoBasket` singleton**
   - Modeled after Photolala1 but adapted to `PhotoBrowserItem` identifiers.
   - Provide APIs `add`, `remove`, `toggle`, `contains`, `clear`, `itemsPublisher`.
   - Store per-item metadata via lightweight struct; keep source hints (local/cloud/apple).
   - Reuse security-scoped URL support on iOS via bookmark cache.
2. **Introduce `BasketItemConvertible` abstraction**
   - Protocol bridging different source entities (`PhotoBrowserItem`, `PhotoFile`, `PhotoS3`, etc.).
   - Enables basket operations inside source-specific controllers without leaking implementation.
3. **Add unit tests**
   - Cover mixed-source add/remove/toggle behavior.
   - Verify bookmark resolution on iOS sandbox (mocked).

### Phase 2 – Basket Content Provider (Week 1-2)
1. **Create `BasketPhotoProvider`**
   - Implements `PhotoSourceProtocol` (read-only) backed by basket contents.
   - Generates `PhotoBrowserItem` array from basket metadata.
   - Bridges to full-size data via original sources (requires resolver delegation).
2. **Support metadata loading**
   - Provide `BasketMetadataResolver` that queries original sources/services to fetch file size/date.
   - Cache results to avoid repeated lookups.
3. **Test provider**
   - Ensure `PhotoBrowserHostView` can render basket items via provider without crashes.

### Phase 3 – UI Integration (Week 2)
1. **Toolbar integration**
   - Extend `PhotoBrowserHostView` (and simplified view) with optional basket button via DI flag.
   - Button toggles item membership (e.g., “Add to Basket” / “Remove from Basket”).
   - Display badge/count indicator via `PhotoBasket.shared` publisher.
2. **Basket Browser**
   - Implement `PhotoBasketHostView` that injects `BasketPhotoProvider` into existing `PhotoBrowserHostView`.
   - Support both platforms: macOS window (hook `PhotoWindowManager`), iOS navigation destination.
3. **Empty / success states**
   - Reuse `PhotoBrowserViewSimplified` empty-state customization to explain basket purpose.

### Phase 4 – Action Execution (Week 2-3)
1. **Define basket action service**
   - `PhotoBasketActionService` orchestrates star/unstar, album add/remove, deep archive, retrieve.
   - Accepts `BasketItem`s, resolves original source handles, and executes via existing services (S3, local, Apple).
   - Supports progress callbacks + cancelation (combine/async).
2. **Action UI**
   - Add batch action toolbar at top of `PhotoBasketHostView` (e.g., segmented buttons or menu).
   - Show progress overlay & errors per action.
3. **Post-action cleanup**
   - Option to clear basket after successful batch; configurable via confirmation sheet.

### Phase 5 – Polishing & QA (Week 3)
1. **Accessibility & UX**
   - Ensure buttons have labels, keyboard shortcuts on macOS.
   - Provide haptics/feedback on iOS add/remove.
2. **Performance validation**
   - Test with large baskets (hundreds of items) from mixed sources.
   - Verify asynchronous resolver doesn’t block UI.
3. **Regression tests**
   - Confirm existing selection flows (non-basket) remain unaffected.
   - Add snapshot/UI tests if feasible (especially for empty/loaded states).

## Architectural Notes
- **Dependency Injection**: `PhotoBrowserHostView` gains optional “basket capability” configurable by parent view. Production flows inject real services; previews/tests can inject mocks.
- **State Synchronization**: Basket model is the single source of truth (ObservableObject). UI binds to its publishers to keep counts and host environment in sync.
- **Security Scope**: Reuse `DefaultPhotoSourceFactory` bookmark handling to ensure items added from iOS folders remain accessible.

## Risks & Mitigations
- **Mixed-source metadata retrieval latency** → Use async tasks with caching + progress UI.
- **iOS bookmark invalidation** → Already covered by new bookmark refresh logic; add tests.
- **Action conflicts (batch star overlapping manual star)** → Basket actions should refresh main sources after completion to avoid stale UI.

## Deliverables
- `PhotoBasket.swift` (model + tests)
- `BasketPhotoProvider.swift`
- `PhotoBasketHostView`, `PhotoBasketActionToolbar`
- Toolbar integration PR touching `PhotoBrowserHostView`
- Documentation updates (`PhotoBasketNotes`, README snippets)
- Validation runs: local, cloud, Apple Photos scenarios


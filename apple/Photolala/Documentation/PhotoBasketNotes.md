# Photo Basket Port Notes

## Source (Photolala1)
- Singleton model `PhotoBasket` (`Photolala1/apple/Photolala/Models/PhotoBasket.swift`)
  - Handles mixed sources: local (`PhotoFile`), cloud (`PhotoS3`), apple (`PhotoApple`)
  - Tracks metadata, supports add/remove/toggle
  - Maintains `items: Set<BasketItem>` with size, archival state
- Basket browser UI (`PhotoBasketBrowserView.swift`) tied to shared model
- Photo selection overlay uses basket for multi-step operations
- Actions (star, add to album, retrieve, deep archive, delete) execute via basket

## Proposed Port Strategy
1. Re-implement `PhotoBasket` in Photolala2 as ObservableObject (shared singleton)
   - Use new `PhotoBrowserItem` + metadata map per source
   - Provide protocol-based APIs to avoid direct dependency on legacy models
2. Introduce `PhotoBasketStore` with persistence (optional) for session state
3. Create `PhotoBasketHostView` leveraging existing `PhotoBrowserHostView`
   - Build around `PhotoBasket` content provider (similar to `PhotoSource`) for reuse
4. Update toolbars (`PhotoBrowserViewSimplified`, `PhotoBrowserHostView`) to surface basket toggles
5. Implement action handlers (star/unstar, album ops, deep archive, retrieval) via dedicated command service
6. Ensure multi-platform support (macOS window + iOS navigation) using host view pattern

## Considerations
- Security scope: reuse same handling as local sources when adding to basket from iOS
- Cloud operations need to batch via async tasks with progress UI
- Persistence: optional; basket is primarily transient
- Testing: create sample sources (local/cloud) and verify toggling + action execution


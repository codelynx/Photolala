# Account Settings: Sign-Out & Account Deletion Implementation Plan

## Objective
Deliver a reliable account settings experience that cleanly signs users out across platforms and fully deletes cloud data when requested, while preserving local content and providing clear diagnostics for developer verification.

## Current State Snapshot
- `AccountManager.signOut()` only clears the session locally; validation is needed to ensure S3 credentials, cached uploads, and background tasks stop correctly.
- `AccountSettingsView` surfaces sign-out and deletion actions, but the flows depend on optimistic assumptions (e.g. `deleteAllUserData` succeeding) and lack granular error reporting or progress feedback.
- Developer diagnostics exist for sign-in (`PhotolalaAccountDiagnosticsView`), yet there is no equivalent coverage for sign-out or account-deletion edge cases.
- Documentation defines the expected S3 layout (`docs/cloud-user-account.md`, `docs/s3-cloud-features.md`) and the strict policies around provider linking/deletion, but code-level enforcement and audit logging need alignment.

## Deliverables
1. Hardened sign-out flow that revokes/clears credentials, cancels pending cloud operations, and resets UI state consistently.
2. Account deletion workflow that confirms identity, wipes S3 namespaces (`photos/`, `thumbnails/`, `catalogs/`, `users/`, `identities/` entries), evicts local caches (catalog store, thumbnail cache, staged uploads), and reports progress/errors with retry guidance.
3. Developer diagnostic hooks or tools to simulate sign-out/deletion paths for dev builds.
4. Updated documentation/tests covering the lifecycle expectations.

## Workstreams & Steps

### 1. Discovery & Design Validation
- Audit `AccountManager` for sign-out related helpers (session persistence, keychain storage, STS refresh tasks, upload queues).
- Trace account deletion callstack (`AccountSettingsView.Model.deleteAccount`, S3 service, Lambda usage) and note gaps versus docs (identity removal, audit logging).
- Confirm backend/Lambda capabilities for irreversible deletion and determine whether additional endpoints are required.
- Draft UX flows for multi-step confirmations, progress indicators, and post-action states (e.g. app reset to local mode).

### 2. Sign-Out Flow Improvements
- Update `AccountManager.signOut()` to:
  - Revoke/clear STS credentials and cancel in-flight AWS clients.
  - Reset cached photo sync queues (including `PhotoBasket` operations), on-disk thumbnail/catalog caches, and background tasks.
  - Purge local secure storage of provider tokens while leaving local photos intact.
- Ensure UI layers (`ContentView`, `PhotoSourceSelector`, `AccountSettingsView`) observe a published auth state so the app transitions to local-only mode instantly.
- Add telemetry/logging hooks for diagnostics builds to trace sign-out steps (mirroring the sign-in diagnostic hooks).
- Write unit/integration coverage to assert session storage is cleared and no residual STS credentials remain.

### 3. Account Deletion Workflow
- Introduce a dedicated service method (e.g. `AccountDeletionService`) that orchestrates:
  - Reauthentication (existing `ReauthenticationView`) and token handoff.
  - Lambda call to delete identity mappings and issue a server-side purge job.
  - Client-side cleanup: `S3Service.deleteAllUserData`, cached catalogs/thumbnails, staged upload artifacts, identity caches, and credentials, with paginated S3 deletes + exponential backoff retries for large datasets.
- Implement staged feedback in UI:
  1. Confirmation screen (with explicit warnings).
  2. Progress sheet showing each namespace being deleted with retry/backoff logic.
  3. Success/failure outcome screen with guidance.
- Handle partial failures gracefully (e.g. S3 delete succeeded but identity removal failed) and surface support-ready diagnostics.
- Verify behavior against repository policies: no merge support, irreversible deletion, respect for privacy obligations.

### 4. Developer Diagnostics & Tooling
- Extend `PhotolalaAccountDiagnosticsView` or add a new diagnostics pane to trigger sign-out/deletion flows with test doubles, capturing logs similar to sign-in diagnostics.
- Provide exportable logs (step-by-step) for QA/manual testing.
- Optionally add CLI script (under `scripts/`) to simulate deletion using dev credentials for backend validation.

### 5. Documentation & Testing
- Update `docs/cloud-user-account.md` and `docs/test-environment.md` with new flows, including required test credentials/deletion safeguards.
- Add automated tests where feasible (e.g. Swift async tests for `AccountManager.signOut`, integration tests behind `#if DEVELOPER`).
- Document manual test matrix (iOS/macOS, Apple/Google providers, linked accounts, offline scenarios).

## Risks & Mitigations
- **Partial Cloud Deletes:** Use idempotent Lambda operations and client-side retries; stage deletion per namespace to resume after failures.
- **Credential Leakage Post-Sign-Out:** Validate via diagnostics and tests that secure storage is cleared; consider keychain enumeration assertions in tests.
- **User Confusion:** Provide clear UI copy and post-action states; ensure local-only mode messaging clarifies photos remain on device.
- **Back-end Gaps:** Coordinate with backend for identity removal endpoints and align on audit logging requirements.

## Success Criteria
- Manual QA can run scripted sign-out/deletion scenarios without residual cloud data or lingering authentication state.
- Diagnostics logs capture full lifecycle steps for troubleshooting.
- Updated documentation and tests cover the new flows, and no regressions in existing authentication features.

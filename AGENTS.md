# Repository Guidelines

## Project Structure & Module Organization
The SwiftUI client lives in `apple/Photolala/`, with UI in `Views/`, AWS integrations in `Services/`, and shared helpers in `Utilities/`. Tests sit in `apple/PhotolalaTests/`, combining `XCTestCase` suites with lightweight `@Test` specs documented in `docs/test-environment.md`. Android currently ships only generated credential sources at `android/app/src/main/java/com/electricwoods/photolala/credentials/`; treat that directory as output until the app port lands. Long-form references and runbooks live in `docs/`, automation sits in `scripts/`, and machine-local secrets belong in `.credentials/` or `untracked/`. Keep `Photolala1/` read-only unless you are mining older behaviour.

## Build, Test, and Development Commands
- `cd apple && xcodebuild -scheme Photolala -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build` — compile the iOS target.
- `cd apple && xcodebuild test -scheme Photolala -destination 'platform=macOS'` — run both XCTest and Swift Testing suites.
- `cd .credential-tool && swift build -c release` — build the `credential-code` generator.
- `./scripts/generate-credentials.sh` then `./scripts/validate-credentials.sh` — refresh and verify encrypted credentials after updating `.credentials/`.

## Coding Style & Naming Conventions
Tabs (width 4) are the default per `.editorconfig`; do not reformat to spaces. Follow Swift naming (`PascalCase` types, `camelCase` members) and keep nested view models alongside their views as in existing files. Prefer async/await APIs, structured logging via `Logger(subsystem:"com.photolala",category:...)`, and adjust generator templates in `.credential-tool` instead of editing produced credential files.

## Testing Guidelines
Run the simulator test command above for CI parity, and keep `XCTestCase` method names prefixed with `test`. Remote tests should target the `photolala-dev` bucket under a `__test__/` prefix and clean up objects. Before exercising networked cases, ensure `./scripts/validate-credentials.sh` passes and lean on service factories or mocks to keep execution under a few seconds. Capture any new coverage notes in `docs/test-environment.md`.

## Commit & Pull Request Guidelines
Commits use short, imperative subjects (`Add test documentation`, `Refactor S3Service`) and stay scoped to a single concern. Pull requests need a summary, the exact build or test commands you ran, links to issues, and screenshots or logs when behaviour shifts. Highlight credential impacts explicitly and state whether generated files were refreshed by the scripts.

## Security & Credential Workflow
Never commit raw secrets; store them under `.credentials/` and rely on `credential-code` to emit encrypted Swift and Kotlin artifacts. Rebuild the tool and re-run the generation script whenever inputs change, and keep `CREDENTIAL_PLAN.md` updated when new secrets or policies are introduced.

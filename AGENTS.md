# AGENTS.md

This file provides guidance to coding agents working in this repository.

## Project

RunCat Neo is a macOS menu-bar app that animates a running cat (or fish — any custom runner) in the status bar to reflect system load, with support for a second runner running alongside the primary one. Target: macOS 26.3+, built with Xcode 26.2+, Swift 6.2 (with `ExistentialAny` upcoming feature enabled).

## Build & Test

The app shell lives in `RunCatNeo.xcodeproj` and embeds the local Swift Package `LocalPackage/`, which contains essentially all source code. The `xcode` MCP tools (`mcp__xcode__BuildProject`, `mcp__xcode__RunAllTests`, etc.) are the preferred way to build and run tests — fall back to `xcodebuild` only when MCP is unavailable.

Tests live only in the SPM package (`DataSourceTests`, `ModelTests`) and use Swift Testing (`@Test`, `#expect`). There are no UI tests and no linter configured.

On the `xcodebuild` fallback only: run it from `LocalPackage/` with the `LocalPackage-Package` scheme on `platform=macOS,arch=arm64`. SwiftPM generates that scheme for the package, so it is not listed at the repository root — from there the equivalent is the `RunCatNeo` scheme and its `UnitTest.xctestplan`, which cover the same two targets. CI takes the former path (`working-directory: LocalPackage`).

CI (`.github/workflows/test.yml`) runs on tag pushes only — local test runs are the primary verification loop during development.

### Command-line app build

Building the app target with `xcodebuild` from the repository root needs two extra settings that plain `xcodebuild build` does not survive:

- `-skipPackagePluginValidation` — the LicenseList dependency ships a build tool plugin (`PrepareLicenseList`) that xcodebuild refuses to run without explicit approval. CI passes the same flag.
- Ad-hoc signing — automatic signing requires a "Mac Development" certificate for team `VJ5N2X84K8`; on machines without one, override with `CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`. The only entitlement is `com.apple.security.files.bookmarks.app-scope`, which needs no provisioning profile.

Verified working invocation for a local Release app bundle:

```sh
xcodebuild -project RunCatNeo.xcodeproj -scheme RunCatNeo \
  -configuration Release -derivedDataPath build/DerivedData \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
```

When a pipeline pipes xcodebuild output (e.g. into `tail`), the pipeline exit code masks xcodebuild's — check the log for `** BUILD SUCCEEDED **` or use `set -o pipefail`.

## Custom Runners

Custom runners are not bundled resources — the app loads them at runtime from `~/Library/Application Support/RunCatNeo/`:

- `CUSTOM_RUNNERS.json` — an array of runner records `{id, name, isTemplate, frameOrder}`, where `id` is the directory name (the UI uses UUIDs) and `frameOrder` is a plain `[Int]` decoded as `.custom(order)`.
- `<id>/frame-<n>.png` — one PNG per frame; custom frames are always addressed as `frame-<n>.png` regardless of the runner name.

Silhouette artwork should be saved with `isTemplate: true` so it follows the menu-bar tint; full-color artwork needs `isTemplate: false`. Seeding this directory is the fastest way to test runner loading without going through the settings UI.

## Architecture (LUCA)

The codebase follows the [LUCA architecture](https://github.com/Kyome22/LUCA) — three SPM library targets with strict, one-way layering: `DataSource` (leaf) ← `Model` ← `UserInterface`. Never invert.

- **`DataSource`** — `Entities`, `Dependencies` (conform to `DependencyClient`, expose `liveValue` + `testValue`), `Repositories`.
- **`Model`** — `Services` (`MetricsService`, `RunnerService`, `LogService`), `Stores` (`@MainActor @Observable`, conform to `Composable`: `Dashboard`, `RunnerBar`, `MetricsBar`, settings stores), `AppDependencies`, `AppDelegate`. Application logic lives here.
- **`UserInterface`** — SwiftUI `Scenes` (`RunnerBarScene`, `MetricsBarScene`, `SettingsWindowScene`), `Views`, and resources in `UserInterface/Resources/`.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the authoritative rules — including how `DependencyClient` couples with test design (thin, untested boundaries; logic lives in `Service`/`Store`), the Composable/Store pattern (Views mutate state only via `store.send(Action)`), cross-cutting state via `AppStateClient` and `AppDependencies`, and resource-layering constraints (`Model` must not reference Asset/String Catalog resources).

## Code Conventions

`CODING_STYLE.md` defines line-level style rules (language, naming, comments, formatting, license headers). Architecture-level rules live in `ARCHITECTURE.md`. Contribution process rules (one PR per concern, PR/issue templates, review etiquette, localization policy, feature-request cost/benefit bar) live in `CONTRIBUTING.md`.

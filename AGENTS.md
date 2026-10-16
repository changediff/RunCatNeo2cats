# AGENTS.md

This file provides guidance to coding agents working in this repository.

## Project

RunCat Neo **Twocats** is a personal fork of [RunCat Neo](https://github.com/runcat-dev/RunCatNeo) (by Kyome22 / Takuto Nakamura, forked at upstream commit `b3b1543`) — a macOS menu-bar app that animates a running cat (or any custom runner) in the status bar to reflect system load. Target: macOS 26.3+, built with Xcode 26.2+, Swift 6.2 (with `ExistentialAny` upcoming feature enabled).

The fork lives at `changediff/RunCatNeo2cats` (renamed from `RunCatNeo2`; old URLs redirect via GitHub). All work happens on the `twocats` branch — `main` still sits at the upstream base and has not been merged. Fork-specific behavior:

- **Two runners on screen** — the menu bar shows the primary plus an optional secondary runner, animated and tinted independently; the secondary is selectable/none-able from the status-item menu.
- **Configurable runner gap** — 0–20 px slider (Settings → Runner → Appearance), default 3 px, persisted via `UserDefaultsRepository`.
- **Separate bundle ID** — `com.changediff.twocats.RunCatNeo`, so it can run alongside the original (`com.kyome.Neo.RunCat`) with independent preferences. The product name (and therefore the `.app`) is `RunCatNeo2cats`; the display name stays "RunCat Neo".

GitHub Pages (https://changediff.github.io/RunCatNeo2cats/) publishes from `/docs` on the `twocats` branch. ⚠️ Before merging `twocats` into `main` and deleting the branch, switch the Pages source to `main /docs` in repo settings, or the site will 404.

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

### Version scheme

The displayed version is stamped automatically on every build: the "Set twocats version suffix" run-script phase (last build phase; the reason `ENABLE_USER_SCRIPT_SANDBOXING = NO`) rewrites `CFBundleShortVersionString` in the built product to `$CURRENT_PROJECT_VERSION.twocats.<short HEAD commit>` (e.g. `1.0.3.twocats.1926dee`). `CURRENT_PROJECT_VERSION` tracks the upstream release — bump it when merging a new upstream tag. Never hardcode the suffix; it follows the commit being built.

## Custom Runners

Custom runners are not bundled resources — the app loads them at runtime from `~/Library/Application Support/RunCatNeo/`:

- `CUSTOM_RUNNERS.json` — an array of runner records `{id, name, isTemplate, frameOrder}`, where `id` is the directory name (the UI uses UUIDs) and `frameOrder` is a plain `[Int]` decoded as `.custom(order)`.
- `<id>/frame-<n>.png` — one PNG per frame; custom frames are always addressed as `frame-<n>.png` regardless of the runner name.

Silhouette artwork should be saved with `isTemplate: true` so it follows the menu-bar tint; full-color artwork needs `isTemplate: false`. Seeding this directory is the fastest way to test runner loading without going through the settings UI.

The `runners/` directory at the repository root holds raw frame assets for the local runner collection — 10 custom runners in total: `fishman-frames` plus 9 ported from the closed-source App Store RunCat (`com.kyome.RunCat`): the special-colored `flash-cat`, `golden-cat`, `metal-cluster-cat`, `entaku`, `maneki-neko`, `sushi`, `uhooi`, plus the silhouettes `dinosaur` and `penguin` (`isTemplate: true`; the other 49 ported silhouettes were dropped by choice). These assets are kept **local only — git-ignored, must not be committed or redistributed**: the artwork remains Kyome22's; personal use only. Official display names come from the app's `RunnerName.strings`. To harvest more runners from that app, pull the APNG Data assets out of its `LocalPackage_UserInterface.bundle/Contents/Resources/Assets.car` (one APNG per runner; read `Data Length` from `xcrun assetutil --info` to slice the PNG out of the car byte stream) and split frames with ImageIO (`CGImageSourceCreateImageAtIndex`).

## Architecture (LUCA)

The codebase follows the [LUCA architecture](https://github.com/Kyome22/LUCA) — three SPM library targets with strict, one-way layering: `DataSource` (leaf) ← `Model` ← `UserInterface`. Never invert.

- **`DataSource`** — `Entities`, `Dependencies` (conform to `DependencyClient`, expose `liveValue` + `testValue`), `Repositories`.
- **`Model`** — `Services` (`MetricsService`, `RunnerService`, `LogService`), `Stores` (`@MainActor @Observable`, conform to `Composable`: `Dashboard`, `RunnerBar`, `MetricsBar`, settings stores), `AppDependencies`, `AppDelegate`. Application logic lives here.
- **`UserInterface`** — SwiftUI `Scenes` (`RunnerBarScene`, `MetricsBarScene`, `SettingsWindowScene`), `Views`, and resources in `UserInterface/Resources/`.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the authoritative rules — including how `DependencyClient` couples with test design (thin, untested boundaries; logic lives in `Service`/`Store`), the Composable/Store pattern (Views mutate state only via `store.send(Action)`), cross-cutting state via `AppStateClient` and `AppDependencies`, and resource-layering constraints (`Model` must not reference Asset/String Catalog resources).

## Code Conventions

`CODING_STYLE.md` defines line-level style rules (language, naming, comments, formatting, license headers). Architecture-level rules live in `ARCHITECTURE.md`. Contribution process rules (one PR per concern, PR/issue templates, review etiquette, localization policy, feature-request cost/benefit bar) live in `CONTRIBUTING.md`.

## Known Follow-ups

- When upstream `runcat-dev/RunCatNeo` moves ahead, add a remote `upstream` and rebase/merge `twocats` onto it occasionally.
- If the fork is ever distributed beyond personal use: re-review signing/notarization against App Store requirements, rework the donation product IDs (`DonationProduct.swift`, `RunCatNeo.storekit`), and remove/replace the extracted runner artwork in `runners/`.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ForYouAndMe** is an iOS CocoaPods framework (+ Example app) for building research study mobile apps. It handles onboarding, surveys, diary notes, health data collection, wearable integrations, and task management. Deployment target: iOS 15.6, Swift 5.2+.

The pod version is defined in `ForYouAndMe.podspec` (`s.version`). Consuming apps (e.g. BetaTrack, CZI) reference it from the public GitHub repo via tag-based version pinning in their Podfiles.

## Build & Run Commands

```bash
# Install dependencies (run from Example/ directory)
cd Example && pod install

# Open workspace (NEVER open .xcodeproj directly)
open Example/ForYouAndMe.xcworkspace

# Build from command line
xcodebuild -workspace Example/ForYouAndMe.xcworkspace -scheme ForYouAndMe-Example -sdk iphonesimulator -configuration Debug build

# Run tests
xcodebuild -workspace Example/ForYouAndMe.xcworkspace -scheme ForYouAndMe-Example -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' test

# Lint the podspec
pod lib lint ForYouAndMe.podspec

# SwiftLint (runs via CocoaPods build phase)
# Config: .swiftlint.yml — 140 char line length, identifier names 2-50 chars
```

## Required Setup Files (not in git)

The Example app needs two plist files that are downloaded from secure storage during CI:
- `Example/ForYouAndMe/GoogleService-Info.plist` — Firebase config
- `Example/ForYouAndMe/ProjectInfo.plist` — study config (`api_base_url`, `oauth_base_url`, `study_id`, `pin_code_suffix`). A sample exists as `ProjectInfo_sample.plist`.

## Architecture

**MVVM-C (MVVM + Coordinators)** with a service locator pattern.

### Service Layer (`Services.swift`)
`Services.shared` is the central singleton that wires everything together:
- `repository: Repository` — data access (wraps `NetworkApiGateway` via Moya)
- `navigator: AppNavigator` — all navigation and coordinator management
- `analytics: AnalyticsService` — Firebase analytics
- `healthService` / `sensorKitService` / `terraService` — health data collection (conditional on `HEALTHKIT` compilation flag)
- `deeplinkService`, `cacheService`, `deviceService`, `mirSpirometryService`

Entry point: `FYAMManager.startup()` called from the host app's `AppDelegate`.

### Navigation
`AppNavigator` (large file) manages the entire app flow. Section-specific coordinators handle sub-flows (onboarding, surveys, video diary, opt-in, spirometry, etc.). No storyboards — all UI is programmatic using **PureLayout**.

### ViewControllers
All inherit from `BaseViewController` which provides shared access to services (`navigator`, `repository`, `analytics`) and manages the floating action button (FAB) for diary entries.

### Networking
- `DefaultService` enum defines 100+ API endpoints
- `NetworkApiGateway` implements the Moya-based network layer
- `TestNetworkApiGateway` provides stubs when `Constants.Test.NetworkStubsEnabled` is true (DEBUG only)
- Custom JSON mapping via `Japx` + `ModelMapper/` (protocol: `Mappable`, `Convertible`)

### Reactive Programming
RxSwift throughout — all async operations return `Single<T>` or `Observable<T>`. `DisposeBag` for memory management.

### Compilation Flags
- `HEALTHKIT` — enables HealthKit, SensorKit, and Terra integrations. Set in Podfile `post_install` via `SWIFT_ACTIVE_COMPILATION_CONDITIONS`.

## Key Directories

```
ForYouAndMe/Classes/
├── Entities/           # Data models (Codable/Mappable)
├── Services/           # Business logic, networking, permissions, health/sensor data
│   ├── Network/        # Moya API gateway, endpoints
│   ├── Permission/     # HealthKit, SensorKit, Location, Motion permissions
│   └── MirSpirometry/  # Spirometer device integration (vendored xcframework)
├── UI/
│   ├── Navigator/      # AppNavigator + ~24 section coordinators
│   ├── ViewControllers/# ~54 screens
│   ├── Views/          # ~61 reusable components
│   └── Style/          # Theming, color palette, font styles
└── Utility/            # Extensions

ModelMapper/            # Custom JSON mapping library
Example/                # Host app, tests, Podfile
```

## Git Workflow & Branching

**Git-flow model** with two long-lived branches and two remotes:

| Branch | Purpose |
|--------|---------|
| `develop` | Integration branch — all feature/bugfix PRs merge here |
| `master` | Release branch — receives merges from develop for releases |

**Remotes:**
| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `git@bitbucket.org:toconsulting/4youandmeios.git` | Internal (Bitbucket) — PRs, CI |
| `github` | `https://github.com/4YouandMeData/4YouandMeiOS.git` | Public — pod source for consuming apps |

**Branch naming:** `feature/FUAM-XXXX-short-description` or `bugfix/FUAM-XXXX-short-description`.

**PR workflow:** Feature/bugfix branches are created from `develop`, PRs are opened on Bitbucket (`origin`), and merged back into `develop`.

## Release & Versioning

Releases follow a strict sequence:

1. **Bump version** — update `s.version` in `ForYouAndMe.podspec` on `develop`, commit (`chore: Bump pod version to X.Y.Z`)
2. **Update CHANGELOG.md** — add release notes on `develop`
3. **Push develop** — to both `origin` and `github`
4. **Merge to master** — `git checkout master && git merge develop`
5. **Tag from master** — `git tag X.Y.Z` (lightweight tag on the version-bump commit)
6. **Push master + tag** — to both remotes: `git push origin master --tags && git push github master --tags`

**Important:** Tags MUST be created from `master`, not `develop`. The podspec `s.source` references `github` as the pod source repo, so the tag must exist there for `pod install` to work in consuming apps.

**Consuming apps** add the pod in their Podfile like:
```ruby
pod 'ForYouAndMe', '~> 0.98.16'
```
They pull from the public GitHub repo via the tag. After a release, consuming apps run `pod update ForYouAndMe` to pick up the new version.

## CI/CD

Azure DevOps pipeline (`azure-pipelines.yml`): triggers on `develop` and `master`, installs certs/profiles, runs `pod install`, downloads secure plists, builds and tests on simulator, then packages IPA.

## Jira

Project board is **FUAM** on [bdx.atlassian.net](https://bdx.atlassian.net). See `jira.md` for the current iOS backlog. To refresh it, follow the update instructions at the bottom of that file.

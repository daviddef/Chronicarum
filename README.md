# Chronicarum

Cultural heritage platform — an interactive map of historically significant sites, with a
conquest timeline that overlays empire borders from 500 BC to 1920 AD.

- `Chronicarum/` — SwiftUI iOS app (iOS 17+)
- `chronicarum.html` — the web prototype, and the source of truth for site content and
  timeline polygon data
- `HANDOFF.md` — original porting notes

## Building

The Xcode project is generated from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen), which is the source of truth for
target settings. `Chronicarum.xcodeproj` is committed so the app opens in Xcode without
extra tooling, but **after adding or removing a source file, regenerate it**:

```sh
brew install xcodegen   # once
xcodegen generate
```

Then open `Chronicarum.xcodeproj` and run, or build from the command line:

```sh
xcodebuild -project Chronicarum.xcodeproj -scheme Chronicarum \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Location permission is declared via `INFOPLIST_KEY_*` build settings in `project.yml`
rather than a checked-in `Info.plist`.

## Status

Working: map with site markers, era/type/tier filters, empire polygon overlay across all
seven timeline periods, "locate me", site detail sheets, search, bookmarks.

Known gaps:

- **Site content is mostly empty** — 11 of 12 sites have empty `chapters` arrays; only the
  Colosseum is written. The prose exists in `chronicarum.html` and needs porting.
- **No site photos** — `SiteHeroView` shows an emoji placeholder pending an image source.
- Data is hardcoded in `SiteData.swift`; Phase 2 is the UNESCO Open Data feed.
- Bookmarks/visited are in-memory only — `PersistenceService` is not yet wired up.

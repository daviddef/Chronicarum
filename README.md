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

## Data

Two layers (see [`scripts/`](scripts/)):

- **~123 featured sites** — hand-authored in `Chronicarum/Models/SiteData.swift`, each with
  a tagline, four facts, and a multi-chapter storyboard.
- **~14k bulk sites** — `Chronicarum/Resources/bulk_sites.json`, imported from Wikidata
  (UNESCO + castles + notable museums) and decoded at runtime by `BulkData.swift`. These
  carry a name, place, type, best-effort era, and a one-line description. They are
  `tier: 2`, so raising the significance filter shows the featured layer alone.

The map culls to the visible region before clustering, so the on-screen marker count stays
near ~100 regardless of catalogue size.

## Status

Working: clustered map of ~14k sites, era/type/tier filters, empire polygon overlay across
all seven timeline periods, "locate me", site detail sheets, search, bookmarks.

Known gaps:

- **No site photos** — `SiteHeroView` shows an emoji placeholder pending an image source.
- **Travel/visa fields are hardcoded** on featured sites and will go stale.
- Bookmarks/visited are in-memory only — `PersistenceService` is not yet wired up.
- A handful of featured sites carry "Do Not Travel" advisories (Bagan, Krak des
  Chevaliers, the Russia entries) — honestly documented but not currently visitable.

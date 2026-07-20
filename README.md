# Chronicarum

Cultural heritage platform — an interactive map of historically significant sites, with a
conquest timeline that overlays empire borders from 500 BC to 1920 AD.

- `Chronicarum/` — SwiftUI iOS app (iOS 17+)
- `chronicarum.html` — the web prototype, and the source of truth for site content and
  timeline polygon data
- `HANDOFF.md` — original porting notes
- `ROADMAP.md` — what's done, where we are, what's next

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
- **~143k bulk sites** — `Chronicarum/Resources/bulk_sites.json`, imported from Wikidata
  (UNESCO + castles + museums + monuments + archaeological sites) and decoded at runtime
  by `BulkData.swift`. These carry a name, place, type, best-effort era, and a one-line
  description. They are `tier: 2`, so raising the significance filter shows the featured
  layer alone.

The map culls to the visible region before clustering, so the on-screen marker count stays
near ~100 regardless of catalogue size.

**Photos** come from Wikimedia Commons (Wikidata P18), loaded on demand via
`Special:FilePath` — 93% of bulk and 80% of featured sites have one; the rest fall back to
an era-tinted glyph. Each photo shows its author and licence (e.g. "FeaturedPics · CC BY-SA 4.0")
and links to its Commons file page — most of these licences require naming the author.

## Status

Working: clustered map of ~143k sites with photos, era/type/tier filters, empire polygon overlay across
all seven timeline periods, "locate me", site detail sheets, search, bookmarks.

Known gaps:

- **Travel/visa fields are hardcoded** on featured sites. The UI now says when they
  were researched and flags sites under advisories, but they still want a live source.
- Bulk sites carry only a one-line description; enriching them is optional future work.

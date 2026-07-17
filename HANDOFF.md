# Chronicarum iOS — Claude Code Handoff

## What This Is

SwiftUI project skeleton for the Chronicarum cultural heritage platform — the iOS counterpart of `chronicarum.html`. All models, view models, and view structure are in place. The app compiles and navigates; it needs the MapKit overlay work and Xcode project file to become a runnable target.

---

## Project Structure

```
Chronicarum/
├── ChronicArumApp.swift          — App entry point, injects environment objects
├── Models/
│   ├── Site.swift                — Core data model (Era, SiteType, Fact, Chapter, Site)
│   ├── Empire.swift              — Conquest timeline models (Empire, TimelinePeriod, NameChange)
│   ├── SiteData.swift            — All 12 V1 sites hardcoded (add UNESCO JSON feed later)
│   └── TimelineData.swift        — 2 of 7 conquest periods; 5 more need porting from HTML
├── ViewModels/
│   ├── MapViewModel.swift        — Map region, filters, site selection, conquest timeline state
│   └── SiteViewModel.swift       — Search, bookmarks, visited, nearby sites
├── Services/
│   ├── LocationService.swift     — CLLocationManager wrapper (Combine)
│   └── PersistenceService.swift  — UserDefaults bookmarks/visited (swap to CloudKit in v2)
└── Views/
    ├── ContentView.swift         — Tab bar root (Map / Explore / Saved)
    ├── Map/
    │   ├── MapRootView.swift     — Primary map host
    │   ├── SiteMarkerView.swift  — Per-site map annotation
    │   ├── MapControlsView.swift — +/- / reset / locate / conquest buttons
    │   ├── MapTopBarView.swift   — Wordmark + filter button
    │   ├── ConquestTimelineBar.swift — Bottom timeline bar when conquest is active
    │   └── MapFilterView.swift   — Sheet for era/type/tier filters
    ├── Sites/
    │   └── SiteDetailView.swift  — Full storyboard sheet (chapters, facts, travel, nearby)
    ├── Explore/
    │   └── ExploreView.swift     — Searchable list with era filter chips
    └── Settings/
        └── SavedView.swift       — Bookmarked / Visited tab view
```

---

## Immediate Tasks for Claude Code

### 1. Create Xcode project
- Target: iOS 17+, SwiftUI lifecycle
- Bundle ID: `com.chronicarum.app`
- Add all `.swift` files in this folder
- Required capabilities: **Location When In Use**, **Maps**
- Add `NSLocationWhenInUseUsageDescription` to Info.plist

### 2. Complete TimelineData.swift
Port the remaining 5 periods from `chronicarum.html` `TIMELINE_DATA`:
- 650 AD (Umayyad Caliphate)
- 1250 AD (Mongol Empire peak)
- 1500 AD (Ottoman / Age of Exploration)
- 1800 AD (Napoleon / British Empire)
- 1920 AD (Post-WWI / British Empire at greatest extent)

The polygon data is in `TIMELINE_DATA` in `chronicarum.html` (available separately). Use the same `[lon, lat]` pairs — Swift converts them in `Empire.coordinates`.

### 3. Wire LocationService into MapViewModel
`MapViewModel` has stubs for `isLocating` and `userLocation`. Inject `LocationService` as a dependency and pipe `locationService.$userLocation` into `mapVM.userLocation`.

### 4. Empire polygon overlay on MapKit
`ConquestTimelineBar` drives the timeline state. When `timelineState.isVisible == true`, render `MKPolygon` overlays for each empire in the current period. Use `MKMapViewRepresentable` wrapping `MKMapView` for overlay support (SwiftUI's `Map` doesn't support custom overlays natively until iOS 17 `MapPolygon`).

Option A (iOS 17+): Use `MapPolygon` in the new SwiftUI Map API.
Option B (iOS 16 compatible): `UIViewRepresentable` wrapping `MKMapView` with a `MKMapViewDelegate` that renders `MKPolygon` overlays.

Each empire's color is `empire.color` (hex string — convert with `Color(hex:)`).

### 5. Add Assets.xcassets colour tokens
- `AccentGold`: `#C9A84C` (appears as `Color("AccentGold")` in several views)
- App icon placeholder

### 6. Chapter HTML rendering
`ChapterContentView` currently strips HTML tags. Replace with a `WKWebView` wrapped in `UIViewRepresentable` for chapters that contain `<p>`, `<strong>`, etc. Or use `AttributedString` with `.init(html:)` for lightweight rendering.

### 7. Site photos
`SiteHeroView` shows an emoji placeholder. Add photo URLs to `Site` and replace with `AsyncImage`.

---

## Design Tokens

| Token | Value | Usage |
|---|---|---|
| Accent Gold | `#C9A84C` | Era: Ancient, titles, active states |
| Classical Red | `#C05538` | Era: Classical |
| Medieval Blue | `#4A7FC1` | Era: Medieval |
| Renaissance Green | `#4F8A5C` | Era: Renaissance |
| Modern Gray | `#6B7280` | Era: Modern |

All defined in `SiteMarkerView.swift` and used via `Color(hex:)` extension. Move to a `DesignTokens.swift` file and `Assets.xcassets` for production.

---

## Data Notes

- `SiteData.swift` has all 12 V1 sites. Only `colosseum` has full chapter content — the others have empty chapter arrays as stubs.
- `TimelineData.swift` has 2 of 7 periods. A `// TODO:` comment marks where the rest belong.
- Phase 2 data source: UNESCO Open Data API at `https://whc.unesco.org/en/list/` — structured JSON feed available.

---

## What chronicarum.html Is

The web prototype at `chronicarum.html` is the source of truth for:
- All site content (chapters, facts, taglines)
- The full conquest timeline polygon data
- Visual design decisions

Reference it when porting content and for the conquest overlay polygon coordinates.

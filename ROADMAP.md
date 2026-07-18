# Chronicarum Roadmap

Where the project has been, where it is now, and what's left. Newest work at the bottom
of each done-list. Commits referenced by short SHA.

---

## Phase 0 — Skeleton (inherited)

The starting point: a SwiftUI project that modelled the app but could not build.

- [x] Models, view models, services, view structure in place (`HANDOFF.md`)
- [x] Web prototype `chronicarum.html` as the source of truth

## Phase 1 — Make it build, run, and work

- [x] Generate the Xcode project from `project.yml` (XcodeGen) · `ba197bf`
- [x] Fix the one compile error; app builds and launches on simulator
- [x] Port all 7 conquest-timeline periods, verified byte-identical to the prototype
- [x] Render empire polygons via the iOS-17 `MapPolygon` API (Map API migration)
- [x] Wire `LocationService` into the map; fix the location-denied hang
- [x] Fix flat-degree distance math in `nearestSite` / `nearbySites`
- [x] Fix the filter button hidden under the controls rail
- [x] Install and run on a physical iPhone (code signing) · `2c2591a`
- [x] Chapter HTML rendering — a small `<p>`/`<strong>` parser, unit-tested · `44d49ef`
- [x] Sacred sites get faith-appropriate map icons, not one torii for all · `c9ec29b`

## Phase 2 — Content: from a handful to thousands

- [x] Port the prototype's 24 chapters / 96 facts (13 featured sites) · `44d49ef`
- [x] Research + add 60 world sites; extend the taxonomy · `e99c8b3`
- [x] Research + add 50 castles and monuments worldwide · `556af88`
- [x] Cluster map markers by zoom so dense regions stay legible · `b87c81f`
- [x] Bulk layer: ~14k sites from Wikidata, loaded from bundled JSON at runtime · `f49741b`
- [x] Widen the bulk import to ~24k (added monuments + archaeological sites). Two
      sitelink bands lost to Wikidata 502s were recovered on retry, so nothing was
      silently dropped. 24,281 sites total, verified rendering smoothly.

## Phase 3 — Depth and durability (not started)

Ordered by my sense of value. None of these are begun.

- [ ] **◀ YOU ARE HERE** — **Site photos**: `SiteHeroView` shows an emoji placeholder;
      needs an image source and `AsyncImage`. The single biggest lift to how the app
      *feels*.
- [ ] **Persistence** — bookmarks/visited are in-memory only; `PersistenceService`
      exists but isn't wired up. Restarting the app loses saves.
- [ ] **Travel data goes stale** — visa/best-time fields are hardcoded on featured sites
      with 2026-dated advice. Needs a live source, or to be removed before real release.
- [ ] **"Do Not Travel" sites** — Bagan, Krak des Chevaliers, and the Russia entries are
      honestly documented but not currently visitable. Decide: keep, flag, or hide.
- [ ] **Bulk sites are thin** — a name + one-line description. Optionally enrich the
      notable ones with a Wikipedia paragraph.
- [ ] **Explore search cost** — filters + sorts ~14k on each keystroke; fine now, worth
      watching as the catalogue grows.

## Known limitations to keep in view

- The `Era` model applies European period names (Renaissance) to non-European sites; the
  prototype's "Early Modern" label was less Eurocentric and was dropped in the port.
- Wikidata has near-duplicate entries (e.g. Palace / Park / Gardens of Versailles as
  separate items) that the dedup does not merge.
- `Chronicarum.xcodeproj` is committed but generated — regenerate with `xcodegen` after
  adding files. `project.yml` is the source of truth.

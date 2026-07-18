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

## Phase 3 — Depth and durability (in progress)

Ordered by my sense of value.

- [x] **Site photos** — Wikimedia Commons images via Wikidata P18, rendered with
      `AsyncImage` and falling back to the era-tinted glyph. 22,351/24,158 bulk (93%)
      and 98/123 featured (80%) have a photo. Each links to its Commons file page,
      where the licence and author live.
- [x] **Persistence** — `PersistenceService` wired into `SiteViewModel`: saved state
      loads at construction and every mutation writes through, so bookmarks survive the
      app being killed. Also added the missing "visited" control — the Saved tab had a
      Visited section that nothing could ever fill.
- [ ] **◀ YOU ARE HERE** — **Travel data goes stale**: visa/best-time fields are
      hardcoded on featured sites with 2026-dated advice. Needs a live source, or to be
      removed before real release.
- [ ] **"Do Not Travel" sites** — Bagan, Krak des Chevaliers, and the Russia entries are
      honestly documented but not currently visitable. Decide: keep, flag, or hide.
- [ ] **Bulk sites are thin** — a name + one-line description. Optionally enrich the
      notable ones with a Wikipedia paragraph.
- [ ] **Explore search cost** — filters + sorts ~24k on each keystroke; fine now, worth
      watching as the catalogue grows.

## Photo attribution — needs a decision before release

Commons photos are freely licensed but almost all carry conditions (CC BY-SA mostly
requires naming the author). The app currently shows a "Wikimedia Commons" chip linking
to each file page, which carries the author and licence. That is good faith, not
guaranteed compliance: strict CC BY-SA wants the author credited alongside the image.
Fixing it properly means a metadata pass over the Commons API (`extmetadata`, batched
50 titles per request) to store artist + licence per photo.

## Known limitations to keep in view

- The `Era` model applies European period names (Renaissance) to non-European sites; the
  prototype's "Early Modern" label was less Eurocentric and was dropped in the port.
- Wikidata has near-duplicate entries (e.g. Palace / Park / Gardens of Versailles as
  separate items) that the dedup does not merge.
- `Chronicarum.xcodeproj` is committed but generated — regenerate with `xcodegen` after
  adding files. `project.yml` is the source of truth.

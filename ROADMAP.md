# Chronicarum Roadmap

Where the project has been, where it is now, and what's left. Newest work at the bottom
of each done-list. Commits referenced by short SHA.

## How far along are we?

**23 of 25 tracked items done**, 1 partly, 1 open. The app is feature-complete and runs
on a real iPhone. The remaining item is additive, not a gap.

| Phase | Status | |
|---|---|---|
| 0 · Skeleton (inherited) | ✅ Done | Didn't compile when handed over |
| 1 · Make it build, run, work | ✅ Done | 10/10 — builds, runs on device |
| 2 · Content: handful → thousands | ✅ Done | 6/6 — 24,281 sites |
| 3 · Depth and durability | ◐ 5 of 7 | 1 partial (travel staleness), 1 open (thin bulk) |

Where it stands today:

- **24,281 sites** — 123 hand-authored (134 chapters, curated facts, sourced) and 24,158
  bulk-imported from Wikidata
- **22,449 photos** — 93% of bulk sites, 80% of featured
- Clustered map that stays responsive at any zoom; conquest timeline across 7 periods;
  location; search; bookmarks that survive a restart
- Runs on a physical iPhone under a paid signing team, profile valid to June 2027

What's genuinely left:

- **Thin bulk entries** (open) — 24k sites carry a one-line description. Enriching them
  with a Wikipedia paragraph is additive; nothing is broken without it.
- **Travel staleness** (partial) — the fields now say when they were researched and that
  they're indicative, but they're still frozen text. Before any public release, they want
  a live source or removal. This is the one item I'd not ship as-is to strangers.

Photo attribution, which was the other release blocker, is now handled: 22,260 photos
carry their author and licence.

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
- [x] **Photo attribution** — author and licence fetched from the Commons API for
      22,260 of 22,261 photos and shown on the image itself (e.g. "FeaturedPics ·
      CC BY-SA 4.0"), linking to the file page. Most of these licences require naming
      the author, so this is compliance rather than polish.
- [x] **"Do Not Travel" sites** — kept, not hidden: deleting honest content wasn't the
      fix, being unmissable was. A warning banner sits above the travel rows, driven by
      the visa note's own wording rather than a hardcoded list.
- [~] **Travel data goes stale** — *mitigated, not solved.* The section now states when
      it was researched and that it's indicative. The real fix is still a live source or
      removing the fields; this only stops them implying an authority they lack.
- [x] **Explore search cost** — the per-keystroke sort of ~24k sites is hoisted out, and
      predicates reordered so cheap enum compares short-circuit the locale-aware search.
- [ ] **◀ YOU ARE HERE** — **Bulk sites are thin**: a name plus a one-line description.
      Optionally enrich the notable ones with a Wikipedia paragraph. The last open item,
      and purely additive.

## Known limitations to keep in view

- The `Era` model applies European period names (Renaissance) to non-European sites; the
  prototype's "Early Modern" label was less Eurocentric and was dropped in the port.
- Wikidata has near-duplicate entries (e.g. Palace / Park / Gardens of Versailles as
  separate items) that the dedup does not merge.
- `Chronicarum.xcodeproj` is committed but generated — regenerate with `xcodegen` after
  adding files. `project.yml` is the source of truth.

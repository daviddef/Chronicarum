# Chronicarum Roadmap

Where the project has been, where it is now, and what's left. Newest work at the bottom
of each done-list. Commits referenced by short SHA.

## How far along are we?

**26 of 29 tracked items done**, 2 partly, 1 open. The app is feature-complete and runs
on a real iPhone (TestFlight build 3). The one open item is additive, not a gap.

| Phase | Status | |
|---|---|---|
| 0 · Skeleton (inherited) | ✅ Done | Didn't compile when handed over |
| 1 · Make it build, run, work | ✅ Done | 10/10 — builds, runs on device |
| 2 · Content: handful → thousands | ✅ Done | 6/6 — 24,281 sites |
| 3 · Depth and durability | ◐ 8 of 11 | 2 partial (travel staleness, Look Around), 1 open (thin bulk) |

Where it stands today:

- **24,281 sites** — 123 hand-authored (134 chapters, curated facts, sourced) and 24,158
  bulk-imported from Wikidata
- **22,449 photos** — 93% of bulk sites, 80% of featured
- Clustered map that stays responsive at any zoom; conquest timeline across 7 periods;
  search; bookmarks and dated visits that survive a restart
- Location-aware: opens where you are, Explore sorted nearest-first with distances,
  cluster overlays with spread and a suggested route
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
- [x] **Map delight** — satellite/hybrid style cycling, a "surprise me" dice that flies to
      a random notable site, and `emphasis: .muted` so Apple's POIs stop competing with our
      markers. Elevation is flat by necessity: `.realistic` occludes annotations in imagery
      mode, verified on device.
- [ ] **Bulk sites are thin** — a name plus a one-line description. Optionally enrich the
      notable ones with a Wikipedia paragraph. Purely additive.
- [x] **Sensitive-site flag** — `Site.isSensitive` excludes death camps, massacre sites,
      slave forts, war graves and political prisons from playful surfaces (currently the
      "surprise me" dice; the guard is in place before any collection mechanic). Keyword
      scan over name and tagline for the 24k bulk, plus an explicit list for curated sites
      whose names give nothing away. 130 of the 1,333-site surprise pool excluded.
- [x] **Visited becomes an archive** — visits now carry a date, and the Saved tab shows a
      record: sites, countries, oldest site, furthest from you, last visited. The first
      piece of the archive loop the research identified.
- [x] **Cache `clusteredItems`** — was a computed property re-filtering all 24k sites on
      every SwiftUI body pass, including ones from unrelated state. Now stored, recomputed
      only when the visible region or a filter changes.
- [~] **Look Around** — implemented in the detail sheet, *unverified*: the iOS Simulator
      serves no Look Around imagery, so the section never appears there. It fails closed
      (hidden when no scene), so it's safe to ship — but it needs a device check at a
      well-covered site like the Eiffel Tower before being called done.
- [x] **Location-aware throughout** — the map opens where the user is, Explore defaults
      to nearest-first with a distance on every row, and tapping a count bubble opens an
      overlay with the places there, how far apart they are, and a suggested route. Two
      separate bugs defeated the auto-centre before instrumenting found them:
      `onMapCameraChange` fires twice on first layout, and the location fix usually lands
      before the map appears.
- [ ] **◀ YOU ARE HERE** — see *What's next* below. Next: bounded collections, then a
      Year in Review.

---

# What's next — making people actually come back

Researched July 2026 across Atlas Obscura, Geocaching, Pokémon GO, Foursquare, AllTrails,
Duolingo, Letterboxd and Untappd. Much of the received wisdom about engagement turns out to
be vendor marketing, so claims below are either **documented** (with a source) or flagged as
inference.

## The finding that should shape everything

**Two independent companies converged on monetising the archive, not the content.**
Letterboxd Pro's headline benefit is *statistics over your own diary*; Untappd Insiders' is
*backdated check-ins and history export*. Neither charges for content or reach — both charge
for the integrity and interpretation of a record the user built themselves.

Why it matters: **willingness to pay rises with tenure automatically.** A stats page is
worth nothing on day one and a great deal in year ten. Letterboxd members created 12.9M
lists in 2025, **+88% year on year — the fastest-growing activity on the platform**, ahead
of logs, ratings and reviews.
([Letterboxd 2025 Year in Review](https://letterboxd.com/journal/2025-year-in-review/))

Chronicarum has the raw material — bookmarks, a visited list, 24k sites with eras and types.
What it lacks is anything turning that into *a record worth keeping*.

## Ranked by impact × feasibility for a solo developer

**1. Turn "visited" into a personal archive.** Today it's a flat list. Give it a date, an
optional note, and a stats view over the result — "your oldest site: 3200 BC", "12
countries", "furthest from home". Polarsteps gets real emotion from two framings: a
**superlative** you can beat, and a **gentle deficit** ("days since you last travelled")
that nudges without a streak's punishment. *Inference, but it follows from the archive
finding above.*

**2. A Year in Review with an eligibility gate.** Letterboxd's requires **≥10 films logged
that year**, making the reward conditional on year-round logging — a commitment device
rather than a punishment. It works: their servers **crashed on 2 January 2026** under the
traffic. Far better suited than a daily streak to something done a few times a year.
([YiR FAQ](https://letterboxd.com/journal/2025-letterboxd-year-in-review-faq/))

**3. Bounded collections, not open-ended points.** **Been** scores against finite sets so
100% means something. The **US National Park Passport** (~433 units, stamps since 1986)
exists explicitly to push visitors toward "smaller hidden gems", and collectors report
visiting parks they'd otherwise skip purely for the stamp. This is the most credible
mechanism found for the **24,158 bulk sites** problem — popularity ranking can never surface
the long tail; a collection frame redistributes attention toward it.
([Eastern National](https://easternnational.org/get-stamped-new-passport-national-parks-collection/))

**4. Look Around in the detail sheet.** `LookAroundPreview` (iOS 17) puts street-level
imagery beside the photo. Free, no entitlement, ~half a day. Fetch lazily on detail open —
there's no batch or coverage API, so prefetching triggers `.loadingThrottled`. Many
heritage sites will return nothing: coverage follows drivable roads, and archaeological
sites often aren't on one.
([MKLookAroundSceneRequest](https://developer.apple.com/documentation/mapkit/mklookaroundscenerequest))

**5. Time-index the sites, not just the polygons.** The conquest timeline moves empire
polygons while 24k markers sit static. Filtering *sites* by the scrubbed period would make
it feel alive rather than decorative.

**6. Cache `clusteredItems`.** A real performance bug, not a feature: it's a computed
property, so it re-filters all 24k sites on **every** SwiftUI body pass, including ones from
unrelated state (sheets, filters, timeline ticks). Should be `@Published private(set)`,
recomputed only on camera and filter changes.

## Traps — mechanics that look obvious and are documented to backfire

**Daily streaks.** Duolingo's works because the streaked behaviour *is* the goal — a
5-minute lesson, any hour, fully under the user's control. Visiting a heritage site is not.
Where behaviour is instrumental rather than terminal, streaks reward app-opening instead of
experiencing. And breaking one is worse than never having one: **66.23% continued with an
intact streak vs 57.86% after a broken one, with identical prior behaviour** — motivation
after a break falls *below* having no streak at all.
([Silverman & Barasch, *J. Consumer Research* 2023](https://academic.oup.com/jcr/article/49/6/1095/6623414))
Duolingo's own published effect sizes are small (+1.7%, +0.38%) and its DAU growth fell from
40% to 21% in four quarters — the mythology outruns the data.

**Points and global leaderboards.** Foursquare stripped its own gamification and said why:
points were **arbitrary** across heterogeneous places ("a check-in at a concert in Istanbul
is really different than one at a dog park"), hundreds of badges meant badges "stopped
feeling special", and global mayorships were unwinnable at scale. Friends-only replacements
were winnable but meaningless.

**Retracting gamification is worse than never shipping it.** When points were removed from
an enterprise social network, contributions fell *below* their pre-gamification baseline
(n=3,486, peer-reviewed).
([Thom-Santelli et al., CSCW 2012](https://dl.acm.org/doi/10.1145/2145204.2145362))

**Social features** need critical mass to be anything but an empty room. X shut down
Communities in 2026: **under 0.4% of users, 80% of spam reports.**
([TechCrunch](https://techcrunch.com/2026/04/23/x-is-shutting-down-communities-because-of-low-usage-and-lots-of-spam/))

## The risk to handle before any of the above

**24k bulk-imported heritage sites certainly include massacre sites, memorials and burial
grounds.** Pokémon GO placed capture points at Auschwitz-Birkenau, the Holocaust Memorial
Museum, the 9/11 Memorial and Hiroshima Peace Memorial Park — a foreseeable, documented
incident. ([Pokémon Go](https://en.wikipedia.org/wiki/Pok%C3%A9mon_Go))

Any collection, badge or points layer will eventually award something for a genocide
memorial. The mitigation is a `sensitive` flag on the site model excluding those sites from
gamified surfaces — **cheap now, expensive retrofitted.** It should land before feature 1,
not after feature 3.

## Business model, for reference

- **Atlas Obscura**, the closest competitor: $18.3M revenue in 2025 and its **first annual
  profit in 16 years** ($2.6M), from brand partnerships with tourism bureaus — not the app.
  It **scrapped its experiences division in 2024**; the CEO said such ventures "are not the
  easiest things to do at scale profitably." Its app rates 4.8 from only ~9.5K ratings — a
  small happy base, not a retention success.
  ([Adweek](https://www.adweek.com/media/atlas-obscura-first-annual-profit/) ·
  [The Rebooting](https://www.therebooting.com/p/atlas-obscuras-next-chapter))
- **AllTrails** paywalls *moment-of-use* capability — offline maps, wrong-turn alerts, live
  location sharing — and keeps content free. ~**1M paid on 25M registered (~4%)** in 2021,
  against a 2.3% median for travel apps.
  ([Spectrum Equity](https://www.spectrumequity.com/news/alltrails-celebrates-1-million-paid-subscribers/) ·
  [RevenueCat](https://www.revenuecat.com/state-of-subscription-apps))
- **Geocaching** keeps content free — 3.4M caches made and maintained by 361k owners,
  reviewed by ~200 unpaid volunteers, 1.2B logs since 2000 — and charges $39.99/yr.
  ([Geocaching newsroom](https://newsroom.geocaching.com/fast-facts))

## Suggested order

**Sensitive-site flag** → **archive + stats** → **Look Around** → **bounded collections** →
**Year in Review**. Notifications only once there's something worth being notified about;
travel apps do enjoy unusually high push opt-in and open rates, but the widely-cited "3×
retention" figure is correlational and vendor-published — treat it as a hypothesis.

---

## Known limitations to keep in view

- The `Era` model applies European period names (Renaissance) to non-European sites; the
  prototype's "Early Modern" label was less Eurocentric and was dropped in the port.
- Wikidata has near-duplicate entries (e.g. Palace / Park / Gardens of Versailles as
  separate items) that the dedup does not merge.
- `Chronicarum.xcodeproj` is committed but generated — regenerate with `xcodegen` after
  adding files. `project.yml` is the source of truth.

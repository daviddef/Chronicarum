# Chronicarum Roadmap

## Where this is going

> **"I'm going to Croatia for 7 days. I like castles and Roman history — where should I go?"**
>
> Chronicarum answers that with a real itinerary: day by day, routed, sized to the time
> available, matched to what you actually care about. Printable as a PDF. Emailed to you.
> Something you take with you.

That is the product. Everything below is either a step toward it or a lesson learned on
the way. The catalogue was never the goal — it is the raw material the planner needs, and
the reason so much of this document is about heritage registers is that **a trip planner
is only as good as the places it knows about.** A planner that answers that Croatia
question with seven pins is worthless; that is precisely where the app was in July 2026,
when Dubrovnik had exactly one site in it.

### The arc

| Stage | | Where it stands |
|---|---|---|
| **1. A map** | Points on a map you can look at | ✅ Done |
| **2. A catalogue** | Enough places that anywhere you stand has something worth seeing | ✅ Done — 260,008 sites |
| **3. Substance** | Each place says something: photo, date, description, why it matters | ◐ Partial — 63% photos, ~37% descriptions |
| **4. Understanding you** | Filters become preferences: "castles and Roman history", not checkboxes | ◐ Themes shipped — 16 of them, 65% of the catalogue tagged |
| **5. The plan** | Days, routes, opening hours, travel time, a sensible order | ◐ Itineraries build, render, and avoid typical closures. **Real routing still missing** |
| **6. Taking it with you** | PDF, email, calendar, offline | ◐ **PDF export shipping.** Email/calendar via the share sheet; offline not started |
| **7. The record** | Where you went, what you saw, a diary worth keeping | ◐ Partial — visits + stats exist |

Stages 1–3 are infrastructure and are largely done. **Stages 4–6 are the actual product**
and none of it is built yet. Stage 7 is what brings people back, and the retention research
below argues it is what people would eventually pay for.

### What stage 4–6 needs that we do not have

Being honest about the gap, because the catalogue work makes the app look closer to this
than it is:

- **Opening hours, closures, admission.** Not in any register. A plan that sends someone to
  a closed monastery on a Monday is worse than no plan.
- **Travel time between places.** We have straight-line distance and a nearest-neighbour
  ordering. A real day plan needs road and walking time — self-hosted Valhalla over OSM is
  the identified route, and it is a server, not a bundled file.
- **What a place is *for*.** "Roman history" is not a filter we can express. `era` and
  `type` are crude proxies; there is no theme model.
- **How long to spend somewhere.** Diocletian's Palace is a morning. A roadside chapel is
  ten minutes. Nothing in the data says so.
- **PDF and email.** Both are straightforward to build, and both are the *last* step —
  worth nothing until the plan behind them is good. Email in particular is a send-on-
  behalf-of-user action and needs explicit consent per send.

None of these are blocked by anything. They are simply not started, and the catalogue work
was a prerequisite rather than a substitute.

---

## How far along are we?

**42 of 44 tracked items done**, 2 partly, 0 open, 2 partly, 1 open. The app is feature-complete and runs
on a real iPhone (TestFlight build 8 — PDF, Wikipedia summaries, Italy, trip planning, draw-a-region). The one open item is additive, not a gap.

| Phase | Status | |
|---|---|---|
| 0 · Skeleton (inherited) | ✅ Done | Didn't compile when handed over |
| 1 · Make it build, run, work | ✅ Done | 10/10 — builds, runs on device |
| 2 · Content: handful → thousands | ✅ Done | 13/13 — 294,943 sites |
| 3 · Depth and durability | ◐ 8 of 11 | 2 partial (travel staleness, Look Around), 1 open (thin bulk) |

Where it stands today:

- **260,131 sites** — 123 hand-authored (134 chapters, curated facts, sourced) and
  260,008 imported by heritage designation: ~104k UK, ~71k US, ~44k French,
  ~14.5k Australian, ~1.4k Croatian, the rest global
- **164,473 photos** — 63% of bulk sites, 80% of featured. Varies hugely by source:
  UK Grade I 99%, France 84%, US 81%, Scotland's Category B far less.
- **~95k sites carry a real description** — 23,811 in French prose from Mérimée, ~71k
  one-liners from the Wikidata join on the US register
- Clustered map that stays responsive at any zoom; conquest timeline across 7 periods;
  search; bookmarks and dated visits that survive a restart
- Location-aware: opens where you are, Explore sorted nearest-first with distances,
  cluster overlays with spread and a suggested route
- Runs on a physical iPhone under a paid signing team, profile valid to June 2027

What's genuinely left:

- **Travel staleness** (partial) — the fields now say when they were researched and that
  they're indicative, but they're still frozen text. Before any public release, they want
  a live source or removal. This is the one item I'd not ship as-is to strangers.

Photo attribution, which was the other release blocker, is now handled: 164,471 of
164,473 distinct photos carry their licence, 98.3% of them with a named author. The two
missing are files that no longer resolve on Commons.

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
- [x] **Import by heritage designation, not Wikipedia popularity** — the notability filter
      was the whole problem. Australia-wide pass added 9,728 places. See *Why the
      catalogue was thin* below.
- [x] **South Australia from the state register** — Wikidata had 113 of a few thousand.
      Adelaide went from 75 places to 1,502. First CC BY source, so first attribution.
- [x] **UK by designation grade** — Grade I, II*, scheduled monuments and Scottish
      Categories A/B: 104,292 places. Grade II (378,336) excluded as the ordinary tier.
- [x] **France from Mérimée** — 44,182 monuments historiques, 84% with a photo (joined via
      Wikidata P380) and 23,811 with the register's own prose. Wikidata held 12.
- [x] **Columnar bundle format** — the load regressed at 187k rows, so the storage
      question came due. Measured, not guessed: see *Making 187k rows load* below.
- [x] **United States from the NRHP** — 71,113 National Register listings, 81% with a
      photo and 99% with a description, both from the Wikidata P649 join. Public domain.
- [x] **Croatia from Wikidata, *not* its national register** — 1,388 sites, 86% with a
      photo. Dubrovnik went from 1 to 49. The register itself is off limits; see
      *Croatia, and a register we cannot use* below.

## Phase 3 — Depth and durability (in progress)

Ordered by my sense of value.

- [x] **Site photos** — Wikimedia Commons images via Wikidata P18, rendered with
      `AsyncImage` and falling back to the era-tinted glyph. 164,473/260,008 bulk (63%)
      and 98/123 featured (80%) have a photo. Each links to its Commons file page,
      where the licence and author live.
- [x] **Persistence** — `PersistenceService` wired into `SiteViewModel`: saved state
      loads at construction and every mutation writes through, so bookmarks survive the
      app being killed. Also added the missing "visited" control — the Saved tab had a
      Visited section that nothing could ever fill.
- [x] **Photo attribution** — author and licence fetched from the Commons API for
      164,471 of 164,473 distinct photos and shown on the image itself (e.g. "FeaturedPics ·
      CC BY-SA 4.0"), linking to the file page. Most of these licences require naming
      the author, so this is compliance rather than polish. The fetcher used to drop a
      whole 50-photo batch whenever a request failed — which is how a run of Cyrillic
      filenames went uncredited — and now halves and retries, so an awkward title costs
      one photo rather than fifty.
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
- [x] **Bulk sites are thin** — *closed.* 21,581 sites now fetch a real Wikipedia summary
      at runtime, giving prose to 17,466 that had none. **Fetched, never bundled**: CC BY-SA
      §2(a)(5)(B)'s anti-TPM clause makes App Store distribution of the text questionable,
      and Creative Commons rejects parallel distribution as a cure — so the app does what
      the official Wikipedia app does. Only the article *title* ships, which is CC0.
      Resolved by Wikidata sitelink, never by name: `/page/summary/Maryborough_Post_Office`
      returns a disambiguation page.
- [x] **Sensitive-site flag** — `Site.isSensitive` excludes death camps, massacre sites,
      slave forts, war graves and political prisons from playful surfaces (currently the
      "surprise me" dice; the guard is in place before any collection mechanic). Keyword
      scan over name and tagline for the bulk layer, plus an explicit list for curated
      sites whose names give nothing away. 4,803 of 143k sites flagged. Re-checked after
      the UK import, which added 31k scheduled monuments: "churchyard" had been missing
      alongside "graveyard" and "cemetery", leaving 1,176 active burial grounds eligible
      for playful surfaces. Matching is now anchored to a leading word boundary so
      "Pereyaslavets" stops reading as a slavery site — but only the leading one, because
      requiring a trailing boundary silently unflagged "Izium mass graves" and "political
      prisoners". The two errors are asymmetric and this leans toward over-including.
      Prehistoric barrows and cairns are deliberately *not* flagged: a Neolithic long
      barrow is an ordinary archaeological attraction, not a distressing site.
      Re-checked again after the US import, which brought whole categories the list had
      never had to reach: **696 plantations were sitting unflagged**, because "slave"
      does not appear in "Albania Plantation House" — but a plantation is a site of
      chattel slavery whatever the register calls it. Added plantation, battlefield,
      internment, trail of tears, lynching. Now 7,168 of 258,620 flagged.
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
- [ ] **◀ YOU ARE HERE** — Australia is now covered by heritage designation rather than
      Wikipedia fame (see *Why the catalogue was thin*). Next: roll the same query to the
      other markets, then bounded collections and a Year in Review.

---

# Why the catalogue was thin — and the fix

Researched July 2026, prompted by a screenshot: Brisbane, a city of 2.6 million, showed
**7 places**. No Anzac Square, no CBD heritage buildings, nothing anyone would walk to.

## The cause

The bulk import gated on **Wikipedia sitelink count ≥ 5 language editions**. That is a
proxy for global fame, and it works exactly as designed for the Colosseum. For anything
local it is destructive:

| Within 20 km of Brisbane CBD | Count |
|---|---|
| Places with a heritage designation | **546** |
| …of those, clearing the ≥5-sitelink bar | **11** |

An independent research pass reached the same conclusion unprompted: *the notability
filter is the entire problem.* Sitelink count measures how many Wikipedias happened to
write an article, which for a suburban post office is zero regardless of merit.

## The fix

**Wikidata `P1435` (heritage designation)** as the inclusion signal. If a government
register lists a place, that is a stronger statement about it being worth visiting than
how many language editions describe it. It also happens to be free of licence obligations:
Wikidata statements are **CC0**, so nothing is owed and nothing is share-alike.

Measured supply at the time of writing:

| Scope | `P1435` + coordinates | …also with a photo |
|---|---|---|
| Worldwide | ~2,100,000 | 962,256 |
| Australia (`P17 = Q408`) | 10,576 | 59.5% |

Per-city, to show the shape: Brisbane 546 · Sydney 937 · Bristol 8,364 · Amsterdam 11,577.
The global photo rate misleads badly (AU 59.5% vs GB 29.2%) — measure per market, never
once.

## What shipped

Australia-wide, partitioned by register rather than by geographic ring — each register is
a naturally bounded slice (largest: Victorian Heritage Register, 2,381) so every query
finishes inside the 60 s SPARQL timeout without paging. 22 registers, 10,493 places
fetched, **9,728 new, 760 existing rows enriched with a locality, 3 genuine duplicates
skipped**. Photo attribution followed: 28,315 of 28,316 credited.

Scripts: [`fetch_heritage_pilot.py`](scripts/fetch_heritage_pilot.py) (Brisbane proof) →
[`fetch_heritage_au.py`](scripts/fetch_heritage_au.py) +
[`merge_heritage_au.py`](scripts/merge_heritage_au.py).

**The dedup bug worth remembering.** The first merge reported "176 curated duplicates
skipped" and it looked plausible. It was not: a 0.01° (~1.1 km) collision radius had
deleted 173 real heritage places — Customs House, Cadmans Cottage, the Garrison Church —
purely for standing near the Sydney Opera House. Only **3** were actual duplicates.
Tightened to 0.0005° (~55 m), with name matching doing the real work. A dedup rule that
silently deletes content is worse than no dedup, because the loss is invisible.

## Caveats on this data

- **Brisbane is atypically good.** ~1,823 of its en.wikipedia articles were bulk-generated
  from the Queensland Heritage Register under CC BY 3.0 AU. Most cities will look thinner
  than the Brisbane result suggests. Don't generalise from it.
- **Templated descriptions are not prose.** `"historic commonwealth heritage site in
  Crace ACT"` restates the name and the pin. 87% of Australian records have a description;
  almost none of it is worth reading. 34.6% have neither a Wikipedia article nor an image.
- **Never title-match to Wikipedia.** `/page/summary/Maryborough_Post_Office` returns a
  disambiguation page. Resolve via the Wikidata sitelink only.

## Filling the gaps the registers left

Measured coverage after the Australia-wide pass, per city, within 20 km:

| Melbourne | Sydney | Perth | Hobart | Brisbane | Canberra | Adelaide | Darwin |
|---|---|---|---|---|---|---|---|
| 1,109 | 949 | 921 | 583 | 551 | 167 | **75** | **15** |

The approach generalises — Brisbane's *photo* rate is exceptional, but its raw count is
unremarkable. Adelaide and Darwin were the outliers, and the cause was not the query: a
census of every Australian designation showed the 22 registers imported had missed only
24 items nationwide. **Wikidata itself is thin there.** The South Australian Heritage
Register held 113 entries against a real register of several thousand; the Northern
Territory 32 against ~180. Coverage is a record of where volunteers have worked.

**South Australia was therefore taken from the state register directly**
([`merge_heritage_sa.py`](scripts/merge_heritage_sa.py)) — data.sa.gov.au publishes it as
GeoJSON under CC BY 3.0 AU. Adelaide went from 75 places to 1,502.

Two things that generalise to every register import after this one:

- **A government register is not a list of destinations.** SA's 24,479 points are three
  different things: State (3,280, the register proper), Local (8,650, mostly bare
  "House"), and Contributory (12,549, streetscape filler with no description). Importing
  all of it would have pinned ~21,000 private homes and invited people to look at them.
  Only State plus a public-facing subset of Local was taken. Expect this split in every
  register; the labels differ, the shape does not.
- **Dedup broke three times, each time differently.** It is worth stating the rule that
  survived, because two plausible ones did not:

  | Attempt | What it did | Cost |
  |---|---|---|
  | Position alone, 0.01° (~1.1 km) | deleted anything near a curated site | 173 places — Customs House, Cadmans Cottage, the Garrison Church, for standing near the Opera House |
  | Name alone, globally | deleted anything sharing a name | 2,599 places — *St John's Anglican Church* because Fremantle has one; 1,300-odd *Dwelling*s by each other |
  | Position alone, 0.0005° (~55 m) | fine in sparse Australia, wrong in Britain | 25,658 places — **Dover Castle** by the Roman fort beneath it, **Canterbury Cathedral** by St Augustine's Abbey, **Bath Assembly Rooms** by the museum inside it |

  The surviving rule is **name match within ~250 m, and nothing on position alone.**
  Identity by QID is already exact, which is what dedup is actually for; proximity is not
  evidence of sameness, because clustering is exactly what a historic precinct *is*.

  The structural lesson underneath all three: **a dedup rule that silently deletes is
  worse than no dedup, because the loss is invisible.** A surviving duplicate is visible
  and fixable; a deleted place is neither. Every import now prints its skip reasons, and
  any skip count above a few percent gets sampled by hand before the merge is kept — which
  is the only reason the Dover Castle case was caught at all.

**Attribution now has somewhere to live.** Wikidata is CC0 and owes nothing, which is why
34k sites carry no source line. CC BY registers do owe it, so `DataSource` in
[`Site.swift`](Chronicarum/Models/Site.swift) renders the credit on each affected site
with a link to the register. Adding a register means adding a case.

## The UK, and the scope question every large market will raise

Australia fit in a bundle without anyone having to decide anything. The UK does not:
there are ~480,000 listed buildings, and **Grade II alone is 378,336 — roughly 81 MB of
JSON against a whole bundle of 8.2 MB.**

Grade II is also the *ordinary* tier: terraced houses, garden walls, milestones, telephone
boxes. It is South Australia's Contributory class again at a hundred times the scale, with
the same problem — most of it is where people live. So the line is drawn at the grades
that mean "worth going to see":

| Designation | Count | |
|---|---|---|
| Grade I (England & Wales) | 10,101 | exceptional interest — **99% have a photo** |
| Grade II* (England & Wales) | 24,515 | more than special interest |
| Scheduled monuments | 33,709 | nationally important archaeology |
| Category A (Scotland) | 6,515 | national importance (≈ Grade I) |
| Category B (Scotland) | 34,621 | regional importance (≈ Grade II*) |
| *Grade II — excluded* | *378,336* | *ordinary listings, mostly private homes* |
| *Category C — excluded* | *26,512* | *Scotland's local tier* |

Scotland gets A **and** B so it sits at the same bar as England; taking only Category A
would under-represent Scotland the exact way sitelink-count under-represented Brisbane.

**Query shape turned out to matter more than query scope.** The obvious single query with
`OPTIONAL` `P31`/`P131`/`P571` label lookups times out at 60 s on every one of these
designations, and `LIMIT`/`OFFSET` paging over an `ORDER BY` is worse. Splitting into a
cheap core query (label, coordinates, image) plus a separate enrichment query joined
locally by QID takes a 10k-row designation from *timeout* to *5 seconds*.

Storage stays JSON for now, with cold-launch parse time measured rather than assumed. If
it regresses, SQLite with a spatial index is the move — and that is also what Grade II
would require if it is ever wanted.

## France, and the first source that ships actual writing

Wikidata was not the route: it holds **12** French monuments with coordinates against a
register of 46,714. Mérimée, the culture ministry's own register, is published under
**Licence Ouverte 2.0** and is far richer than Wikidata would ever have been.

44,182 imported, and two things set it apart from every earlier source:

- **84% have a photo** — against 49% for the UK. Mérimée ships no images at all; they come
  from a join to Wikidata on `P380` (Mérimée ID), which turns out to be the cheapest photo
  coverage available anywhere so far.
- **23,811 carry `historique`** — real descriptive prose, ~525 characters at the median.
  This is the first source that answers *"bulk entries are thin"* instead of adding more
  bare pins.

**The prose stays in French.** It is the French state's own account of a French monument;
machine-translating it would create an adaptation of an official record, and a
mistranslated protection notice is worse than an untranslated one. The UI labels it
*En français* rather than pretending otherwise, and the text is selectable so anyone who
wants a translation can lift it. It loads from its own 14 MB file, lazily, so it never
touches the catalogue parse — the same split already used for photo credits.

**Generic names needed two passes.** The register titles a building by what it *is* when
it has no name: 2,717 "Maison", 2,448 "Eglise", 2,124 "Immeuble". Qualifying by commune
was the obvious fix and produced four consecutive Explore rows reading *"Immeuble, Paris
4e Arrondissement"* — useless to someone standing on the street, since an arrondissement
holds hundreds. Qualifying by street address instead gives *"Immeuble, 63 rue de la
Verrerie"*, which is a place you can walk to.

Dedup also had to be narrowed again, for a new reason: Mérimée must not be deduped
**against itself**. Its `reference` is already a unique key, so a name check within the
source can only produce false positives — and produced 3,943, since neighbouring
protected buildings genuinely share the title "Immeuble".

## Making 187k rows load

The bundle format question, deferred earlier with "ship JSON and measure", came due: at
187,507 rows the catalogue took **1,457 ms** on a Release build. Profiling put 1,419 ms of
that in `JSONDecoder` — file read was 17 ms and mapping to `Site` was 70 ms.

Three formats, all measured on device-class Release builds rather than reasoned about:

| Approach | Load | Size |
|---|---|---|
| `JSONDecoder` over `[BulkSite]` | 1,457 ms | 40 MB |
| `JSONSerialization`, row dictionaries | **1,918 ms** | 40 MB |
| `JSONSerialization`, **columnar** | **967 ms** | **29 MB** |

The middle row is the useful lesson. Dropping `Codable` for `JSONSerialization` looked
like an obvious win and made things **32% worse**: it returns `NSDictionary`, so every
`row["name"] as? String` crosses the Objective-C bridge — ~1.9M bridged casts, costing
more than the reflection they replaced. The first optimisation attempt was a regression,
and only measuring caught it.

Columnar wins because it pays that cost once per *field* rather than once per *row*: ten
array casts, then indexed access. It is also 26% smaller, because a row-wise file repeats
all ten key names 187,507 times.

`bulk_sites.json` stays row-wise as the source of truth for the import scripts and is
**excluded from the app target**; [`build_columnar.py`](scripts/build_columnar.py)
produces what ships. Getting below ~300 ms would need a binary format or SQLite — worth
doing if the catalogue roughly doubles again, not before.

## Croatia, and a register we cannot use

Croatia keeps an excellent register, and it is the first source in this project that had
to be **read and then walked away from**.

The Ministry of Culture's Geoportal publishes a genuine INSPIRE **WFS with GeoJSON
output** — 7,302 protected cultural goods across 20 typed feature classes (sacred
buildings, military and defensive structures, archaeological zones, cultural landscapes),
each carrying a name, dating, architect, a prose description and an image path. Better
structured than Mérimée, and roughly seven times what Wikidata holds for Croatia.

Its [terms of use](https://geoportal.kulturnadobra.hr/api/app/get-terms-of-use/cro) say:

> *"Podaci ... isključivo su informativnog karaktera i služe za osobnu uporabu, te se ne
> smiju koristiti u komercijalne svrhe niti distribuirati trećoj strani."*
>
> *"Zabranjeno je svako mijenjanje, umnožavanje, distribuiranje podataka, na bilo kojoj
> vrsti medija ..."*

**Personal use only. No commercial use. No distribution to third parties. No reproduction
on any medium.** Photographs additionally require a signed agreement with each individual
author. Bundling those records into a shipped app is distribution on media however the app
is priced, so the service was queried twice to establish its schema and licence, and then
left alone.

This is worth recording prominently precisely *because* the data is right there and
technically trivial to take. Every other register in this project has been open — CC BY,
Licence Ouverte, public domain, CC0 — and it would be easy to assume that is the norm and
stop reading terms. It is not the norm. If Croatia matters commercially, the route is an
agreement with the Ministry, not a crawler.

**What shipped instead:** Wikidata, CC0, filtered by a positive allowlist of classes a
traveller would go to — 1,388 sites, 86% with a photo. Dubrovnik went from **1 site to 49**,
Split 21 → 180, Zagreb 23 → 405. Better, and honestly ours. But it is worth being clear
that Croatia is now the best example in the catalogue of the gap between *what exists* and
*what we are allowed to ship*: 1,388 against a register of 7,302.

## Themes — teaching the catalogue what a place is *about*

`Era` and `SiteType` describe a site the way a catalogue does: a period name and a building
category. Neither can express the sentence the product exists to answer — *"I like castles
and Roman history."* [`derive_themes.py`](scripts/derive_themes.py) adds 16 themes, derived
offline and shipped as a bitmask per site, so matching is an integer AND rather than a
string search over 260k rows.

Themes are **not a partition**. A Norman castle with a chapel is `castles` *and* `sacred`;
a Roman aqueduct is `roman` *and* `grand-engineering`. That is what makes a two-interest
question answerable as a union rather than forcing a single box.

| | tagged | | | tagged |
|---|---|---|---|---|
| Churches & abbeys | 43,614 | | Farms & countryside | 14,563 |
| Civic & public life | 19,390 | | Prehistoric | 14,439 |
| Castles & forts | 18,694 | | Monuments & memorials | 11,567 |
| Grand houses | 18,088 | | Archaeology | 11,100 |
| Industrial | 9,497 | | Museums & galleries | 8,356 |
| Bridges & engineering | 8,131 | | Old towns & streets | 7,930 |
| Gardens & parks | 7,268 | | Military & wartime | 4,111 |
| Roman & classical | 3,641 | | Coast & maritime | 3,291 |

**65% of the catalogue carries at least one theme.** The other 35% is ordinary buildings —
"Becker, Christine, House", "299 West George Street" — and they are left untagged
deliberately. A listed terraced house is not *about* anything in this sense, and inventing
a theme for it would make every other theme mean less.

### Rules, not a model

260k rows. Hand-labelling is impossible and LLM-labelling at that scale is expensive,
irreproducible and — the real objection — **unverifiable**: a wrong label is
indistinguishable from a right one without reading all 260k. Keyword rules are inspectable,
deterministic, free to re-run as the catalogue grows, and wrong in ways that can be *found*
by sampling. Every fix below was a visible one-line change.

The rules run mostly over **names**, because that is the only universal signal:

    era known                   30%   <- cannot anchor "Roman" on era
    type == "heritage"          60%   <- the generic bucket
    description present         51%   <- absent for 106k UK sites entirely
    name present               100%

Names are multilingual, so each theme carries vocabulary in English, French and Croatian
rather than an English list plus hope.

### What the first pass got wrong

Measuring beat reasoning three times, and every one of these would have shipped silently:

| | |
|---|---|
| **410 Roman Catholic churches tagged as Roman history** | `\broman\b` matches "Roman Catholic". A user asking for Roman history would have got Iowa parish churches. |
| **590 town halls tagged as grand houses** | `\bhall\b` is an English country-house word *and* a civic one. |
| **"Gate piers" tagged as maritime** | An architectural gatepost is not a harbour pier. |
| **Diocletian's Palace not tagged Roman** | It contains no generic Roman keyword at all. Nor did Verulamium or Hadrian's Wall — the three sites a person would name *first*. |

The fixes: per-theme **veto patterns** for words that mean one thing in heritage vocabulary
and another in ordinary English; named Roman sites added explicitly; and `era` promoted
from a fallback to an additive signal, so a classically-dated site is Roman whatever its
name says. A second pass then found 7,637 sites typed `monument` carrying no theme at all —
the vocabulary had aqueducts and bridges but nothing for the statue or war memorial someone
actually walks past — so `monuments` and `townscape` were appended.

**Bit order is load-bearing.** The catalogue is labelled against bit positions, so a theme
inserted in the middle would silently re-label 260k rows. Append only, then re-run.

## Visit duration

A day plan needs to know that Diocletian's Palace is a morning and a wayside cross is five
minutes. **No heritage register records this** — registers describe what a place *is*,
never how long you would stand in front of it. [`derive_durations.py`](scripts/derive_durations.py)
estimates it from themes plus scale words in the name.

Shipped in **bands** — 5, 10, 15, 20, 30, 45, 60, 90, 120, 180 minutes — never as a
computed figure. The signal is a theme and a few words; it does not support "37 minutes",
and printing that would imply a confidence the data cannot carry. The UI says *"about
2 hr"* for the same reason.

| | share | |
|---|---|---|
| 10 min | 36% | ordinary listed buildings — a look from the pavement |
| 30 min | 22% | parish churches, barrows |
| 90 min | 12% | museums, old-town quarters, grand houses |
| 60 min | 8% | castles, cathedrals, gardens |
| 5 min | 2% | crosses, milestones, telephone boxes |

Mean 32 minutes per site.

`tier` turned out to be useless here — it is **2 for all 260,008 bulk sites**, so
significance could not drive it. Measuring that first is what sent the design to themes and
names instead.

### Four things a sample caught

Each of these shipped in an intermediate run and was found by printing real rows:

| | |
|---|---|
| **"Buckingham Palace boundary walls" — 2 hours** | It is a wall. The component rule only fired on head nouns, and this one begins with "Buckingham". |
| **Every Venetian townhouse in Split — 2 hours** | "Palace" covers Diocletian's *and* a merchant's street facade. 685 rows, ~100 actually royal. The blanket promotion is gone; only royal and imperial residences earn it. |
| **A churchyard cross — 30 minutes** | The theme model correctly saw "churchyard" and gave it a parish church's time. But the site *is* the cross. The head noun settles what a site is. |
| **"Dover Castle Hotel" — a castle** | A pub. British and Australian pubs are named after castles constantly, and a castle-themed itinerary that routes someone to a Wetherspoons is worse than one that misses a castle. Vetoed in the theme model. |

## Containment — and the bigger problem behind it

Registers describe the same place at several scales. A gate, the palace it pierces and the
world heritage complex containing both are three correct records, and summing their
durations claims ten hours for one afternoon. This is **not** the duplicate problem the
merge scripts solve — a duplicate is one place recorded twice; these are genuinely
different records.

[`fetch_containment.py`](scripts/fetch_containment.py) takes Wikidata `P361` (part of),
which is explicit and free. Two filters make it usable:

- **Both ends must be in our catalogue.** "Part of Europe" is true and useless.
- **The parts must be near each other.** `P361` also encodes class membership — a generic
  *stećak* is "part of" necropolises 20, 55 and 67 km apart. Real containment is metres;
  2 km is generous and removed every false pair observed.

154,681 candidate relations → **2,324 contained sites** across 1,017 containers. A site
whose parent is also present contributes no time: you are already spending the container's
hour, and the parts are what you see while you are there.

### Where it works

Glasgow's Park Terrace area, 187 records within 350 m — Georgian terraces listed both as a
terrace *and* as every individual house:

| | |
|---|---|
| naive sum | 144.9 h |
| with containment | **50.8 h** — 97 records folded away |

`1–21 Park Terrace` alone holds 39 listed houses. Chester city walls holds 31 sections.

### Where it doesn't, and why that matters more

The case that motivated the work barely moved. Split's centre went 50.1 h → **48.1 h**,
because Wikidata records Diocletian's Palace as part of the UNESCO complex but says nothing
about the Golden or Silver Gates. Coverage is **0.9% of the catalogue** — precise where it
exists, absent almost everywhere.

That is worth stating plainly rather than presenting containment as the fix: **it is not
what makes Split take 48 hours.** Central Split genuinely holds 52 heritage records, and a
person visits six of them. The remaining problem is **selection**, not double-counting —
deciding which six are worth a day — and no containment data solves it.

Still open for containment itself:

- **Geometric containment.** Several registers (UK, SA, Croatia) publish polygon layers;
  only points were imported. A point inside another site's footprint is contained. This is
  the route to real coverage and it means re-importing geometry.
- **Wikidata `P527` (has part)**, the inverse — some items record only one direction.

## Selection — which six of the fifty-two

Containment was supposed to fix "central Split needs 48 hours for one afternoon". It
removed two. The catalogue genuinely holds 52 heritage records within 400 m of Split's
centre and a person visits about six; the problem was never double counting, it was that
**nothing decided which six**.

[`derive_significance.py`](scripts/derive_significance.py) scores every site 0–100. It is
a **ranking device, not a judgement** — a 12 is not "unimportant", it is "if you only have
a day, not this one".

| weight | signal | |
|---|---|---|
| 40 | renown | Wikipedia sitelinks, log-scaled, capped at 50 |
| 25 | designation | World Heritage, Grade I, Category A, National Historic Landmark |
| 20 | substance | has a photo, has real prose, takes an hour or more |
| 10 | wholeness | a container scores up, a part scores down |
| 5 | name | a proper name rather than "House" |

### The reversal at the centre of it

The strongest signal is **Wikipedia sitelink count** — the thing this project began by
getting wrong. The first import required ≥5 language editions and left Brisbane with 7
sites and Dubrovnik with 1. Replacing it with heritage designation is what made the
catalogue real.

It was the wrong **filter** and it is the right **ranker**. Nothing about how many
Wikipedias describe a place says whether it belongs in a heritage catalogue — that is what
a government register is for. But once every designated place is *in*, sitelinks measure
very well which of them a visitor has heard of. Croatia by sitelinks: Plitvice 70,
Diocletian's Palace 52, Bakarski Castle 0. Exactly right for choosing six places to see;
exactly wrong for choosing which 260,008 to hold.

Same number, opposite job. Sitelinks exist for only ~140k rows, so a missing count is never
treated as evidence of *un*importance — it is a bonus or nothing, and register grades carry
the rest.

### "Best" is significance discounted by distance

Sorting by raw significance while standing in Split returns **Gorée, Senegal — 4,593 km
away**. Correct as a global ranking, useless as an answer to "where should I go today".
Distance alone is no better: it offers six listed townhouses on this street while the
cathedral sits 300 m on.

`detourScore` divides significance by distance with a **25 km half-life** — a site 25 km
out needs twice the significance to rank alongside one at your feet. Standing in Split it
now returns the Palace complex, Diocletian's Palace, the Cathedral of St Domnius, the
Temple of Jupiter, and **Salona 4.9 km out**, which is exactly the trade a person makes.

### Two things measuring caught

**Stadion Poljud ranked fourth in Split.** A football stadium, on 40 sitelinks and nothing
else. Renown measures what Wikipedia covers, which includes stadiums, airports and
universities. Renown now requires corroboration — a theme, a grade or a real description —
and is discounted to a quarter without it. World Heritage sites with no theme keep their
score because the designation corroborates them.

**The Croatian *language* was in the catalogue as a place.** Intangible heritage carries
`P1435` exactly like a building, and Wikidata gives it the country centroid for
coordinates, so it sat at 45°N 15°E scoring 53 on 200 sitelinks. Eleven such rows were
removed. A designation is not evidence of somewhere you can stand.

### A latent bug this exposed

Explore's "Significance" sort has never worked. It sorted by `tier`, which is **2 for all
260,008 bulk sites** — so the control has been inert since the bulk layer shipped. Same for
the cluster overlay's "most significant 40", which was an arbitrary 40.

## Day shaping — the thing everything else was for

*"I'm going to Croatia for 7 days. I like castles and Roman history — where should I go?"*
[`TripPlan.swift`](Chronicarum/Models/TripPlan.swift) answers it. Standing in Split with
castles and Roman history selected, three days:

    Day 1 — 5 stops, 7.3h
       1m  walk   Temple of Jupiter, Split                 about 45 min
       1m  walk   Historical Complex of Split / Diocletian about 3 hr
      13m  drive  Salona                                   about 45 min
      12m  drive  Klis Fortress                            about 1 hr
      24m  drive  Cambi Castle                             about 1 hr

Every earlier stage feeds this: registers gave the places, **themes** made "castles and
Roman history" expressible, **durations** made a day addable, **containment** stopped the
palace being counted three times, **significance** chose five from ninety-seven.

### Three things the first version got wrong

**It buried the best thing.** Choosing greedily by value-per-minute puts off anything
expensive, so the Historical Complex of Split — the single best thing in the city — landed
on *day 3* while day 1 was spent on its gates. Each day now **anchors** on the best unused
site and fills around it.

**It filled a Bath day with 26 stops.** Ranking by `significance / cost` rewards cheap
filler: a 10-minute Georgian railing at 33 beats the Roman Baths at 86. The value function
is now `significance − 0.5 × travel`, with a cap of 7 stops and a floor at 40% of the day's
anchor. Bath Day 1 became: Great Spa Towns, Roman Baths, Pulteney Bridge, Royal Crescent,
Farleigh Hungerford Castle.

**It scheduled a two-minute walk last.** The Temple of Jupiter sits beside the palace and
was visited *after* driving to Klis Fortress and back, because selection was also doing
sequencing. Those are different problems: stops are now chosen for value, then reordered
nearest-neighbour.

### What it still cannot do

- **Opening hours.** Not modelled at all. The plan will happily send you to a monastery on
  a Monday. This is the largest remaining gap in the product and has no data source yet.
- **Real routing.** Straight-line × 1.25, walked under 1.5 km and driven above.
  Self-hosted Valhalla over OSM is the known fix; the plan's *shape* will not change, only
  its numbers.
- **Containment it cannot see.** Day 2 still opens with the Silver and Golden Gates, which
  are inside the complex visited on day 1 — Wikidata records the palace as part of the
  complex but says nothing about its gates. Geometric containment is the route to fixing
  it.
- **Anything about you beyond themes.** No pace, no mobility, no "we have children", no
  "we don't drive".

## Opening hours — the honest answer is that nobody has them

The largest remaining gap turned out not to be a build problem but a sourcing one, and the
sourcing has no answer. Measured before designing anything:

| source | coverage | cost |
|---|---|---|
| Wikidata `P3025` (opening hours) | **703 designated sites worldwide** (0.27%) | free |
| OpenStreetMap `opening_hours` | **5%** of heritage objects, in both Bath and Split | ODbL — must publish our derived database |
| Any heritage register | **nothing** | — |
| Wikidata `P856` (official website) | ~9% UK, ~6% Croatia, 2.6% of our catalogue | free |

**This settles the ODbL question that had been open since the Brisbane research.** OSM is
the only candidate with real hours data, and accepting the obligation to publish our
derived database would buy hours for **one site in twenty**. That is not a trade worth
making.

### So the app does not claim to know

Three things shipped instead, none of which invents a fact:

**Typical patterns by kind of place.** Museums are commonly closed Mondays; historic houses
close Mondays and over winter; castles keep short winter hours; churches are usually open
but may close for services; ruins and monuments are open ground. Ordinary travel knowledge,
applied by theme, and always hedged —
[`OpeningPattern.swift`](Chronicarum/Models/OpeningPattern.swift).

**The planner acts on it.** Trips take a start date, so days map to weekdays, and a place
commonly shut that day is demoted rather than excluded — the patterns are typical, not
known, and refusing to show the only museum in town because it is Monday would trust a
guess further than it deserves. Starting a Bath trip on **Monday 27 July** now produces:

    Day 1 · Monday   Great Spa Towns, Bath Abbey, Pulteney Bridge,
                     Queen Square, Royal Crescent, Farleigh Hungerford Castle
    Day 2 · Tuesday  Roman Baths, ...

The Roman Baths moved itself to Tuesday. Nothing told it to; the closure factor did it.

**A way to check.** 6,871 sites carry an official website (CC0, from `P856`), shown as
"Check the official site". Thin at 2.6%, and shipped anyway — for those sites the
alternative is "go and find out somehow".

Every surface says the same thing in plain words: *we don't know this site's actual hours,
no heritage register records them, this is what's typical.* A plan that quietly invents an
opening time is worse than one that admits ignorance, because the first sends someone
across a city to a locked door.

## Taking it with you — PDF

[`ItineraryPDF.swift`](Chronicarum/Models/ItineraryPDF.swift) renders a plan as a printable
A4 document, shared through the system sheet — so print, Files, Mail and Messages all come
free, and **sending it to someone stays the user's gesture rather than the app's**.

Drawn with `UIGraphicsPDFRenderer` and `NSAttributedString` rather than by rasterising
SwiftUI views: a fourteen-day trip needs real pagination, and printed text should be
selectable and searchable at print resolution. Rendering views to images gives neither.

**Both caveats print on every page.** A printed itinerary is the artefact most likely to be
trusted without question and least likely to be re-checked, because it leaves the app
behind. Travel times are estimates; opening hours are unknown for every site; the page says
so.

### Printing it found two bugs the screen had hidden

**Bristol Temple Meads railway station was filed under "Churches & abbeys."** `\btemple\b`
matches "Temple Meads". Station and street names swallow religious words wholesale —
Temple Quay, Whitechapel, Chapel Street — and it took seeing a rail terminus in a printed
list of abbeys to notice. Sacred is now vetoed for railway, bus and underground stations.

**"The Great Spa Towns of Europe · Belgium"**, printed on a Bath itinerary. A transnational
UNESCO site takes the first country Wikidata lists. Not fixed — it needs the locality
preferred over the country for multi-country sites, which is wider than one veto.

There is a pattern here worth keeping: **each new output surface has exposed defects the
previous ones could not.** The map hid thin data that Explore made obvious; Explore hid
double-counting that durations made obvious; durations hid theme errors that print made
obvious.

## Italy, and the curated sites the planner could not see

The trip planner is the newest output surface, and — following the pattern that each new
surface exposes what the last one hid — auditing it across cities I had not tried surfaced
two bugs, one of them serious.

**Italy was 2.7% imported.** A one-day Rome plan returned the Aurelian Walls and a modern-
art gallery but not the Colosseum. The catalogue held **1,628 Italian sites against 61,192
designated in Wikidata** — Italy had never had a dedicated import, only the original global
sweep. [`fetch_heritage_it.py`](scripts/fetch_heritage_it.py) added **34,813** by
designation grade (`Q26971668`, Italian national heritage — the Colosseum's own),
excluding the natural-conservation designations that dominate the tail. Rome is now a real
city in the app.

**The 123 flagships were invisible to the planner.** Chasing the Colosseum found something
worse than a missing import. The Colosseum was never missing — it is a *curated* site,
hand-authored in Swift. But every derivation script (`derive_themes`, `derive_durations`,
`derive_significance`) only ever reads `bulk_sites.json`, so the curated sites — the
Colosseum, the Mona Lisa, Machu Picchu, Uluru, the exact wonders the app was founded to
show — arrived with **significance 0, visit duration 0, no themes**. The planner filters on
`significance >= 25` and `visitMinutes >= 10`, so *the best 123 places in the whole app
were the only ones a plan could never include.* Fixed at load in
[`BulkData.swift`](Chronicarum/Models/BulkData.swift): a curated site's significance comes
from its author-assigned tier (above anything the bulk scorer produces), its duration from
its type, its themes from name and type. A Rome plan now opens Colosseum → Pantheon →
Museo Nazionale Romano → Aurelian Walls → Sistine Chapel.

That bug had been latent since the planner shipped, and it is the sharpest example yet of
the surface pattern: the map, Explore and the detail sheet all showed the curated sites
perfectly — only planning, which reads the derived fields, exposed that they were empty.

**A self-inflicted one too, worth recording:** adapting the UK merge script for Italy by
find-replacing "United Kingdom" → "Italy" missed the f-string that builds the location
line, so 1,350 Italian sites briefly read "San Giuliano Milanese, United Kingdom". Caught
by sampling the merged output, not by the merge succeeding.

## Draw a region — lasso the map

Answering a direct request: draw a loop on the map, and everything inside it becomes a
group you can summarise and route through.

It reuses the whole existing cluster path. A drawn region produces a `SiteCluster`, which
feeds the *same* overlay a tapped count-bubble already used — spread, nearest, total time,
containment note, "Plan a route", "Zoom". The only genuinely new capability is
screen↔coordinate conversion, which `MapReader`'s `MapProxy` provides on iOS 17.

- A lasso button on the controls rail toggles drawing mode. While active, a transparent
  layer over the map captures the drag and traces the loop, so the map's own pan and zoom
  never fight it.
- On release the screen loop is converted to coordinates; sites are found by a bounding-box
  reject then ray-cast point-in-polygon on lat/lon (flat-earth error is nil over a region
  of tens of km); current filters still apply; the result is capped at 40 by significance,
  so lassoing all of England yields a day's worth, not ten thousand railings.

**The coordinate bug, and the fix.** The first version (build 8) was wrong on device: a
loop drawn over a cluster returned a single site 210 km away. Cause was the classic
`MapReader` trap — the drag gesture and `proxy.convert` resolved `.local` against different
frames, because the map ignores the safe area and the reader does not, so the drawn loop
was converted to coordinates hundreds of km from where it was drawn. Fixed by never
converting the loop to coordinates at all: both the loop and every candidate site are
projected into **one shared named coordinate space**, and point-in-polygon runs in screen
space, so any frame offset cancels. Verified in the simulator by running the real
conversion path — a small loop at the map centre now encloses only sites within ~80 km of
that centre (matching the loop's actual coverage), where the bug placed them 210 km
outside the visible region.

## Open question: institutional sites

The US register carries categories that are arguably distressing and are currently **not**
flagged, because the call is a judgement rather than an omission:

| | unflagged |
|---|---|
| almshouse | 134 |
| asylum | 54 |
| sanatorium | 18 |
| penitentiary | 10 |
| poor farm | 8 |
| reformatory | 2 |

These are sites of institutional confinement, poverty and, in many cases, documented
abuse — but several are also ordinary museums today (Eastern State Penitentiary runs
tours). The plantation case was clear-cut and was acted on; this one is not, and it is
left visible here rather than decided quietly. ~226 sites either way.

## Where to go next — toward the itinerary

The catalogue is now large enough that **more imports are no longer the highest-value
work.** 260k sites is enough to answer the Croatia question anywhere in the UK, US, France
or Australia. What is missing is everything between "here are pins near you" and "here is
your Tuesday".

Ranked by what actually moves the app toward a printable itinerary:

**1. ~~A theme model~~ — done, see *Themes* below.** 16 themes, 65% of the catalogue
tagged, filtering live in both Explore and the map. Stage 4 is unblocked.

**2. ~~Visit duration~~ — done, see *Visit duration* below.** Every site now carries a
banded estimate. **Opening hours remain open and are now the hardest missing piece**: not
in any heritage register, and Wikidata has `P3025` on a rounding error of items. A plan
that sends someone to a closed site is worse than no plan, and this is the item that
decides whether the planner is genuinely useful or merely plausible.

**2b. ~~Containment~~ — partly done.** 2,324 sites now know their container. It fixes the
double-counting it can see and leaves a bigger problem behind it: **selection**. See below.

**2c. ~~Selection~~ — done, see *Selection* below.** Every site scores 0–100 on whether it
is worth a detour, and Explore's "Best" sort combines that with distance. Standing in
Split it now answers: the Palace complex, the Cathedral, the Temple of Jupiter, and Salona
4.9 km out.

**3. Real travel time.** `SiteCluster.route(from:)` already does nearest-neighbour ordering
on straight-line distance, which is fine for "these five are near each other" and useless
for "you can see these four on Tuesday". Self-hosted **Valhalla** (MIT, permits closed-
source commercial use, no per-call cost) over OSM footways and roads is the identified
route. Note this is a *server*, the first the project would need.

**4. Day-shaping.** Given themed sites, durations and travel times, produce N days that a
person would actually enjoy: clustered geographically, varied in kind, not eight churches
in a row, with a sensible start and end. This is the part that is genuinely *the product*
and it is a solved-shape problem once 1–3 exist.

**5. PDF and email.** Both are simple and both are last. A beautiful PDF of a bad plan is
still a bad plan. Email is a send-on-behalf-of-user action — one explicit confirmation per
send, no standing permission.

**6. Photo and description gaps, opportunistically.** 37% of sites still have no
description and 37% no photo. Commons `generator=geosearch` at 500 m can close much of the
photo gap using coordinates we already have, with a relevance heuristic — a photo 400 m
away may be the wrong building.

### Imports still worth doing, but no longer urgent

Netherlands RCE (~63,000), Ireland NIAH (CC BY 4.0, includes image links), Historic England
(OGL) to reconcile UK names. Each is a day's work and adds breadth to markets the planner
already covers adequately. **Croatia is the argument for doing these later, not sooner:**
the constraint there was licensing, not effort, and no amount of importing fixes a
catalogue that cannot say when a place is open.

## Decisions still open

- **OpenStreetMap** would add a genuinely complementary plaque/memorial/public-art layer
  (254 named Brisbane objects Wikidata lacks) — but ODbL §4.6 forces publishing the derived
  database, and §4.7(b) makes that necessary for App Store distribution anyway. Ship OSM
  *and* publish, or don't ship OSM. There is no third option. **Not taken.**
- **CC BY-SA 4.0 §2(a)(5)(B)** has a parallel anti-DRM clause, and Creative Commons' own
  wiki flags App Store distribution as a possible violation while rejecting parallel
  distribution as a cure. Mitigation if we ever enrich with Wikipedia prose: **fetch at
  runtime, don't bake it into the binary** — which is how the official Wikipedia iOS app
  works. Wikidata (CC0) and NRHP (public domain) are unaffected and bundle freely.
- **Don't LLM-rewrite Wikipedia extracts.** That creates an adaptation and CC BY-SA
  attaches to the generated text. Verbatim extract plus a link is the clean path.

---

# Retention research — why stage 7 is the one that pays

Researched July 2026. Kept because its central finding survived contact with the trip
planner idea and in fact points straight at it: **people pay for the record of what they
did, not for the content itself.** An itinerary is what produces that record — you plan a
trip, you take it, and what you are left with is a diary. Stages 5 and 7 are the same loop
seen from either end.

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

# Data pipeline

The catalogue has two layers:

- **Featured sites** — the ~123 hand-authored sites in
  [`Chronicarum/Models/SiteData.swift`](../Chronicarum/Models/SiteData.swift),
  each with a curated tagline, four facts, and multi-chapter storyboard.
- **Bulk sites** — ~14k heritage sites in
  [`Chronicarum/Resources/bulk_sites.json`](../Chronicarum/Resources/bulk_sites.json),
  imported from Wikidata and loaded at runtime by
  [`BulkData.swift`](../Chronicarum/Models/BulkData.swift).

## Regenerating the bulk layer

Both scripts hardcode an absolute scratchpad path at the top — edit `SP` (and, in
`transform_bulk.py`, `CURATED`) before running.

```sh
python3 fetch_bulk.py       # queries Wikidata SPARQL → bulk_{unesco,castle,museum}.json
python3 transform_bulk.py   # merges, dedupes vs featured, maps era → bulk_sites.json
```

Then copy `bulk_sites.json` into `Chronicarum/Resources/` and rebuild.

```sh
python3 derive_country.py    # settle `country` from coordinates, then
python3 derive_collections.py && python3 build_columnar.py
```

> **`bulk_sites.json` is git-ignored, so a data fix that only commits the generated files
> will be silently reverted by the next person who regenerates.** This is not theoretical:
> the country fix was merged as `bulk_columnar.json` + `collections.json`, and rebuilding
> the bundle from a local `bulk_sites.json` that predated it put Volubilis back in the
> Roman Empire. Nothing failed and nothing warned — the numbers just quietly moved.
>
> So a data change is only really landed once the **script that produces it** is committed
> and re-runnable. Before rebuilding, re-run the derive steps rather than assuming your
> row-wise copy is current; they are deterministic, so running them again is free.

**`derive_country.py` must run after any bulk (re)import.** `fetch_bulk.py` asks Wikidata
for `P17` and gets back whichever value comes first, which for a transnational inscription
is an arbitrary one of seven countries and for an archaeological site is often an empire.
The fetch cannot fix this — `P17` genuinely holds all of them — so the choice is made
afterwards, from the site's own coordinates. See "Whose country is this" in ROADMAP.md.

- **Source:** Wikidata SPARQL (`query.wikidata.org/sparql`). Needs a `User-Agent`.
- **Scope:** all UNESCO World Heritage sites + castles + museums + monuments +
  archaeological sites, the non-UNESCO categories filtered to Wikipedia sitelinks ≥ 5
  (a notability floor). Tune `BANDS` / the `CATS` list in `fetch_bulk.py` to widen or
  narrow. `fetch_bulk.py` skips categories whose `bulk_<cat>.json` already exists —
  delete one to refetch it.
- **Era** is inferred from each site's inception date (Wikidata P571); sites with no
  date map to `Era.unknown` ("Undated") rather than a guess.
- Bulk sites are `tier: 2`, below the featured 3–5, so the significance filter doubles
  as a featured-only switch.

## The outdoor layer — trails, walks, bike rides

`fetch_trails.py` is self-contained and needs no scratchpad edit — run it and it writes
`Chronicarum/Resources/trails.json` directly.

```sh
python3 fetch_trails.py     # OSM route relations (Overpass) → trails.json
```

- **Source:** OpenStreetMap route relations via the Overpass API, **ODbL**. The extracted
  geometry is a Derivative Database, so it ships in its own file (a collective database kept
  separate from the heritage catalogue) and the app shows `TrailData.attribution` wherever a
  trail appears. This script IS the "means of creating" ODbL asks us to offer on request.
- **Scope:** national and international named routes only — `network` in `iwn`/`nwn` (walk)
  and `icn`/`ncn` (bike). Local footpaths run to millions; the network tier is the
  significance filter all over again. Pilot bbox is Great Britain — edit `BBOX` to extend.
- **The stage-merge is the point.** OSM splits a long route into a superroute parent (no
  geometry of its own) plus per-stage children. `base_name()` recovers the shared path name
  so the stages rebuild into one multi-segment trail, each stage kept as its own polyline.
- The raw Overpass response is cached at `scripts/.trails_raw_cache.json` (git-ignored, ~68
  MB) so re-runs while tuning filters don't re-query. Delete it to force a fresh pull.
- Geometry is simplified (Ramer–Douglas–Peucker) and stored as precision-5 encoded
  polylines; the whole file is ~200 KB, small enough to bundle without LFS.

## Shipping to TestFlight

Bump `CURRENT_PROJECT_VERSION` in `project.yml`, then:

```sh
xcodegen generate
xcodebuild -project Chronicarum.xcodeproj -scheme Chronicarum -configuration Release \
  -destination generic/platform=iOS -archivePath build/Chronicarum.xcarchive archive
xcodebuild -exportArchive -archivePath build/Chronicarum.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export      # retry on Apple 504
xcrun altool --upload-app -f build/export/Chronicarum.ipa -t ios \
  --apiKey 9K9486HSDF --apiIssuer 69a6de8c-a266-47e3-e053-5b8c7c11a4d1
```

- `ExportOptions.plist` lives in the repo root (team `L9SAXP2E2W`, app-store-connect method).
- The API key is `~/.appstoreconnect/private_keys/AuthKey_9K9486HSDF.p8`; the **issuer** is
  `69a6de8c-a266-47e3-e053-5b8c7c11a4d1`. Do **not** confuse the issuer with the
  provisioning-profile UUID `0a202525-…`: passing that to `--apiIssuer` gives a persistent
  401 "credentials invalid" even though the key parses.
- Export sometimes fails with a transient Apple 504 — retry the `-exportArchive` step a few
  times before treating it as a real failure.

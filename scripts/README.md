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

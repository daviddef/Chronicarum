"""Settle the `country` field from where the site actually is.

## The bug, as printed

    The Great Spa Towns of Europe · Belgium

on an itinerary for **Bath**. The inscription covers eleven towns in seven countries;
Wikidata records all seven in `P17` and the bulk import took whichever came back first.
Belgium won, so a transnational site 500 km away joined "World Heritage Sites of Belgium",
and a user standing in Bath was told that collection was 0 km off.

## What the measurement found

Only the **22,234 rows whose `country` is a bare country name** can carry this defect —
they are the ones from the original Wikidata sweep. Everything else was written by a
national import (`Aberdeenshire, United Kingdom`) and its country is settled by the register
it came from. Of those rows, checked against Natural Earth boundaries:

    21,398   one P17 value          the ordinary case, nothing to choose
       379   two or more P17 values the defect's territory
       457   no P17 at all          461 rows carry no country at all

The 379 are **not** mostly transnational sites. Sorting them by what the extra values are:

    Ancient Rome 63 · Soviet Union 27 · Byzantine Empire 13 · Russian Empire 12
    Roman Empire 8 · Bosporan Kingdom 7 · Austria–Hungary 7 · Sasanian Empire 6 ...

Wikidata's `P17` answers "what state was this in", across all of history, and for an
archaeological site the honest answer is a list of empires. Volubilis was filed under
**Roman Empire**, Bukhara under **Russian Empire**, the Historic Centre of Saint Petersburg
under the **Soviet Union**. That is a larger class than the transnational one and the same
first-value-wins bug produced it, so one pass fixes both.

Genuinely transnational World Heritage in the catalogue: **54 inscriptions**, of which 30
were filed under a country their own coordinates are not in.

## The rule

**The coordinate chooses among the claims the source already makes.** It picks which of a
site's `P17` values to keep; it does not invent one. That is what makes it safe to run over
22k rows — the worst case is that a site keeps the country Wikidata gave it.

The one exception is a site whose every claim is a *defunct* state (`P576` dissolution
date): there is nothing to choose, so the coordinate answers outright. This is also what
fills the 461 blanks.

## Where the coordinate is not an authority

Natural Earth follows de-facto control, and in four places that would have the app take a
sovereignty position it has no business taking — reassigning Crimean sites to Russia,
Golan sites to Israel. Inside the regions listed in `DISPUTED` the coordinate is ignored
and the source's country stands, including when the source's country is an empire that
fell in 476. Declining to adjudicate is the point; a tidier answer here would be a claim.
"""
import json, os, subprocess, sys, time
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geolocate import CountryIndex, boundaries

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE = f"{ROOT}/Chronicarum/Resources/bulk_sites.json"
SP = os.environ.get("CHRONICARUM_SCRATCH", "/private/tmp/chronicarum")

UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"
CHUNK = 700          # QIDs per query; a VALUES block much past this exceeds the URL limit

# name -> (lat0, lat1, lon0, lon1). Territories whose control is contested, where Natural
# Earth's answer is a position rather than a fact.
DISPUTED = {
    "Crimea":         (44.30, 46.30, 32.40, 36.95),   # Natural Earth: Russia
    "Golan Heights":  (32.62, 33.35, 35.62, 35.92),   # Natural Earth: Israel
    "East Jerusalem": (31.74, 31.84, 35.20, 35.29),   # Natural Earth: Israel
}


def sparql(query, attempts=4):
    for attempt in range(attempts):
        out = subprocess.run(
            ["curl", "-sS", "--max-time", "300", ENDPOINT,
             "--data-urlencode", f"query={query}",
             "-H", "Accept: application/sparql-results+json",
             "-H", f"User-Agent: {UA}"], capture_output=True, text=True)
        try:
            return json.loads(out.stdout)["results"]["bindings"]
        except Exception:
            sys.stderr.write(f"  ! attempt {attempt + 1} failed\n")
            time.sleep(8)
    sys.exit("gave up on Wikidata")


def cached(name, build):
    """Every fetch here is slow and none of it changes between runs of the resolver."""
    path = f"{SP}/{name}"
    if os.path.exists(path):
        return json.load(open(path))
    value = build()
    json.dump(value, open(path, "w"))
    return value


def fetch_claims(qids):
    """{QID: {country QID: label}} — every P17 value, not just the first."""
    claims = {}
    for start in range(0, len(qids), CHUNK):
        chunk = qids[start:start + CHUNK]
        values = " ".join("wd:" + q for q in chunk)
        rows = sparql(f"""SELECT ?item ?country ?countryLabel WHERE {{
  VALUES ?item {{ {values} }}
  ?item wdt:P17 ?country .
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }} }}""")
        for b in rows:
            item = b["item"]["value"].rsplit("/", 1)[-1]
            claims.setdefault(item, {})[b["country"]["value"].rsplit("/", 1)[-1]] = \
                b["countryLabel"]["value"]
        sys.stderr.write(f"  P17: {start + len(chunk):,}/{len(qids):,}\n")
    return claims


def fetch_states(qids):
    """{QID: {label, iso, end}} for everything P17 pointed at.

    `end` is P576, the dissolution date, and it is the whole test for "is this a country
    or a fallen empire" — an ISO code is not, because the Netherlands has no code of its
    own and Kosovo's is unofficial."""
    states = {}
    for start in range(0, len(qids), CHUNK):
        values = " ".join("wd:" + q for q in qids[start:start + CHUNK])
        rows = sparql(f"""SELECT ?c ?cLabel ?end ?iso WHERE {{ VALUES ?c {{ {values} }}
  OPTIONAL {{ ?c wdt:P576 ?end }} OPTIONAL {{ ?c wdt:P297 ?iso }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }} }}""")
        for b in rows:
            entry = states.setdefault(b["c"]["value"].rsplit("/", 1)[-1],
                                      {"label": b["cLabel"]["value"], "iso": None, "end": None})
            if "iso" in b:
                entry["iso"] = b["iso"]["value"]
            if "end" in b:
                entry["end"] = b["end"]["value"]
    return states


def fetch_iso_labels():
    """ISO 3166-1 alpha-2 -> the label the catalogue already uses for that country."""
    rows = sparql("""SELECT ?c ?cLabel ?iso WHERE {
  ?c wdt:P297 ?iso . SERVICE wikibase:label { bd:serviceParam wikibase:language "en". } }""")
    return {b["iso"]["value"]: {"qid": b["c"]["value"].rsplit("/", 1)[-1],
                                "label": b["cLabel"]["value"]} for b in rows}


def disputed(lat, lon):
    for name, (lat0, lat1, lon0, lon1) in DISPUTED.items():
        if lat0 <= lat <= lat1 and lon0 <= lon <= lon1:
            return name
    return None


def main():
    os.makedirs(SP, exist_ok=True)
    sites = json.load(open(BUNDLE))

    # A comma means a national import wrote the field ("Fife, United Kingdom") and the
    # register it came from already settled the country. Only the bare ones are P17's.
    candidates = [s for s in sites
                  if s["id"].startswith("wd-") and "," not in s.get("country", "")]
    qids = [s["id"][3:] for s in candidates]
    print(f"{len(candidates):,} of {len(sites):,} rows carry a bare country from P17")

    claims = cached("p17_claims.json", lambda: fetch_claims(qids))
    referenced = sorted({q for v in claims.values() for q in v})
    states = cached("p17_states.json", lambda: fetch_states(referenced))
    iso_labels = cached("iso_labels.json", fetch_iso_labels)
    index = CountryIndex(boundaries(SP), iso_labels)

    def living(qid):
        state = states.get(qid)
        return bool(state) and not state["end"]

    stats, changes = Counter(), []
    for site in candidates:
        stated = site.get("country", "")
        held = {q: label for q, label in claims.get(site["id"][3:], {}).items() if living(q)}
        here = index.country(site["lat"], site["lon"])
        region = disputed(site["lat"], site["lon"])

        if region:
            stats[f"left alone: {region}"] += 1
            continue
        if here and len(held) > 1 and here in held.values():
            resolved, why = here, "several claims, coordinate chose"
        elif held and len(held) == 1 and stated not in held.values():
            resolved, why = next(iter(held.values())), "stated state is defunct"
        elif not held and here:
            resolved, why = here, "no living claim, coordinate answered"
        else:
            stats["left alone"] += 1
            continue

        stats[why] += 1
        if resolved == stated:
            stats["  already right"] += 1
            continue
        changes.append((site["id"], site["name"], stated, resolved))
        site["country"] = resolved

    json.dump(sites, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

    print(f"\n{len(changes):,} rows rewritten -> {BUNDLE}")
    for reason, count in stats.most_common():
        print(f"  {count:>6}  {reason}")
    print("\n  most common corrections:")
    for (was, now), count in Counter((c[2] or "(none)", c[3]) for c in changes).most_common(12):
        print(f"    {count:>4}  {was:<28} -> {now}")


if __name__ == "__main__":
    main()

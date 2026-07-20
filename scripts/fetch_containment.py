"""Find which sites are physically inside other sites.

## The problem

"Castles and Roman history" within 400 m of Split's centre sums to 10.8 hours of visiting
for one afternoon:

    Historical Complex of Split with the Palace of Diocletian   180 min
    Diocletian's Palace                                         120 min
    Golden Gate                                                  60 min
    Silver Gate                                                  20 min

These are not four visits. The gates are in the palace, which *is* the UNESCO complex —
three registers describing the same stones at three scales. Until the catalogue knows that,
day-shaping cannot add up a day.

This is **not** the duplicate problem the merge scripts solve. A duplicate is one place
recorded twice; these are genuinely different records at different scales, all correct.

## Source

Wikidata `P361` (part of), which is explicit and free. Two filters make it usable:

  * **Both ends must be in our catalogue.** "Part of Europe" is true and useless.
  * **The parts must be near each other.** `P361` is also used for class membership —
    a generic "stećak" is "part of" necropolises 20, 55 and 67 km apart. Real containment
    is metres. 2 km is generous and still removes every false pair observed.

Coverage is thin — Wikidata records this for a small fraction of heritage — so this
establishes *precise* containment only. Sites the data does not cover are handled at plan
time by grouping, not by guessing a parent here.
"""
import json, subprocess, sys, time

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

# The markets actually imported, plus a designation-restricted global sweep for the
# original Wikidata layer. Per-country because a single unrestricted P361 query over all
# of Wikidata times out — the property is used for everything from body parts to albums.
QUERIES = {
    "United Kingdom": 'wd:Q145', "United States": 'wd:Q30', "France": 'wd:Q142',
    "Australia": 'wd:Q408', "Croatia": 'wd:Q224', "Italy": 'wd:Q38',
    "Spain": 'wd:Q29', "Germany": 'wd:Q183', "Greece": 'wd:Q41',
}

def country_query(country):
    """Bounded by heritage designation on purpose.

    The unrestricted form — every item in the country with coordinates and a P361 — is far
    too broad to run: the UK alone has on the order of a million geocoded items and P361 is
    used across all of them, so the query times out repeatedly. Requiring the child to be
    heritage-designated bounds it to the shape of our catalogue and returns in seconds."""
    return f"""
SELECT ?item ?parent WHERE {{
  ?item wdt:P17 {country} ; wdt:P1435 ?d ; wdt:P625 ?c ; wdt:P361 ?parent .
  ?parent wdt:P625 ?pc .
}}"""

GLOBAL_QUERY = """
SELECT ?item ?parent WHERE {
  ?item wdt:P1435 ?d ; wdt:P625 ?c ; wdt:P361 ?parent .
  ?parent wdt:P625 ?pc .
}"""

def run(query, label):
    for attempt in range(4):
        out = subprocess.run(
            ["curl", "-sS", "-G", "--max-time", "300", ENDPOINT,
             "--data-urlencode", f"query={query}",
             "-H", "Accept: application/sparql-results+json",
             "-H", f"User-Agent: {UA}"], capture_output=True, text=True)
        try:
            return json.loads(out.stdout)["results"]["bindings"]
        except Exception:
            sys.stderr.write(f"    ! {label} attempt {attempt + 1} failed\n")
            time.sleep(8)
    return None

pairs = set()

for name, qid in QUERIES.items():
    rows = run(country_query(qid), name)
    if rows is None:
        sys.stderr.write(f"  ! {name}: GAVE UP — coverage incomplete\n")
        continue
    for b in rows:
        pairs.add((b["item"]["value"].rsplit("/", 1)[-1],
                   b["parent"]["value"].rsplit("/", 1)[-1]))
    print(f"  {name:<18} {len(rows):>6} relations (total {len(pairs)})", flush=True)

rows = run(GLOBAL_QUERY, "global P1435")
if rows is not None:
    before = len(pairs)
    for b in rows:
        pairs.add((b["item"]["value"].rsplit("/", 1)[-1],
                   b["parent"]["value"].rsplit("/", 1)[-1]))
    print(f"  {'global (P1435)':<18} {len(rows):>6} relations (+{len(pairs) - before} new)")

json.dump(sorted(pairs), open(f"{SP}/containment.json", "w"))
print(f"\n{len(pairs)} candidate part-of relations -> containment.json")

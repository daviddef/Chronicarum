"""Italy — the biggest hole in the catalogue.

A trip-planner audit surfaced it: asking for a day in Rome returned the Aurelian Walls and
a modern-art gallery but **not the Colosseum**, which was not in the catalogue at all. Nor
the Pantheon, nor the Trevi Fountain. Italy had never had a dedicated import — it entered
only through the original global sweep — so the catalogue held **1,628 Italian sites
against 61,192 designated in Wikidata**, and the single most-visited monument in Rome fell
in the missing 97%.

For an app whose founding promise was "I want to see the Mona Lisa and the Inca pyramids",
missing the Colosseum is the worst possible gap.

Same approach as the UK: import by designation, split into a cheap core query (label,
coords, image) and a separate enrichment query joined by QID, because the combined form
times out.

`Q26971668` ("Italian national heritage") is the designation the Colosseum carries and
covers 56,153 sites. The other large Italian designations are natural-conservation areas —
Special Areas of Conservation, sites of community importance, Special Protection Areas —
which are not visitor destinations and are left out.
"""
import json, subprocess, sys, time, urllib.parse

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

DESIGNATIONS = [
    ("Q26971668", "Italian national heritage"),
    ("Q18946666", "South Tyrol heritage"),
    ("Q3323404",  "national monument of Italy"),
]

def core_query(qid):
    return f"""
SELECT ?item ?lab ?lat ?lon ?img WHERE {{
  ?item wdt:P1435 wd:{qid} ; rdfs:label ?lab .
  FILTER(LANG(?lab)="en")
  ?item p:P625 ?cs . ?cs psv:P625 ?cv .
  ?cv wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon .
  OPTIONAL {{ ?item wdt:P18 ?img }}
}}"""

def enrich_query(qid):
    return f"""
SELECT ?item ?adminLabel ?kindLabel ?inception WHERE {{
  ?item wdt:P1435 wd:{qid} .
  OPTIONAL {{ ?item wdt:P131 ?admin }}
  OPTIONAL {{ ?item wdt:P31 ?kind }}
  OPTIONAL {{ ?item wdt:P571 ?inception }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
}}"""

def run(q, label):
    for attempt in range(4):
        out = subprocess.run(
            ["curl", "-sS", "-G", "--max-time", "300", ENDPOINT,
             "--data-urlencode", f"query={q}",
             "-H", "Accept: application/sparql-results+json",
             "-H", f"User-Agent: {UA}"], capture_output=True, text=True)
        try:
            return json.loads(out.stdout)["results"]["bindings"]
        except Exception:
            sys.stderr.write(f"    ! {label} attempt {attempt + 1} failed\n")
            time.sleep(10)
    return None

rows, failed = {}, []

for qid, name in DESIGNATIONS:
    core = run(core_query(qid), f"{name} core")
    if core is None:
        failed.append(name)
        continue
    added = 0
    for b in core:
        q = b["item"]["value"].rsplit("/", 1)[-1]
        if q in rows:
            if "img" in b and not rows[q].get("img"):
                rows[q]["img"] = urllib.parse.unquote(b["img"]["value"].rsplit("/", 1)[-1])
            continue
        rows[q] = {
            "qid": q,
            "name": b["lab"]["value"],
            "lat": round(float(b["lat"]["value"]), 5),
            "lon": round(float(b["lon"]["value"]), 5),
            "img": urllib.parse.unquote(b["img"]["value"].rsplit("/", 1)[-1])
                   if "img" in b else None,
        }
        added += 1

    extra = run(enrich_query(qid), f"{name} enrich")
    enriched = 0
    if extra is not None:
        for b in extra:
            q = b["item"]["value"].rsplit("/", 1)[-1]
            r = rows.get(q)
            if r is None:
                continue
            if not r.get("admin"):
                r["admin"] = b.get("adminLabel", {}).get("value")
            if not r.get("kind"):
                r["kind"] = b.get("kindLabel", {}).get("value")
            if not r.get("inception"):
                r["inception"] = b.get("inception", {}).get("value")
            enriched += 1

    print(f"  {name:<28} {len(core):>6} rows, +{added:>6} new, "
          f"{enriched:>6} enrichment hits (total {len(rows)})", flush=True)

out = list(rows.values())
json.dump(out, open(f"{SP}/heritage_it.json", "w"), ensure_ascii=False)
print(f"\n{len(out)} Italian heritage places -> heritage_it.json")
print(f"  with photo:     {sum(1 for r in out if r.get('img'))}")
print(f"  Colosseum present: {'Q10285' in rows}")
if failed:
    print(f"  ! failed: {failed}")

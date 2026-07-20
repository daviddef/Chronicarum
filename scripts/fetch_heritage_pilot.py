"""Brisbane pilot: import by HERITAGE DESIGNATION rather than Wikipedia popularity.

The existing bulk import filters on Wikipedia sitelinks (>=5 language editions), which
works for the Colosseum and destroys local heritage — 546 heritage-designated places
within 20km of Brisbane, only 11 of which clear that bar.

Wikidata P1435 ("heritage designation") is the better signal: if a government register
lists a place, that is a stronger statement about it being worth visiting than how many
Wikipedias happen to describe it. Worldwide there are ~2.1M such items with coordinates.

Fetched in concentric rings so each query stays inside the 60s SPARQL timeout.
"""
import json, subprocess, sys, time, urllib.parse

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

CENTRE = (153.0251, -27.4698)   # Brisbane CBD, lon/lat for wikibase:around
RADII  = [3, 6, 10, 15, 25, 40, 60]

def query(radius):
    return f"""
SELECT ?item ?lab ?lat ?lon ?desc ?img ?inception ?kindLabel WHERE {{
  SERVICE wikibase:around {{
    ?item wdt:P625 ?loc .
    bd:serviceParam wikibase:center "Point({CENTRE[0]} {CENTRE[1]})"^^geo:wktLiteral .
    bd:serviceParam wikibase:radius "{radius}" .
  }}
  ?item wdt:P1435 ?designation .
  ?item rdfs:label ?lab . FILTER(LANG(?lab)="en")
  ?item p:P625 ?cs . ?cs psv:P625 ?cv .
  ?cv wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon .
  OPTIONAL {{ ?item schema:description ?desc . FILTER(LANG(?desc)="en") }}
  OPTIONAL {{ ?item wdt:P18 ?img }}
  OPTIONAL {{ ?item wdt:P571 ?inception }}
  OPTIONAL {{ ?item wdt:P31 ?kind . ?kind rdfs:label ?kindLabel . FILTER(LANG(?kindLabel)="en") }}
}}"""

def run(q):
    for attempt in range(4):
        out = subprocess.run(
            ["curl", "-sS", "-G", "--max-time", "180", ENDPOINT,
             "--data-urlencode", f"query={q}",
             "-H", "Accept: application/sparql-results+json",
             "-H", f"User-Agent: {UA}"], capture_output=True, text=True)
        try:
            return json.loads(out.stdout)["results"]["bindings"]
        except Exception:
            sys.stderr.write(f"  ! attempt {attempt+1} failed\n")
            time.sleep(8)
    return None

rows = {}
for r in RADII:
    res = run(query(r))
    if res is None:
        sys.stderr.write(f"  ! radius {r}km gave up — coverage incomplete\n")
        continue
    added = 0
    for b in res:
        qid = b["item"]["value"].rsplit("/", 1)[-1]
        if qid in rows:
            # keep the richest record: prefer one that carries a photo
            if "img" in b and "img" not in rows[qid]:
                rows[qid].update(b)
            continue
        rows[qid] = b
        added += 1
    print(f"  radius {r:>2}km: {len(res):>5} rows, +{added} new (total {len(rows)})", flush=True)

out = []
for qid, b in rows.items():
    out.append({
        "qid": qid,
        "name": b["lab"]["value"],
        "lat": round(float(b["lat"]["value"]), 5),
        "lon": round(float(b["lon"]["value"]), 5),
        "desc": b.get("desc", {}).get("value"),
        "img": urllib.parse.unquote(b["img"]["value"].rsplit("/", 1)[-1]) if "img" in b else None,
        "inception": b.get("inception", {}).get("value"),
        "kind": b.get("kindLabel", {}).get("value"),
    })

json.dump(out, open(f"{SP}/heritage_brisbane.json", "w"), ensure_ascii=False)
print(f"\n{len(out)} heritage places -> heritage_brisbane.json")
print(f"  with photo: {sum(1 for r in out if r['img'])}")
print(f"  with desc:  {sum(1 for r in out if r['desc'])}")

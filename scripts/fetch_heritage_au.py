"""Australia-wide heritage import, partitioned by register.

Same principle as the Brisbane pilot: inclusion by heritage designation (P1435) rather
than Wikipedia popularity. Partitioned per register because each is a natural, bounded
slice — the largest is ~2,400 rows — which keeps every query inside the 60s SPARQL
timeout without paging tricks.
"""
import json, subprocess, sys, time, urllib.parse

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

# Every designation with >=8 items in Australia, from the register census.
REGISTERS = [
    "Q28147634", "Q56052054", "Q28152854", "Q20680290", "Q56046814", "Q30108476",
    "Q28152860", "Q20747146", "Q28152858", "Q30166806", "Q19683138", "Q30129400",
    "Q66493566", "Q43113623", "Q28147636", "Q17006517", "Q64869389", "Q28152859",
    "Q28147635", "Q9259", "Q47457178", "Q39086668",
]

def query(designation):
    return f"""
SELECT ?item ?lab ?lat ?lon ?desc ?img ?inception ?kindLabel ?admin ?adminLabel WHERE {{
  ?item wdt:P1435 wd:{designation} ; wdt:P17 wd:Q408 .
  ?item rdfs:label ?lab . FILTER(LANG(?lab)="en")
  ?item p:P625 ?cs . ?cs psv:P625 ?cv .
  ?cv wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon .
  OPTIONAL {{ ?item schema:description ?desc . FILTER(LANG(?desc)="en") }}
  OPTIONAL {{ ?item wdt:P18 ?img }}
  OPTIONAL {{ ?item wdt:P571 ?inception }}
  OPTIONAL {{ ?item wdt:P31 ?kind . ?kind rdfs:label ?kindLabel . FILTER(LANG(?kindLabel)="en") }}
  OPTIONAL {{ ?item wdt:P131 ?admin . ?admin rdfs:label ?adminLabel . FILTER(LANG(?adminLabel)="en") }}
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
            sys.stderr.write(f"    ! attempt {attempt+1} failed\n")
            time.sleep(8)
    return None

rows, failed = {}, []
for reg in REGISTERS:
    res = run(query(reg))
    if res is None:
        failed.append(reg)
        sys.stderr.write(f"  ! {reg}: GAVE UP — coverage incomplete\n")
        continue
    added = 0
    for b in res:
        qid = b["item"]["value"].rsplit("/", 1)[-1]
        if qid in rows:
            # Prefer the richer record — a photo, or an admin area for the location line.
            if "img" in b and "img" not in rows[qid]:
                rows[qid].update(b)
            continue
        rows[qid] = b
        added += 1
    print(f"  {reg}: {len(res):>5} rows, +{added} new (total {len(rows)})", flush=True)

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
        "admin": b.get("adminLabel", {}).get("value"),
    })

json.dump(out, open(f"{SP}/heritage_au.json", "w"), ensure_ascii=False)
print(f"\n{len(out)} Australian heritage places -> heritage_au.json")
print(f"  with photo: {sum(1 for r in out if r['img'])}")
print(f"  with desc:  {sum(1 for r in out if r['desc'])}")
if failed:
    print(f"  ! registers that failed and were skipped: {failed}")

"""UK heritage import, partitioned by designation grade.

Same inclusion principle as Australia (Wikidata P1435), but the UK forces a scope decision
Australia did not. There are ~480,000 listed buildings, and Grade II alone is 378,336 —
about 81 MB of JSON against a whole current bundle of 8.2 MB. Grade II is also the
"ordinary" tier: terraced houses, garden walls, milestones, telephone boxes. Pinning it
would repeat the South Australian Contributory mistake at a hundred times the scale, and
would mostly be pointing at people's homes.

So the line is drawn at the tiers that mean "worth going to see":

    Grade I          10,101   exceptional interest              (99% have a photo)
    Grade II*        24,515   more than special interest
    Scheduled mon.   33,709   nationally important archaeology
    Category A        6,515   Scotland, national importance     (~ Grade I)
    Category B       34,621   Scotland, regional importance     (~ Grade II*)

Scottish Category C is excluded for the same reason as Grade II — it is the local tier.
Including A and B but not C keeps Scotland at the same bar as England and Wales; taking
only Category A would under-represent Scotland exactly the way sitelink-count filtering
under-represented Brisbane.

Query shape matters here. The obvious single query with OPTIONAL P31/P131/P571 label
lookups times out at 60s on every one of these designations, and LIMIT/OFFSET paging over
an ORDER BY is worse. Splitting into a cheap core query (label, coordinates, image) and a
separate enrichment query joined locally by QID brings a 10k-row designation down to
about 5 seconds.
"""
import json, subprocess, sys, time, urllib.parse

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

DESIGNATIONS = [
    ("Q15700818", "Grade I"),
    ("Q15700831", "Grade II*"),
    ("Q219538",   "Scheduled monument"),
    ("Q10729054", "Category A (Scotland)"),
    ("Q10729125", "Category B (Scotland)"),
]

def core_query(qid):
    """Label, coordinates and image only. Everything else makes this time out."""
    return f"""
SELECT ?item ?lab ?lat ?lon ?img WHERE {{
  ?item wdt:P1435 wd:{qid} ; rdfs:label ?lab .
  FILTER(LANG(?lab)="en")
  ?item p:P625 ?cs . ?cs psv:P625 ?cv .
  ?cv wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon .
  OPTIONAL {{ ?item wdt:P18 ?img }}
}}"""

def enrich_query(qid):
    """Admin area, kind and inception, joined back by QID. Uses the label service rather
    than explicit rdfs:label OPTIONALs, which is what makes it affordable."""
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
        sys.stderr.write(f"  ! {name}: GAVE UP — coverage incomplete\n")
        continue

    added = 0
    for b in core:
        q = b["item"]["value"].rsplit("/", 1)[-1]
        if q in rows:
            # Already seen under another designation (a scheduled monument is often also
            # a listed building). Keep the first, but take a photo if this one has one.
            if "img" in b and not rows[q].get("img"):
                rows[q]["img"] = urllib.parse.unquote(
                    b["img"]["value"].rsplit("/", 1)[-1])
            continue
        rows[q] = {
            "qid": q,
            "name": b["lab"]["value"],
            "lat": round(float(b["lat"]["value"]), 5),
            "lon": round(float(b["lon"]["value"]), 5),
            "img": urllib.parse.unquote(b["img"]["value"].rsplit("/", 1)[-1])
                   if "img" in b else None,
            "grade": name,
        }
        added += 1

    extra = run(enrich_query(qid), f"{name} enrich")
    enriched = 0
    if extra is None:
        sys.stderr.write(f"  ~ {name}: enrichment failed, keeping bare rows\n")
    else:
        for b in extra:
            q = b["item"]["value"].rsplit("/", 1)[-1]
            r = rows.get(q)
            if r is None:
                continue          # no coordinates, so it never made the core set
            # P31 is multi-valued; first non-empty wins, matching the AU import.
            if not r.get("admin"):
                r["admin"] = b.get("adminLabel", {}).get("value")
            if not r.get("kind"):
                r["kind"] = b.get("kindLabel", {}).get("value")
            if not r.get("inception"):
                r["inception"] = b.get("inception", {}).get("value")
            enriched += 1

    print(f"  {name:<24} {len(core):>6} rows, +{added:>6} new, "
          f"{enriched:>6} enrichment hits (total {len(rows)})", flush=True)

out = list(rows.values())
json.dump(out, open(f"{SP}/heritage_uk.json", "w"), ensure_ascii=False)

print(f"\n{len(out)} UK heritage places -> heritage_uk.json")
print(f"  with photo:    {sum(1 for r in out if r.get('img'))}")
print(f"  with admin:    {sum(1 for r in out if r.get('admin'))}")
print(f"  with kind:     {sum(1 for r in out if r.get('kind'))}")
print(f"  with inception:{sum(1 for r in out if r.get('inception'))}")
if failed:
    print(f"  ! designations that failed and were skipped: {failed}")

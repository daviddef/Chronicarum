"""Fill photo gaps for curated sites that have no bulk twin (the Eiffel Tower, the Mona
Lisa and Uluru aren't castles, museums or archaeological sites).

Matches by exact English label AND requires the item's coordinates to sit near the
curated site's. Either signal alone is unsafe: a label can be ambiguous, and proximity
alone once put a floor plan of a neighbouring Roman structure on the Colosseum."""
import json, re, subprocess, sys, time

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
CURATED = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Models/SiteData.swift"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"
MAX_DEGREES = 0.15   # ~15 km: generous enough for differing centroids, tight enough to disambiguate

src = open(CURATED).read()
sites = []
for blk in re.split(r"\n        Site\(", src)[1:]:
    i  = re.search(r'id: "([^"]+)"', blk)
    n  = re.search(r'name: "([^"]+)"', blk)
    la = re.search(r"latitude: (-?[\d.]+)", blk)
    lo = re.search(r"longitude: (-?[\d.]+)", blk)
    if i and n and la and lo:
        sites.append({"id": i.group(1), "name": n.group(1),
                      "lat": float(la.group(1)), "lon": float(lo.group(1))})

existing = json.load(open(f"{SP}/featured_images.json"))
missing = [s for s in sites if s["id"] not in existing]
print(f"{len(missing)} curated sites without a photo")

def esc(v):
    return v.replace("\\", "\\\\").replace('"', '\\"')

added = 0
# Query in small groups so one bad label can't fail the whole batch.
for i in range(0, len(missing), 12):
    chunk = missing[i:i + 12]
    values = " ".join(f'"{esc(s["name"])}"@en' for s in chunk)
    query = f"""
SELECT ?lab ?image ?lat ?lon WHERE {{
  VALUES ?lab {{ {values} }}
  ?item rdfs:label ?lab ; wdt:P18 ?image ; p:P625 ?cs .
  ?cs psv:P625 ?cv . ?cv wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon .
}}"""
    out = subprocess.run(
        ["curl", "-sS", "-G", "--max-time", "120", ENDPOINT,
         "--data-urlencode", f"query={query}",
         "-H", "Accept: application/sparql-results+json",
         "-H", f"User-Agent: {UA}"], capture_output=True, text=True)
    try:
        rows = json.loads(out.stdout)["results"]["bindings"]
    except Exception:
        sys.stderr.write(f"  ! chunk {i//12} failed\n")
        time.sleep(5)
        continue

    for s in chunk:
        for r in rows:
            if r["lab"]["value"] != s["name"]:
                continue
            if abs(float(r["lat"]["value"]) - s["lat"]) > MAX_DEGREES: continue
            if abs(float(r["lon"]["value"]) - s["lon"]) > MAX_DEGREES: continue
            import urllib.parse
            existing[s["id"]] = urllib.parse.unquote(r["image"]["value"].rsplit("/", 1)[-1])
            added += 1
            break
    time.sleep(1)

json.dump(existing, open(f"{SP}/featured_images.json", "w"), ensure_ascii=False, indent=1)
print(f"recovered {added} more; featured photos now {len(existing)}/{len(sites)}")

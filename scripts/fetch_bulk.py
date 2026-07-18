"""Fetch heritage sites from Wikidata in sitelink bands (to dodge the 60s query
timeout), dedupe, and write one compact raw file per category.

Skips any category whose bulk_<cat>.json already exists, so it's cheap to re-run when
adding a new category. Delete the file to force a refetch."""
import json, os, subprocess, sys, time

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

# (category label, WHERE clause selecting the class, our site type)
CATS = [
    ("unesco",        "?item wdt:P1435 wd:Q9259 .",             "unesco"),
    ("castle",        "?item wdt:P31/wdt:P279* wd:Q23413 .",    "castle"),
    ("museum",        "?item wdt:P31/wdt:P279* wd:Q33506 .",    "museum"),
    ("monument",      "?item wdt:P31/wdt:P279* wd:Q4989906 .",  "monument"),
    ("archaeological","?item wdt:P31/wdt:P279* wd:Q839954 .",   "archaeological"),
]
# sitelink bands: UNESCO keeps all (>=0); castles/museums notability-filtered (>=5).
BANDS = [(5, 7), (8, 11), (12, 24), (25, 1000)]

def sparql(query):
    out = subprocess.run(
        ["curl", "-sS", "-G", "--max-time", "120", ENDPOINT,
         "--data-urlencode", f"query={query}",
         "-H", "Accept: application/sparql-results+json",
         "-H", f"User-Agent: {UA}"],
        capture_output=True, text=True)
    try:
        return json.loads(out.stdout)["results"]["bindings"]
    except Exception:
        sys.stderr.write(f"  ! query failed ({out.stdout[:120]!r})\n")
        return None

def q(where, lo, hi, unesco):
    band = "" if unesco else f"?item wikibase:sitelinks ?sl . FILTER(?sl >= {lo} && ?sl <= {hi})"
    return f"""
SELECT ?item ?lab ?lat ?lon ?countryLabel ?desc ?inception WHERE {{
  {where}
  ?item p:P625 ?cs . ?cs psv:P625 ?cv .
  ?cv wikibase:geoLatitude ?lat ; wikibase:geoLongitude ?lon .
  ?item rdfs:label ?lab . FILTER(LANG(?lab)="en")
  {band}
  OPTIONAL {{ ?item wdt:P17 ?country . ?country rdfs:label ?countryLabel . FILTER(LANG(?countryLabel)="en") }}
  OPTIONAL {{ ?item schema:description ?desc . FILTER(LANG(?desc)="en") }}
  OPTIONAL {{ ?item wdt:P571 ?inception . }}
}}"""

def main():
    for cat, where, stype in CATS:
        if os.path.exists(f"{SP}/bulk_{cat}.json"):
            print(f"{cat}: already fetched, skipping")
            continue
        seen, rows = {}, []
        bands = [(0, 100000)] if cat == "unesco" else BANDS
        for lo, hi in bands:
            for attempt in range(3):
                res = sparql(q(where, lo, hi, cat == "unesco"))
                if res is not None:
                    break
                time.sleep(5)
            if res is None:
                sys.stderr.write(f"  ! {cat} band {lo}-{hi} gave up\n"); continue
            for r in res:
                qid = r["item"]["value"].rsplit("/", 1)[-1]
                if qid in seen:
                    continue
                seen[qid] = 1
                rows.append({
                    "qid":  qid,
                    "name": r["lab"]["value"],
                    "lat":  round(float(r["lat"]["value"]), 5),
                    "lon":  round(float(r["lon"]["value"]), 5),
                    "country": r.get("countryLabel", {}).get("value"),
                    "desc": r.get("desc", {}).get("value"),
                    "inception": r.get("inception", {}).get("value"),
                    "stype": stype,
                })
            print(f"  {cat} band {lo}-{hi}: +{len(res)} rows (total {len(rows)})")
        json.dump(rows, open(f"{SP}/bulk_{cat}.json", "w"), ensure_ascii=False)
        print(f"{cat}: {len(rows)} unique -> bulk_{cat}.json")

if __name__ == "__main__":
    main()

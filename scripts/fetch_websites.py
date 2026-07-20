"""Fetch official websites (Wikidata P856) so a person can check hours themselves.

## Why this instead of opening hours

There is no usable source for opening hours. Measured, not assumed:

    Wikidata P3025 (opening hours)   703 designated sites worldwide   0.27%
    OpenStreetMap opening_hours      5% of heritage objects in both Bath and Split
    Any heritage register            nothing — registers record what a place IS

OSM is the only real candidate and it costs the ODbL obligation to publish our derived
database, in exchange for hours on one site in twenty. That is a bad trade and it settles
a question that had been deferred since the Brisbane research.

So the app will not claim to know when anywhere is open. What it can do is hand the reader
the official site in one tap, which is what they would go looking for anyway. Coverage is
thin — ~9% in the UK, ~6% in Croatia — but it is CC0, costs nothing, and never lies.
"""
import json, subprocess, sys, time

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

COUNTRIES = {
    "United Kingdom": "wd:Q145", "France": "wd:Q142", "Australia": "wd:Q408",
    "Croatia": "wd:Q224", "Italy": "wd:Q38", "Spain": "wd:Q29", "Greece": "wd:Q41",
    "United States": "wd:Q30",
}

def query(qid):
    return f"""
SELECT ?item ?w WHERE {{
  ?item wdt:P17 {qid} ; wdt:P1435 ?d ; wdt:P625 ?c ; wdt:P856 ?w .
}}"""

def run(q, label):
    for attempt in range(3):
        out = subprocess.run(
            ["curl", "-sS", "-G", "--max-time", "240", ENDPOINT,
             "--data-urlencode", f"query={q}",
             "-H", "Accept: application/sparql-results+json",
             "-H", f"User-Agent: {UA}"], capture_output=True, text=True)
        try:
            return json.loads(out.stdout)["results"]["bindings"]
        except Exception:
            sys.stderr.write(f"    ! {label} attempt {attempt + 1} failed\n")
            time.sleep(8)
    return None

sites = {}
for name, qid in COUNTRIES.items():
    rows = run(query(qid), name)
    if rows is None:
        sys.stderr.write(f"  ! {name}: GAVE UP\n")
        continue
    for b in rows:
        q = b["item"]["value"].rsplit("/", 1)[-1]
        sites.setdefault(q, b["w"]["value"])
    print(f"  {name:<16} {len(rows):>6} rows (total {len(sites)})", flush=True)

json.dump(sites, open(f"{SP}/websites.json", "w"))
print(f"\n{len(sites)} official websites -> websites.json")

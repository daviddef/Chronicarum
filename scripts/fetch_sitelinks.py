"""Fetch Wikipedia sitelink counts — the renown signal, used for ranking only.

## The reversal

Sitelink count is where this project started and it was the original mistake: the first
bulk import required **≥5 language editions**, which left Brisbane with 7 sites and
Dubrovnik with 1. Replacing it with heritage designation is what made the catalogue real.

It was the wrong *filter*. It is the right *ranker*.

Nothing about "how many Wikipedias describe this" tells you whether a place deserves to be
in a heritage catalogue — that is what a government register is for. But once every
designated place is in, sitelinks are an excellent measure of which of them a visitor has
heard of. Croatia, ranked by sitelinks: Plitvice Lakes 70, Diocletian's Palace 52, and
Bakarski Castle 0. That ordering is exactly right for choosing six places to see in a day,
and exactly wrong for choosing which 260,008 to hold.

Same number, opposite job. Using it for inclusion destroyed the catalogue; using it for
selection is what makes a day plan possible.

## Coverage

Only sites carrying a Wikidata QID — about 140k of 260k. The register-sourced rows (US
NRHP, Mérimée, South Australia) have no QID and score 0 here, so the significance model
must never treat a missing sitelink count as evidence of *un*importance. It contributes a
bonus or nothing, and per-register grades carry those sources instead.
"""
import json, subprocess, sys, time

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

COUNTRIES = {
    "United Kingdom": "wd:Q145", "United States": "wd:Q30", "France": "wd:Q142",
    "Australia": "wd:Q408", "Croatia": "wd:Q224", "Italy": "wd:Q38",
    "Spain": "wd:Q29", "Germany": "wd:Q183", "Greece": "wd:Q41",
}

def country_query(qid):
    return f"""
SELECT ?item ?n WHERE {{
  ?item wdt:P17 {qid} ; wdt:P625 ?c ; wikibase:sitelinks ?n .
  FILTER(?n > 1)
}}"""

# Anything designated, anywhere — catches the original global import.
GLOBAL_QUERY = """
SELECT ?item ?n WHERE {
  ?item wdt:P1435 ?d ; wdt:P625 ?c ; wikibase:sitelinks ?n .
  FILTER(?n > 1)
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

links = {}

for name, qid in COUNTRIES.items():
    rows = run(country_query(qid), name)
    if rows is None:
        sys.stderr.write(f"  ! {name}: GAVE UP\n")
        continue
    for b in rows:
        q = b["item"]["value"].rsplit("/", 1)[-1]
        links[q] = max(links.get(q, 0), int(b["n"]["value"]))
    print(f"  {name:<18} {len(rows):>7} items (total {len(links)})", flush=True)

rows = run(GLOBAL_QUERY, "global P1435")
if rows is not None:
    before = len(links)
    for b in rows:
        q = b["item"]["value"].rsplit("/", 1)[-1]
        links[q] = max(links.get(q, 0), int(b["n"]["value"]))
    print(f"  {'global (P1435)':<18} {len(rows):>7} items (+{len(links) - before} new)")

json.dump(links, open(f"{SP}/sitelinks.json", "w"))
print(f"\n{len(links)} items with sitelinks -> sitelinks.json")

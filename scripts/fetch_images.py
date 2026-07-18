"""Fetch Wikimedia Commons image filenames (Wikidata P18) for the bulk categories.

Selecting only item+image keeps the query light enough to run unbanded, unlike the main
site fetch. Output: images.json, a {QID: "File name.jpg"} map."""
import json, os, subprocess, sys, time, urllib.parse

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

CATS = [
    ("unesco",         "?item wdt:P1435 wd:Q9259 .",            False),
    ("castle",         "?item wdt:P31/wdt:P279* wd:Q23413 .",   True),
    ("museum",         "?item wdt:P31/wdt:P279* wd:Q33506 .",   True),
    ("monument",       "?item wdt:P31/wdt:P279* wd:Q4989906 .", True),
    ("archaeological", "?item wdt:P31/wdt:P279* wd:Q839954 .",  True),
]

def run(where, filtered):
    sl = "?item wikibase:sitelinks ?sl . FILTER(?sl >= 5)" if filtered else ""
    query = f"SELECT ?item ?image WHERE {{ {where} ?item wdt:P625 ?c ; wdt:P18 ?image . {sl} }}"
    for attempt in range(4):
        out = subprocess.run(
            ["curl", "-sS", "-G", "--max-time", "240", ENDPOINT,
             "--data-urlencode", f"query={query}",
             "-H", "Accept: application/sparql-results+json",
             "-H", f"User-Agent: {UA}"],
            capture_output=True, text=True)
        try:
            return json.loads(out.stdout)["results"]["bindings"]
        except Exception:
            sys.stderr.write(f"  ! attempt {attempt+1} failed\n")
            time.sleep(10)
    return None

images = {}
if os.path.exists(f"{SP}/images.json"):
    images = json.load(open(f"{SP}/images.json"))

for cat, where, filtered in CATS:
    rows = run(where, filtered)
    if rows is None:
        sys.stderr.write(f"  ! {cat}: GAVE UP — no images fetched for this category\n")
        continue
    added = 0
    for r in rows:
        qid = r["item"]["value"].rsplit("/", 1)[-1]
        if qid in images:
            continue
        # P18 arrives as a Commons URL; keep just the decoded filename.
        images[qid] = urllib.parse.unquote(r["image"]["value"].rsplit("/", 1)[-1])
        added += 1
    print(f"{cat}: {len(rows)} rows, +{added} new (total {len(images)})")

json.dump(images, open(f"{SP}/images.json", "w"), ensure_ascii=False)
print(f"\nimages.json: {len(images)} QIDs with a Commons image")

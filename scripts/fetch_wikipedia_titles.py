"""Map our sites to their English Wikipedia article titles.

## Why only titles

The longest-standing open item in the roadmap is that most sites carry a one-line
description or none — 160k of them. Wikipedia has real prose for a large share, and the
licensing was worked out during the Brisbane research:

  * Wikipedia text is **CC BY-SA 4.0**, satisfied by a hyperlink to the reused page.
  * But CC BY-SA 4.0 §2(a)(5)(B) has an anti-TPM clause, and Creative Commons' own wiki
    flags App Store distribution as a possible violation — while explicitly rejecting
    parallel distribution as a cure.

So the text is **fetched at runtime and never bundled**, which sidesteps the question
entirely and is how the official Wikipedia iOS app operates. What ships is the article
*title*, which comes from Wikidata and is CC0 — an identifier, not the work.

## Resolve by sitelink, never by name

`/page/summary/Maryborough_Post_Office` returns a **disambiguation page**. Title-matching
heritage names to Wikipedia hits this constantly, which is why the title comes from the
Wikidata sitelink rather than from our own name string.

Bounded per country: the unrestricted form times out.
"""
import json, subprocess, sys, time, urllib.parse

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

# Per designation for the big markets — a whole-country query over sitelinks times out.
SLICES = [
    ("UK Grade I",        "?item wdt:P1435 wd:Q15700818 ."),
    ("UK Grade II*",      "?item wdt:P1435 wd:Q15700831 ."),
    ("UK scheduled",      "?item wdt:P1435 wd:Q219538 ."),
    ("Scotland A",        "?item wdt:P1435 wd:Q10729054 ."),
    ("Scotland B",        "?item wdt:P1435 wd:Q10729125 ."),
    ("Australia",         "?item wdt:P17 wd:Q408 ; wdt:P1435 ?d ."),
    ("Croatia",           "?item wdt:P17 wd:Q224 ; wdt:P625 ?cc ."),
    ("Italy",             "?item wdt:P17 wd:Q38 ; wdt:P1435 ?d ."),
    ("Spain",             "?item wdt:P17 wd:Q29 ; wdt:P1435 ?d ."),
    ("France",            "?item wdt:P17 wd:Q142 ; wdt:P1435 ?d ."),
]

def query(where):
    return f"""
SELECT ?item ?title WHERE {{
  {where}
  ?item wdt:P625 ?c .
  ?a schema:about ?item ; schema:isPartOf <https://en.wikipedia.org/> ; schema:name ?title .
}}"""

def run(q, label):
    for attempt in range(3):
        out = subprocess.run(
            ["curl", "-sS", "-G", "--max-time", "300", ENDPOINT,
             "--data-urlencode", f"query={q}",
             "-H", "Accept: application/sparql-results+json",
             "-H", f"User-Agent: {UA}"], capture_output=True, text=True)
        try:
            return json.loads(out.stdout)["results"]["bindings"]
        except Exception:
            sys.stderr.write(f"    ! {label} attempt {attempt + 1} failed\n")
            time.sleep(8)
    return None

titles = {}
for label, where in SLICES:
    rows = run(query(where), label)
    if rows is None:
        sys.stderr.write(f"  ! {label}: GAVE UP\n")
        continue
    for b in rows:
        q = b["item"]["value"].rsplit("/", 1)[-1]
        titles.setdefault(q, b["title"]["value"])
    print(f"  {label:<16} {len(rows):>7} rows (total {len(titles)})", flush=True)

json.dump(titles, open(f"{SP}/wikipedia_titles.json", "w"), ensure_ascii=False)
print(f"\n{len(titles)} article titles -> wikipedia_titles.json")

"""Which catalogue sites are UNESCO World Heritage.

The bulk import kept `P1435` (heritage designation) as an inclusion test but never recorded
*which* designation, so the catalogue cannot currently tell a World Heritage Site from a
locally listed cottage except through its significance score. Collections need the
distinction to be exact rather than inferred: "World Heritage Sites of France" is a claim
about an official list, and a set that quietly includes something UNESCO never inscribed is
worthless as a collection.

`Q9259` is the World Heritage Site designation. CC0, like everything else from Wikidata.
"""
import json, subprocess, sys, time

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

QUERY = """
SELECT ?item WHERE {
  ?item wdt:P1435 wd:Q9259 ; wdt:P625 ?c .
}"""


def main():
    for attempt in range(4):
        out = subprocess.run(
            ["curl", "-sS", "-G", "--max-time", "300", ENDPOINT,
             "--data-urlencode", f"query={QUERY}",
             "-H", "Accept: application/sparql-results+json",
             "-H", f"User-Agent: {UA}"], capture_output=True, text=True)
        try:
            rows = json.loads(out.stdout)["results"]["bindings"]
            break
        except Exception:
            sys.stderr.write(f"  ! attempt {attempt + 1} failed\n")
            time.sleep(8)
    else:
        sys.exit("gave up fetching World Heritage designations")

    qids = sorted({b["item"]["value"].rsplit("/", 1)[-1] for b in rows})
    json.dump(qids, open(f"{SP}/world_heritage.json", "w"))
    print(f"{len(qids):,} World Heritage items with coordinates -> world_heritage.json")


if __name__ == "__main__":
    main()

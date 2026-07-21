"""Map Wikidata QIDs to their National Heritage List for England entry numbers.

The catalogue's UK rows are keyed by QID, because they came from Wikidata. Historic
England's footprints are keyed by NHLE list entry. `P1216` is the join between them, it is
exact, and — being a Wikidata statement — it is CC0.

The alternative was matching a footprint to a catalogue point by proximity and name, which
is precisely the approach that deleted Dover Castle during the dedup work. An identifier
that both sides already agree on is worth the extra query.
"""
import json, subprocess, sys, time

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
ENDPOINT = "https://query.wikidata.org/sparql"

QUERY = """
SELECT ?item ?ref WHERE {
  ?item wdt:P1216 ?ref ; wdt:P625 ?c .
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
        sys.exit("gave up fetching NHLE references")

    mapping = {}
    for b in rows:
        qid = b["item"]["value"].rsplit("/", 1)[-1]
        mapping[str(b["ref"]["value"])] = qid

    json.dump(mapping, open(f"{SP}/nhle_refs.json", "w"))
    print(f"{len(mapping):,} NHLE reference -> QID mappings -> nhle_refs.json")


if __name__ == "__main__":
    main()

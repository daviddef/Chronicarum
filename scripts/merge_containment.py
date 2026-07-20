"""Attach a parent site to every record Wikidata says is part of another.

Filters the raw `P361` pairs down to real physical containment and writes a `par` field
holding the parent's site id.

Three things the raw data needs protecting against:

  * **Non-containment relations.** `P361` covers class membership and administrative
    grouping as happily as physical nesting. A generic "stećak" is "part of" necropolises
    20, 55 and 67 km apart. Requiring the pair to be within 2 km removes every false pair
    observed while keeping cases as loose as Lokrum island → old city of Dubrovnik.

  * **Multiple parents.** Wikidata often records several. The *smallest* container is the
    useful one for planning — knowing the cathedral is in the old town is less actionable
    than knowing it is in the cathedral close — so the nearest parent wins.

  * **Cycles.** A and B can each claim to be part of the other, and a chain can loop.
    Anything that cannot resolve to a root within a few hops has its parent dropped rather
    than risking an infinite walk in the app.
"""
import json, math
from collections import Counter

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"

MAX_KM = 2.0        # generous; observed false pairs start at ~17 km
MAX_DEPTH = 6       # deep enough for gate -> palace -> complex, shallow enough to be safe


def km(a, b):
    k = math.cos(math.radians(a["lat"]))
    return math.hypot((a["lat"] - b["lat"]) * 111, (a["lon"] - b["lon"]) * 111 * k)


sites = json.load(open(BUNDLE))
by_id = {s["id"]: s for s in sites}
pairs = json.load(open(f"{SP}/containment.json"))

skipped = Counter()
candidates = {}          # child id -> (parent id, distance)

for child_qid, parent_qid in pairs:
    child_id, parent_id = "wd-" + child_qid, "wd-" + parent_qid
    if child_id == parent_id:
        skipped["self-reference"] += 1
        continue
    child, parent = by_id.get(child_id), by_id.get(parent_id)
    if child is None or parent is None:
        skipped["one end not in catalogue"] += 1
        continue

    distance = km(child, parent)
    if distance > MAX_KM:
        skipped["too far apart to be containment"] += 1
        continue

    # Smallest container wins — see module docstring.
    existing = candidates.get(child_id)
    if existing is None or distance < existing[1]:
        candidates[child_id] = (parent_id, distance)

# Drop anything whose parent chain does not terminate. Cheaper and safer than making the
# app defend itself against a cycle it can do nothing about.
def resolves(child_id):
    seen, current, hops = {child_id}, child_id, 0
    while True:
        entry = candidates.get(current)
        if entry is None:
            return True
        current = entry[0]
        hops += 1
        if current in seen or hops > MAX_DEPTH:
            return False
        seen.add(current)

for child_id in list(candidates):
    if not resolves(child_id):
        del candidates[child_id]
        skipped["cyclic or too deep"] += 1

for site in sites:
    site.pop("par", None)
entry_count = 0
for child_id, (parent_id, _) in candidates.items():
    by_id[child_id]["par"] = parent_id
    entry_count += 1

json.dump(sites, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

print(f"{len(pairs)} candidate relations -> {entry_count} contained sites")
for reason, n in skipped.most_common():
    print(f"  dropped {n:>6}  {reason}")

parents = Counter(p for p, _ in candidates.values())
print(f"\n  distinct containers: {len(parents)}")
print("  largest:")
for parent_id, n in parents.most_common(8):
    print(f"    {by_id[parent_id]['name'][:46]:<46} holds {n}")

folded = sum(by_id[c]["dur"] for c in candidates)
print(f"\n  visiting minutes now attributable to a parent rather than counted "
      f"separately: {folded} ({folded / 60:.0f} h)")

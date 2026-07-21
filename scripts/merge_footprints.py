"""Attach parents by geometry: a site standing inside a scheduled area is part of it.

`merge_containment.py` handles the explicit case — Wikidata `P361`, which is precise and
covers 0.9% of the catalogue. This covers a different slice: Historic England publishes the
actual mapped boundary of every scheduled monument, so any catalogue point falling inside
one is contained as a matter of surveyed fact rather than of someone having written the
statement down.

Scale, honestly: **1,188 new relations.** That is small against 294,820 sites, and it is
the ceiling rather than a first pass — see `fetch_footprints_uk.py` for why listed-building
polygons cannot contribute (97% of them are 2.5 m placeholder triangles). Geometric
containment turns out to be a scheduled-monument feature, so it finds precincts, forts,
abbey grounds and dockyards, and never the terraced street.

## The direction problem this exposed

The obvious reading of containment — the parent is the visit, the children are things you
see while you are there — is true for a Georgian terrace holding 39 listed houses and
**false** for most scheduled areas:

    Fulham Palace moated site  (significance 20)  contains  Fulham Palace       (65)
    Portsmouth Dockyard docks  (significance 23)  contains  HMS Victory         (56)
                                                            Mary Rose           (43)

A scheduled monument is frequently an archaeological designation drawn around something,
not a destination in itself. Suppressing the child there would delete the best thing in
Portsmouth in favour of a dockyard wall. The fix is not in this script — the relation is
real either way — but in how the planner reads it: it now drops whichever end of a
contained pair is *worth less*, rather than always the child. Both ships survive; the
scheduled basin does not.

## Licence

Historic England data under **Open Government Licence v3.0**, geometry derived from
Ordnance Survey MasterMap. Only the derived parent-child relations ship, never the
polygons — but the credit is still owed, so it is recorded in `DataSource`.
"""
import json
from collections import defaultdict, Counter

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"

CELL = 0.01     # ~1.1 km grid; every scheduled area is far smaller


def point_in_rings(rings, lon, lat):
    """Ray-cast against any outer ring."""
    for ring in rings:
        inside = False
        n = len(ring)
        j = n - 1
        for i in range(n):
            xi, yi = ring[i][0], ring[i][1]
            xj, yj = ring[j][0], ring[j][1]
            if (yi > lat) != (yj > lat) and lon < (xj - xi) * (lat - yi) / (yj - yi) + xi:
                inside = not inside
            j = i
        if inside:
            return True
    return False


def area_of(rings):
    """Shoelace area in square degrees — only ever compared against another, so the unit
    does not matter. Used to pick the smallest containing area when several overlap."""
    total = 0.0
    for ring in rings:
        s = 0.0
        for i in range(len(ring)):
            x1, y1 = ring[i]
            x2, y2 = ring[(i + 1) % len(ring)]
            s += x1 * y2 - x2 * y1
        total += abs(s) / 2
    return total


def main():
    sites = json.load(open(BUNDLE))
    footprints = json.load(open(f"{SP}/footprints_uk.json"))
    refs = json.load(open(f"{SP}/nhle_refs.json"))
    by_id = {s["id"]: s for s in sites}

    grid = defaultdict(list)
    for s in sites:
        grid[(int(s["lat"] / CELL), int(s["lon"] / CELL))].append(s)

    skipped = Counter()
    # child id -> (parent id, area) so the smallest containing area wins
    candidates = {}

    for f in footprints:
        qid = refs.get(f["ref"])
        if qid is None:
            skipped["monument has no Wikidata QID"] += 1
            continue
        parent_id = "wd-" + qid
        if parent_id not in by_id:
            skipped["monument not in catalogue"] += 1
            continue

        rings = f["rings"]
        xs = [p[0] for r in rings for p in r]
        ys = [p[1] for r in rings for p in r]
        lo, hi, wlo, whi = min(ys), max(ys), min(xs), max(xs)
        area = area_of(rings)

        for gy in range(int(lo / CELL), int(hi / CELL) + 1):
            for gx in range(int(wlo / CELL), int(whi / CELL) + 1):
                for s in grid[(gy, gx)]:
                    if s["id"] == parent_id:
                        continue
                    if not (lo <= s["lat"] <= hi and wlo <= s["lon"] <= whi):
                        continue
                    if not point_in_rings(rings, s["lon"], s["lat"]):
                        continue
                    existing = candidates.get(s["id"])
                    if existing is None or area < existing[1]:
                        candidates[s["id"]] = (parent_id, area)

    # An explicit P361 statement beats a geometric inference: someone asserted it.
    kept = 0
    for child_id, (parent_id, _) in candidates.items():
        if by_id[child_id].get("par"):
            skipped["already had an explicit P361 parent"] += 1
            continue
        by_id[child_id]["par"] = parent_id
        kept += 1

    json.dump(sites, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

    print(f"{len(footprints):,} footprints -> {len(candidates):,} points inside one")
    print(f"  {kept:,} new geometric containment relations written")
    for reason, n in skipped.most_common():
        print(f"  skipped {n:>6}  {reason}")

    total = sum(1 for s in sites if s.get("par"))
    print(f"\n  sites with a parent, all sources: {total:,}")

    parents = Counter(p for p, _ in candidates.values())
    print("  largest new containers:")
    for parent_id, n in parents.most_common(8):
        print(f"    {by_id[parent_id]['name'][:46]:<46} holds {n}")


if __name__ == "__main__":
    main()

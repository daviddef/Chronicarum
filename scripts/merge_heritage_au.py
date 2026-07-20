"""Merge the Australia-wide heritage import into the bundled catalogue."""
import json, re
from collections import Counter

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"
CURATED = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Models/SiteData.swift"

KIND_RULES = [
    (("cathedral", "church", "chapel", "basilica", "mosque", "synagogue", "temple",
      "monastery", "convent"), "sacred"),
    (("art museum", "museum", "gallery"), "museum"),
    (("war memorial", "memorial", "monument", "statue", "obelisk", "fountain"), "monument"),
    (("castle", "fort", "fortification", "barracks", "battery"), "castle"),
    (("archaeological", "ruin"), "ruin"),
    (("botanical garden", "national park", "nature reserve", "park", "garden",
      "reserve", "wetland"), "natural"),
    (("cemetery", "graveyard"), "heritage"),
    (("lighthouse", "bridge", "tower", "clock"), "monument"),
]

def site_type(kind):
    k = (kind or "").lower()
    for needles, mapped in KIND_RULES:
        if any(n in k for n in needles):
            return mapped
    return "heritage"

def era_from_inception(iso):
    if not iso:
        return "unknown"
    m = re.match(r"(-?)(\d+)-", iso)
    if not m:
        return "unknown"
    year = int(m.group(2)) * (-1 if m.group(1) == "-" else 1)
    if year < -500:  return "ancient"
    if year < 500:   return "classical"
    if year < 1400:  return "medieval"
    if year < 1750:  return "renaissance"
    return "modern"

def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())

def location_for(r):
    """'Brisbane City, Australia' reads better than a bare 'Australia' in a list of
    10k Australian places. Falls back when P131 is missing."""
    admin = (r.get("admin") or "").strip()
    return f"{admin}, Australia" if admin else "Australia"

bundle = json.load(open(BUNDLE))
by_id = {s["id"]: s for s in bundle}

src = open(CURATED).read()
cur_names = {norm(m) for m in re.findall(r'name: "([^"]+)"', src)}
cur_points = list(zip((float(x) for x in re.findall(r"latitude: (-?[\d.]+)", src)),
                      (float(x) for x in re.findall(r"longitude: (-?[\d.]+)", src))))

def collides_curated(r):
    """Only a genuine duplicate of a curated site, not merely a neighbour.

    A 0.01 degree (~1.1km) radius was the first attempt and it was far too blunt: it
    silently deleted 173 real heritage places, including Customs House, Cadmans Cottage
    and the Garrison Church, purely for standing near the Sydney Opera House. Exactly
    3 were actual duplicates. Name match does the real work; the tight radius (~55m)
    only catches the same place recorded under a slightly different name."""
    if norm(r["name"]) in cur_names:
        return True
    return any(abs(r["lat"] - la) < 0.0005 and abs(r["lon"] - lo) < 0.0005
               for la, lo in cur_points)

heritage = json.load(open(f"{SP}/heritage_au.json"))
added = enriched = skipped_curated = 0

for r in heritage:
    sid = "wd-" + r["qid"]

    if sid in by_id:
        # Already present — from the earlier Brisbane pass or the original bulk import.
        # Backfill the better location line rather than leaving a bare country.
        existing = by_id[sid]
        loc = location_for(r)
        if loc != "Australia" and existing.get("country") in (None, "", "Australia"):
            existing["country"] = loc
            enriched += 1
        continue

    if collides_curated(r):
        skipped_curated += 1
        continue

    row = {
        "id": sid,
        "name": r["name"],
        "lat": r["lat"],
        "lon": r["lon"],
        "type": site_type(r.get("kind")),
        "era": era_from_inception(r.get("inception")),
        "country": location_for(r),
        "desc": (r.get("desc") or "").strip(),
    }
    if r.get("img"):
        row["img"] = r["img"]
    bundle.append(row)
    by_id[sid] = row
    added += 1

bundle.sort(key=lambda s: s["id"])
json.dump(bundle, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

print(f"added {added} new, enriched {enriched} existing with a locality, "
      f"{skipped_curated} skipped as curated duplicates")
print(f"bundle now: {len(bundle)} bulk sites")
print("  new by type:", dict(Counter(site_type(r.get('kind')) for r in heritage).most_common()))
print(f"  file size: {len(open(BUNDLE).read())//1024} KB")

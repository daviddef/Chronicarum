"""Merge the heritage-designation pilot into the bundled catalogue.

Keyed on QID so it dedupes cleanly against the existing bulk import (whose ids are
"wd-<QID>"), and skips anything already covered by a curated site.
"""
import json, re

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"
CURATED = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Models/SiteData.swift"

# P31 "instance of" label → our SiteType. Matched as substrings, most specific first;
# anything unmatched falls through to the generic heritage bucket, which is honest —
# "historic site" is exactly what 342 of these are.
KIND_RULES = [
    (("cathedral", "church", "chapel", "basilica", "mosque", "synagogue", "temple",
      "monastery", "convent"), "sacred"),
    (("art museum", "museum", "gallery"), "museum"),
    (("war memorial", "memorial", "monument", "statue", "obelisk", "fountain"), "monument"),
    (("castle", "fort", "fortification", "barracks", "battery"), "castle"),
    (("archaeological", "ruin"), "ruin"),
    (("botanical garden", "national park", "nature reserve", "park", "garden",
      "reserve"), "natural"),
    (("cemetery", "graveyard"), "heritage"),   # kept generic; also caught by isSensitive
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

bundle = json.load(open(BUNDLE))
existing_ids = {s["id"] for s in bundle}

# Curated names/coords, so a heritage row doesn't duplicate a hand-authored site.
src = open(CURATED).read()
cur_names = {norm(m) for m in re.findall(r'name: "([^"]+)"', src)}
cur_points = [(float(a), float(b)) for a, b in
              zip(re.findall(r"latitude: (-?[\d.]+)", src),
                  re.findall(r"longitude: (-?[\d.]+)", src))]

def collides_curated(r):
    if norm(r["name"]) in cur_names:
        return True
    return any(abs(r["lat"] - la) < 0.01 and abs(r["lon"] - lo) < 0.01
               for la, lo in cur_points)

heritage = json.load(open(f"{SP}/heritage_brisbane.json"))
added, skipped_dupe, skipped_curated = 0, 0, 0

for r in heritage:
    sid = "wd-" + r["qid"]
    if sid in existing_ids:
        skipped_dupe += 1
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
        "country": "Australia",
        "desc": (r.get("desc") or "").strip(),
    }
    if r.get("img"):
        row["img"] = r["img"]
    bundle.append(row)
    existing_ids.add(sid)
    added += 1

bundle.sort(key=lambda s: s["id"])
json.dump(bundle, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

from collections import Counter
print(f"added {added} heritage places "
      f"({skipped_dupe} already present, {skipped_curated} duplicate a curated site)")
print(f"bundle now: {len(bundle)} bulk sites")
print("  new by type:", dict(Counter(site_type(r.get('kind')) for r in heritage)))
print(f"  file size: {len(open(BUNDLE).read())//1024} KB")

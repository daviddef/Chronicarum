"""Merge the UK heritage import into the bundled catalogue.

Wikidata is CC0, so unlike the South Australian register this owes no attribution and the
rows carry no `src`.

The dedup rule is the one arrived at the hard way in `merge_heritage_sa.py`: a name only
counts as evidence of duplication when the two places are also close together. UK heritage
names are formulaic to the point of parody — there are hundreds of "The Old Rectory" and
"Church of St Mary" — so a global name match here would be catastrophic rather than merely
bad.
"""
import json, re, unicodedata
from collections import Counter

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"
CURATED = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Models/SiteData.swift"

KIND_RULES = [
    (("cathedral", "church", "chapel", "abbey", "priory", "minster", "basilica", "mosque",
      "synagogue", "temple", "monastery", "convent", "friary"), "sacred"),
    (("art museum", "museum", "gallery"), "museum"),
    (("castle", "fort", "fortification", "barracks", "citadel", "keep", "tower house",
      "martello"), "castle"),
    (("archaeological", "ruin", "hillfort", "barrow", "cairn", "henge", "tumulus",
      "stone circle", "roman"), "ruin"),
    (("war memorial", "memorial", "monument", "statue", "obelisk", "fountain", "cross"),
     "monument"),
    (("botanical garden", "national park", "nature reserve", "park", "garden", "reserve",
      "wetland"), "natural"),
    (("lighthouse", "bridge", "tower", "clock", "windmill", "watermill"), "monument"),
    (("country house", "manor", "palace", "hall", "stately"), "heritage"),
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
    s = unicodedata.normalize("NFKD", s)
    return re.sub(r"[^a-z0-9]", "", s.lower())

def location_for(r):
    """"Bath, United Kingdom" beats a bare country in a list of 100k UK places."""
    admin = (r.get("admin") or "").strip()
    return f"{admin}, United Kingdom" if admin else "United Kingdom"

bundle = json.load(open(BUNDLE))
by_id = {s["id"]: s for s in bundle}

# Curated sites are hand-authored and win any collision.
src = open(CURATED).read()
cur_names = {norm(m) for m in re.findall(r'name: "([^"]+)"', src)}
cur_points = list(zip((float(x) for x in re.findall(r"latitude: (-?[\d.]+)", src)),
                      (float(x) for x in re.findall(r"longitude: (-?[\d.]+)", src))))

# Proximity ALONE is not evidence of duplication here, and assuming it was cost 25,658
# real places on the first run: Dover Castle deleted by the Roman fort beneath it,
# Canterbury Cathedral by St Augustine's Abbey, Bath Assembly Rooms by the Fashion Museum
# housed inside it, the Jewel House by the White Tower. The 55 m rule that was right for
# Australia is wrong for Britain for one reason — density. A UK high street has a dozen
# separately listed buildings within 55 m of each other, and they are genuinely different
# places you can go and see.
#
# So the only signal kept is name + proximity, at a radius tight enough that two places
# sharing a name really are one place. Every row already carries a QID, and identity by
# QID is exact, which is what dedup is actually for. Some true duplicates will survive
# this. That is the correct trade: a duplicate is visible and can be fixed later, a
# deletion is invisible and cannot.
NEAR_DEG = 0.0025      # ~250 m — same name this close is the same building

def cell(lat, lon):
    return (int(lat / NEAR_DEG), int(lon / NEAR_DEG))

grid = {}
for s in bundle:
    grid.setdefault(cell(s["lat"], s["lon"]), []).append(s)

def duplicate_of(name, lat, lon):
    n = norm(name)
    cy, cx = cell(lat, lon)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            for s in grid.get((cy + dy, cx + dx), ()):
                if (abs(s["lat"] - lat) < NEAR_DEG and abs(s["lon"] - lon) < NEAR_DEG
                        and norm(s["name"]) == n):
                    return True
    return False

def collides_curated(r):
    if norm(r["name"]) in cur_names:
        return True
    return any(abs(r["lat"] - la) < 0.0005 and abs(r["lon"] - lo) < 0.0005
               for la, lo in cur_points)

heritage = json.load(open(f"{SP}/heritage_uk.json"))
added = enriched = 0
skipped = Counter()

for r in heritage:
    sid = "wd-" + r["qid"]

    if sid in by_id:
        # Already present from the original ~24k sitelink-based import. Backfill the
        # better location line rather than leaving a bare "United Kingdom".
        existing = by_id[sid]
        loc = location_for(r)
        if loc != "United Kingdom" and existing.get("country") in (None, "", "United Kingdom"):
            existing["country"] = loc
            enriched += 1
        skipped["already in catalogue"] += 1
        continue

    if collides_curated(r):
        skipped["duplicates a curated site"] += 1
        continue
    if duplicate_of(r["name"], r["lat"], r["lon"]):
        skipped["duplicate of a nearby site"] += 1
        continue

    row = {
        "id": sid,
        "name": r["name"],
        "lat": r["lat"],
        "lon": r["lon"],
        "type": site_type(r.get("kind")),
        "era": era_from_inception(r.get("inception")),
        "country": location_for(r),
        "desc": "",           # Wikidata descriptions were not fetched; the grade is the
                              # useful line here and it lives in the type/era already.
    }
    if r.get("img"):
        row["img"] = r["img"]
    bundle.append(row)
    by_id[sid] = row
    grid.setdefault(cell(r["lat"], r["lon"]), []).append(row)
    added += 1

bundle.sort(key=lambda s: s["id"])
json.dump(bundle, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

print(f"added {added} UK heritage places, enriched {enriched} existing with a locality")
for reason, n in skipped.most_common():
    print(f"  skipped {n:>6}  {reason}")
print(f"\nbundle now: {len(bundle)} bulk sites, {len(open(BUNDLE).read()) // 1024} KB")
print("  new by grade:", dict(Counter(r.get("grade") for r in heritage).most_common()))
print("  new by type: ", dict(Counter(site_type(r.get("kind")) for r in heritage).most_common()))

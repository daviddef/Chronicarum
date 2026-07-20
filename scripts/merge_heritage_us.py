"""Merge the US National Register into the bundled catalogue.

NRHP is public domain (17 U.S.C. §105), so nothing is owed. The NPS is credited anyway
via `DataSource.nrhp` — it costs one line and the register did the work.

The register itself ships neither descriptions nor images; both arrive from the Wikidata
join on P649 built by `fetch_heritage_us.py`.
"""
import json, re, unicodedata
from collections import Counter

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"
CURATED = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Models/SiteData.swift"

# The register's own ResType is coarse (building/site/structure/object/district), so the
# name carries most of the signal. Checked against the name, most specific first.
NAME_RULES = [
    (("cathedral", "church", "chapel", "synagogue", "temple", "mosque", "meetinghouse",
      "meeting house", "friends meeting", "abbey", "monastery", "convent", "mission"),
     "sacred"),
    (("museum", "gallery"), "museum"),
    (("fort ", "fort-", "fortification", "armory", "arsenal", "battery", "presidio",
      "castle", "blockhouse", "garrison"), "castle"),
    (("archeological", "archaeological", "mound", "petroglyph", "pueblo", "cliff dwelling",
      "ruins", "earthworks", "village site"), "ruin"),
    (("monument", "memorial", "statue", "obelisk", "fountain", "bridge", "lighthouse",
      "light station", "windmill", "watermill", "tower"), "monument"),
    (("park", "garden", "arboretum", "preserve", "refuge", "forest"), "natural"),
]

def site_type(name, restype):
    n = (name or "").lower()
    for needles, mapped in NAME_RULES:
        if any(needle in n for needle in needles):
            return mapped
    # "site" in the register usually means an archaeological or landscape site rather than
    # a standing building, which is the closest thing it has to a ruin.
    if restype == "site":
        return "ruin"
    return "heritage"

def era_from_inception(iso):
    """Only from the Wikidata join. `CertDate` in the register is the LISTING date — using
    it would date every American site to the twentieth century."""
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

# Wikidata's description is sometimes just a restatement of the listing itself — "place in
# Michigan listed on National Register of Historic Places" — which tells a reader nothing
# they cannot see from the pin. 1,783 rows read like this, and 1,782 of them have a street
# address, which is more use to someone trying to find the place.
CIRCULAR = re.compile(r"listed on (the )?national register|national register of historic"
                      r" places|nrhp[- ]listed", re.I)

def norm(s):
    s = unicodedata.normalize("NFKD", s)
    return re.sub(r"[^a-z0-9]", "", s.lower())

def title_case(s):
    """The register shouts its states: WASHINGTON, NEW YORK."""
    return s.title() if s.isupper() else s

records = json.load(open(f"{SP}/heritage_us.json"))
wikidata = json.load(open(f"{SP}/nrhp_wd_map.json"))
bundle = json.load(open(BUNDLE))
existing_ids = {s["id"] for s in bundle}

src = open(CURATED).read()
cur_names = {norm(m) for m in re.findall(r'name: "([^"]+)"', src)}
cur_points = list(zip((float(x) for x in re.findall(r"latitude: (-?[\d.]+)", src)),
                      (float(x) for x in re.findall(r"longitude: (-?[\d.]+)", src))))

# Name within ~250 m, never position alone, and never the source against itself — the two
# rules that took three failures to arrive at. See merge_heritage_uk.py and
# merge_heritage_fr.py. NRIS_Refnum is already unique, so within-source checks can only
# produce false positives.
NEAR_DEG = 0.0025

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

# Names repeat heavily across states — 400-odd "Old Stone House", every county with its
# "Masonic Temple". Qualifying a repeated name with its city makes the row identifiable.
name_counts = Counter(r["name"] for r in records)

def description(wikidata_desc, address):
    if wikidata_desc and not CIRCULAR.search(wikidata_desc):
        return wikidata_desc
    return address or wikidata_desc or ""

rows, skipped = [], Counter()

for r in records:
    name, lat, lon = r["name"], r["lat"], r["lon"]
    if not name:
        skipped["no name"] += 1
        continue

    # 24 listings are recorded as demolished. A pin for a building that is gone sends
    # someone to an empty lot.
    if r.get("extant") == "False":
        skipped["no longer extant"] += 1
        continue

    # The service returns a handful of rows at (0, 0).
    if abs(lat) < 0.01 and abs(lon) < 0.01:
        skipped["null-island coordinates"] += 1
        continue

    city = title_case(r.get("city") or "")
    if name_counts[name] > 1 and city:
        name = f"{name}, {city}"

    sid = "nrhp-" + r["ref"]
    if sid in existing_ids:
        skipped["already in catalogue"] += 1
        continue
    if norm(name) in cur_names or any(
            abs(lat - la) < 0.0005 and abs(lon - lo) < 0.0005 for la, lo in cur_points):
        skipped["duplicates a curated site"] += 1
        continue
    if duplicate_of(name, lat, lon):
        skipped["duplicate of a site already in the catalogue"] += 1
        continue

    extra = wikidata.get(r["ref"], {})
    state = title_case(r.get("state") or "")
    location = ", ".join(x for x in (city, state) if x) or "United States"

    row = {
        "id": sid,
        "name": name,
        "lat": lat,
        "lon": lon,
        "type": site_type(r["name"], r.get("restype")),
        "era": era_from_inception(extra.get("inception")),
        "country": f"{location}, USA" if location != "United States" else location,
        # Wikidata's one-liner where it says something, else the street address.
        "desc": description(extra.get("desc"), r.get("address")),
        "src": "nrhp",
    }
    if extra.get("img"):
        row["img"] = extra["img"]

    bundle.append(row)
    existing_ids.add(sid)
    rows.append(row)

bundle.sort(key=lambda s: s["id"])
json.dump(bundle, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

print(f"added {len(rows)} US National Register listings")
for reason, n in skipped.most_common():
    print(f"  skipped {n:>6}  {reason}")
photos = sum(1 for r in rows if r.get("img"))
descs = sum(1 for r in rows if r["desc"])
print(f"\n  with photo:       {photos} ({photos * 100 // max(len(rows), 1)}%)")
print(f"  with description: {descs} ({descs * 100 // max(len(rows), 1)}%)")
print(f"  by type: {dict(Counter(r['type'] for r in rows).most_common())}")
print(f"  by era:  {dict(Counter(r['era'] for r in rows).most_common())}")
print(f"\nbundle now: {len(bundle)} bulk sites, {len(open(BUNDLE).read()) // 1024} KB")

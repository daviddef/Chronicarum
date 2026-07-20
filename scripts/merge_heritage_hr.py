"""Import Croatian heritage from Wikidata — and NOT from the national register.

## Why not the register

Croatia keeps an excellent register. The Ministry of Culture's Geoportal
(geoportal.kulturnadobra.hr) publishes a real INSPIRE WFS with GeoJSON output and 7,302
protected cultural goods carrying names, dating, architect, prose descriptions and image
paths — roughly seven times what Wikidata holds, and better structured than Mérimée.

It cannot be used. Its terms of use (api/app/get-terms-of-use/cro) state:

    "Podaci ... isključivo su informativnog karaktera i služe za osobnu uporabu, te se ne
     smiju koristiti u komercijalne svrhe niti distribuirati trećoj strani."

    "Zabranjeno je svako mijenjanje, umnožavanje, distribuiranje podataka, na bilo kojoj
     vrsti medija ..."

Personal use only; no commercial use; no distribution to third parties; no reproduction on
any medium. Photographs additionally require a signed agreement with each author. Bundling
those records into a shipped app is distribution on media however the app is priced, so
the register was inspected to establish the licence and then left alone.

This is worth stating loudly because the data is *right there* and technically trivial to
take. Getting a licence wrong quietly is how a project acquires a liability it cannot see.
If Croatia matters commercially, the route is an agreement with the Ministry, not a
crawler.

## What this uses instead

Wikidata, which is CC0 and owes nothing: every Croatian item with coordinates, filtered to
classes a traveller would actually go to. That is far thinner than the register — hundreds
rather than thousands in the interior — but it is honestly ours to ship.
"""
import json, re, unicodedata, urllib.parse
from collections import Counter

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"
CURATED = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Models/SiteData.swift"

# A positive allowlist, not an exclusion list. Excluding known-bad classes let hostels,
# hotels, neighbourhoods and squares through on the first pass; naming what belongs is the
# safer direction when the failure mode is admitting somewhere nobody would travel to see.
CLASS_TYPES = {
    "sacred": {"church building", "church", "chapel", "cathedral", "basilica", "monastery",
               "convent", "abbey", "friary", "mosque", "synagogue", "shrine", "hermitage",
               "parish church", "collegiate church", "sanctuary"},
    "castle": {"castle", "castle ruin", "fortress", "fortification", "citadel", "tower house",
               "defensive tower", "city walls", "bastion", "fort", "watchtower"},
    "ruin": {"archaeological site", "ruins", "Roman villa", "hillfort", "amphitheatre",
             "Roman amphitheatre", "Roman theatre", "necropolis", "tumulus", "megalith",
             "ancient city", "archaeological find"},
    "museum": {"museum", "art museum", "gallery", "art gallery", "open-air museum",
               "archaeological museum", "historic house museum"},
    "monument": {"monument", "memorial", "war memorial", "statue", "obelisk", "fountain",
                 "bridge", "lighthouse", "clock tower", "bell tower", "campanile", "column",
                 "windmill", "watermill", "city gate", "triumphal arch"},
    "natural": {"national park", "nature park", "nature reserve", "botanical garden",
                "protected area", "park"},
    "heritage": {"cultural property", "palace", "manor house", "villa", "historic building",
                 "cultural heritage ensemble", "old town", "historic centre", "granary",
                 "caravanserai", "theatre", "opera house", "library", "town hall",
                 "market hall", "baths", "thermae", "aqueduct", "cistern", "mausoleum"},
}
CLASS_TO_TYPE = {name: t for t, names in CLASS_TYPES.items() for name in names}

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

# ── Collapse the SPARQL rows (one per class/admin combination) into items ──────────────
rows_in = json.load(open(f"{SP}/hr_wd.json"))["results"]["bindings"]
items = {}
for b in rows_in:
    qid = b["item"]["value"].rsplit("/", 1)[-1]
    e = items.setdefault(qid, {"kinds": set(), "designated": False})
    e["name"] = b["lab"]["value"]
    e["lat"] = round(float(b["lat"]["value"]), 5)
    e["lon"] = round(float(b["lon"]["value"]), 5)
    if "kindLabel" in b:
        e["kinds"].add(b["kindLabel"]["value"])
    if "desig" in b:
        e["designated"] = True
    if "img" in b and "img" not in e:
        e["img"] = urllib.parse.unquote(b["img"]["value"].rsplit("/", 1)[-1])
    if "inception" in b and "inception" not in e:
        e["inception"] = b["inception"]["value"]
    if "adminLabel" in b and "admin" not in e:
        e["admin"] = b["adminLabel"]["value"]

bundle = json.load(open(BUNDLE))
existing_ids = {s["id"] for s in bundle}

src = open(CURATED).read()
cur_names = {norm(m) for m in re.findall(r'name: "([^"]+)"', src)}
cur_points = list(zip((float(x) for x in re.findall(r"latitude: (-?[\d.]+)", src)),
                      (float(x) for x in re.findall(r"longitude: (-?[\d.]+)", src))))

NEAR_DEG = 0.0025          # name within ~250 m, never position alone

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

rows, skipped = [], Counter()

for qid, e in items.items():
    matched = [CLASS_TO_TYPE[k] for k in e["kinds"] if k in CLASS_TO_TYPE]
    # A heritage designation alone earns a place even if the class is unrecognised —
    # P1435 is the signal this whole approach is built on.
    if not matched and not e["designated"]:
        skipped["not a heritage class"] += 1
        continue

    sid = "wd-" + qid
    if sid in existing_ids:
        skipped["already in catalogue"] += 1
        continue

    name, lat, lon = e["name"], e["lat"], e["lon"]
    if norm(name) in cur_names or any(
            abs(lat - la) < 0.0005 and abs(lon - lo) < 0.0005 for la, lo in cur_points):
        skipped["duplicates a curated site"] += 1
        continue
    if duplicate_of(name, lat, lon):
        skipped["duplicate of a nearby site"] += 1
        continue

    admin = (e.get("admin") or "").strip()
    row = {
        "id": sid,
        "name": name,
        "lat": lat,
        "lon": lon,
        "type": Counter(matched).most_common(1)[0][0] if matched else "heritage",
        "era": era_from_inception(e.get("inception")),
        "country": f"{admin}, Croatia" if admin else "Croatia",
        # Wikidata descriptions were not fetched for Croatia; the class is the useful
        # line and it is already carried by `type`.
        "desc": "",
    }
    if e.get("img"):
        row["img"] = e["img"]

    bundle.append(row)
    existing_ids.add(sid)
    rows.append(row)

bundle.sort(key=lambda s: s["id"])
json.dump(bundle, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

print(f"added {len(rows)} Croatian heritage sites (Wikidata, CC0)")
for reason, n in skipped.most_common():
    print(f"  skipped {n:>6}  {reason}")
photos = sum(1 for r in rows if r.get("img"))
print(f"\n  with photo: {photos} ({photos * 100 // max(len(rows), 1)}%)")
print(f"  by type: {dict(Counter(r['type'] for r in rows).most_common())}")
print(f"  by era:  {dict(Counter(r['era'] for r in rows).most_common())}")
print(f"\nbundle now: {len(bundle)} bulk sites, {len(open(BUNDLE).read()) // 1024} KB")

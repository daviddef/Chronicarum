"""Fill the South Australian gap from the state register directly.

Wikidata carries only 113 SA Heritage Register places against a real register of a few
thousand, which is why Adelaide showed 75 sites when Perth showed 921. Wikidata coverage
is a volunteer artefact and South Australia simply has not been worked on. The register
itself is published openly, so take it from the source.

Source:  data.sa.gov.au "SA Heritage Places", SAHeritagePlacesPoints_GDA2020.geojson
Licence: CC BY 3.0 AU  — attribution is required, and is rendered on each imported
         site by `DataSource.saHeritageRegister` (see Models/Site.swift). The `src`
         field written below is what carries that link through to the app.

The dataset is three different things stacked together and only the first two belong in a
travel app:

    State         3,280   the SA Heritage Register proper — named, specific destinations
    Local         8,650   council listings; mostly bare "House" / "Attached Houses"
    Contributory 12,549   streetscape filler, most with no description at all

Importing all 24,479 would drop pins on ~21,000 private homes and tell people to go look
at them. That is worse than the thin catalogue it fixes: useless to a visitor, and an
intrusion on residents who listed their house on a planning register, not a tourist map.
So: all of State, the public-facing subset of Local, none of Contributory.
"""
import json, re, unicodedata
from collections import Counter

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
SRC = f"{SP}/sa/SAHeritagePlacesPoints_GDA2020.geojson"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"

# A Local listing earns a place only if it reads as somewhere the public can go. This is a
# positive allowlist rather than a residential blocklist on purpose: the failure we care
# about is admitting a private home, so anything unrecognised is excluded.
PUBLIC = re.compile(r"""\b(church|chapel|cathedral|manse|convent|monastery|mosque|synagogue
    |school|college|university|institute|hall|library|museum|gallery|theatre|cinema
    |hotel|inn|tavern|brewery|winery|distillery|bank|post\ ?office|court|gaol|jail|police
    |fire\ ?station|railway|station|bridge|lighthouse|jetty|wharf|mill|smithy|forge|factory
    |silo|memorial|monument|obelisk|fountain|statue|cemetery|gardens?|park|reserve
    |homestead|woolshed|store|market|hospital|asylum|observatory|windmill|pumping
    |reservoir|town\ ?hall|council|club|lodge|masonic)\b""", re.I | re.X)

TYPE_RULES = [
    (("church", "chapel", "cathedral", "manse", "convent", "monastery", "mosque",
      "synagogue"), "sacred"),
    (("museum", "gallery"), "museum"),
    (("memorial", "monument", "obelisk", "fountain", "statue", "bridge", "lighthouse"),
     "monument"),
    (("gaol", "jail", "fort", "barracks"), "castle"),
    (("gardens", "park", "reserve"), "natural"),
]

def site_type(text):
    t = text.lower()
    for needles, mapped in TYPE_RULES:
        if any(n in t for n in needles):
            return mapped
    return "heritage"

def title_case(s):
    """The register shouts its suburbs — ADELAIDE, PORT AUGUSTA. Only fix the all-caps
    ones; anything already mixed-case was written deliberately."""
    return s.title() if s.isupper() else s

def display_name(details):
    """`details` is a description, not a name: "House - 'Dimora', front fence and gates
    and southern boundary wall". Prefer a quoted name, else cut at the first clause
    boundary so the map label stays legible."""
    quoted = re.search(r"['‘’\"]([^'‘’\"]{3,60})['‘’\"]", details)
    if quoted:
        return quoted.group(1).strip()
    head = re.split(r",| including | comprising | consisting ", details, maxsplit=1)[0]
    head = head.strip(" -–—.")
    return head if 3 <= len(head) <= 70 else details[:70].strip(" -–—.")

def norm(s):
    s = unicodedata.normalize("NFKD", s)
    return re.sub(r"[^a-z0-9]", "", s.lower())

features = json.load(open(SRC))["features"]
bundle = json.load(open(BUNDLE))

# Dedup against what Wikidata already gave us. SA rows there are sparse but real, and a
# duplicate Adelaide Town Hall is more visible than a missing one.
#
# A name match ONLY counts when the two places are also near each other. Matching names
# globally looks reasonable and is badly wrong: heritage names are formulaic, so a first
# pass killed 2,599 genuine SA places — St John's Anglican Church deleted because
# Fremantle has one, and 1,300-odd "Dwelling"s deleted by each other. Names are a weak
# signal made strong only by proximity.
NEAR_DEG = 0.02        # ~2 km — same-name-and-same-suburb is a real duplicate
SAME_DEG = 0.0005      # ~55 m — same spot, whatever it is called

def cell(lat, lon):
    return (int(lat / NEAR_DEG), int(lon / NEAR_DEG))

grid = {}
for s in bundle:
    grid.setdefault(cell(s["lat"], s["lon"]), []).append(s)

def neighbours(lat, lon):
    cy, cx = cell(lat, lon)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            yield from grid.get((cy + dy, cx + dx), ())

def duplicate_of(name, lat, lon):
    n = norm(name)
    for s in neighbours(lat, lon):
        dlat, dlon = abs(s["lat"] - lat), abs(s["lon"] - lon)
        if dlat < SAME_DEG and dlon < SAME_DEG:
            return s
        if dlat < NEAR_DEG and dlon < NEAR_DEG and norm(s["name"]) == n:
            return s
    return None

existing_ids = {s["id"] for s in bundle}

seen_place = set()          # idcode — the register repeats a place across parcels
rows, skipped = [], Counter()

for feat in features:
    p = feat["properties"]
    cls = p.get("heritageclass1desc")
    details = (p.get("details") or "").strip()

    if cls == "Contributory":
        skipped["contributory"] += 1
        continue
    if not details:
        skipped["no description"] += 1
        continue
    if cls == "Local" and not PUBLIC.search(details):
        skipped["local, private dwelling"] += 1
        continue
    if p.get("locationaccuracy") == "U":
        skipped["no usable location"] += 1
        continue

    idcode = p.get("idcode")
    if idcode in seen_place:
        skipped["repeat parcel of same place"] += 1
        continue
    seen_place.add(idcode)

    lon, lat = feat["geometry"]["coordinates"]
    name = display_name(details)

    sid = f"sahr-{idcode}"
    if sid in existing_ids or duplicate_of(name, lat, lon):
        skipped["already in catalogue"] += 1
        continue

    suburb = title_case((p.get("suburb") or "").strip())

    # For ~70% of these, `details` is just the name again ("Statue of Queen Victoria"),
    # so using it as the tagline prints the same words twice in the list row. The street
    # address is the more useful second line anyway — these are places you walk to, and
    # unlike the Wikidata sites they have no prose to fall back on.
    address = " ".join(filter(None, (
        (p.get("streetnr") or "").strip(),
        (p.get("streetname") or "").strip(),
        (p.get("streettype") or "").strip(),
    ))).strip()
    tagline = details if norm(details) != norm(name) else address
    rows.append({
        "id": sid,
        "name": name,
        "lat": round(lat, 5),
        "lon": round(lon, 5),
        "type": site_type(details),
        # The register records listing dates, not construction dates, so inferring an era
        # from shrstatusdate would date every place to the 1980s. Honest answer: unknown.
        "era": "unknown",
        "country": f"{suburb}, South Australia" if suburb else "South Australia",
        "desc": tagline,
        "src": "sahr",
    })
    row = rows[-1]
    grid.setdefault(cell(lat, lon), []).append(row)

bundle.extend(rows)
bundle.sort(key=lambda s: s["id"])
json.dump(bundle, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))

print(f"added {len(rows)} South Australian heritage places")
for reason, n in skipped.most_common():
    print(f"  skipped {n:>6}  {reason}")
print(f"\nbundle now: {len(bundle)} bulk sites, {len(open(BUNDLE).read())//1024} KB")
print("  by type:", dict(Counter(r["type"] for r in rows).most_common()))
print("  low-confidence coordinates:", sum(
    1 for f in features if f["properties"].get("locationaccuracy") == "L"))

"""Import French monuments historiques from Mérimée.

Wikidata is not the source here: it holds 12 French monuments with coordinates against a
register of 46,714. The register itself is published openly and is far richer than
anything Wikidata would have given us.

Source:  data.culture.gouv.fr, "Immeubles protégés au titre des Monuments Historiques"
Licence: Licence Ouverte v2.0 (Etalab) — reuse including commercial, with attribution.

Each record carries a `copyright` line reading "© Monuments historiques, <year>. Cette
notice reprend intégralement les termes de l'arrêté de protection…". That is a statement
that the notice reproduces a legally binding protection decree and that paper copies are
not posted out — it is not a reuse restriction, and it sits underneath the dataset's
Licence Ouverte. Attribution is still owed and is rendered per-site via `DataSource`.

Two things make this import different from the UK one:

  * 84% of records join to a Commons photo through Wikidata's P380 (Mérimée ID), against
    49% for the UK. Mérimée itself ships no images, so the join does all the work.

  * 23,896 records carry `historique` — real descriptive prose, ~525 characters at the
    median. This is the first source that answers the "bulk entries are thin" problem
    rather than adding more bare pins. It is written in French, and it stays in French:
    it is the official record of a French monument, machine-translating it would create
    an adaptation of the state's own text, and a wrong translation of a protection notice
    is worse than an untranslated one. It is labelled as such in the UI.

The prose goes in its own file, loaded lazily, so 14 MB of text never touches the main
catalogue parse — the same split already used for photo credits.
"""
import json, re, unicodedata
from collections import Counter

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
BUNDLE = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/bulk_sites.json"
HISTORY = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources/merimee_history.json"
CURATED = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Models/SiteData.swift"

TYPE_RULES = [
    (("église", "chapelle", "abbaye", "cathédrale", "basilique", "prieuré", "couvent",
      "monastère", "temple", "synagogue", "mosquée", "calvaire", "cloître"), "sacred"),
    (("musée", "galerie"), "museum"),
    (("château", "manoir", "forteresse", "citadelle", "donjon", "tour", "fort",
      "enceinte", "rempart"), "castle"),
    (("dolmen", "menhir", "tumulus", "oppidum", "villa gallo-romaine", "site archéologique",
      "vestiges", "ruines", "cromlech"), "ruin"),
    (("monument", "statue", "obélisque", "fontaine", "croix", "pont", "phare",
      "moulin"), "monument"),
    (("jardin", "parc", "square"), "natural"),
]

def site_type(denomination):
    d = (denomination or "").lower()
    for needles, mapped in TYPE_RULES:
        if any(n in d for n in needles):
            return mapped
    return "heritage"

# "3e quart 19e siècle", "16e siècle;2e moitié 19e siècle", "Moyen Age"
CENTURY = re.compile(r"(\d{1,2})e\s*siècle", re.I)

def era_from_century(field, datation):
    """The register dates by century phrase, not by year. Take the EARLIEST century
    mentioned — "16e siècle;2e moitié 19e siècle" means a 16th-century building altered
    in the 19th, and the building is what someone travels to see."""
    text = " ".join(x for x in (field, datation) if x)
    if not text:
        return "unknown"
    centuries = [int(m) for m in CENTURY.findall(text)]
    if centuries:
        year = (min(centuries) - 1) * 100          # 19e siècle -> 1800
    elif re.search(r"moyen[- ]age", text, re.I):
        return "medieval"
    elif re.search(r"antiquité|gallo-romain|romain", text, re.I):
        return "classical"
    elif re.search(r"préhistoire|néolithique|protohistoire", text, re.I):
        return "ancient"
    else:
        return "unknown"
    if year < -500:  return "ancient"
    if year < 500:   return "classical"
    if year < 1400:  return "medieval"
    if year < 1750:  return "renaissance"
    return "modern"

def norm(s):
    s = unicodedata.normalize("NFKD", s)
    return re.sub(r"[^a-z0-9]", "", s.lower())

records = json.load(open(f"{SP}/merimee_raw.json"))
images = json.load(open(f"{SP}/merimee_imgs_map.json"))
bundle = json.load(open(BUNDLE))

src = open(CURATED).read()
cur_names = {norm(m) for m in re.findall(r'name: "([^"]+)"', src)}
cur_points = list(zip((float(x) for x in re.findall(r"latitude: (-?[\d.]+)", src)),
                      (float(x) for x in re.findall(r"longitude: (-?[\d.]+)", src))))

# Name within ~250 m only — never position alone. See merge_heritage_uk.py for why:
# proximity-only dedup deleted Dover Castle and 25,657 others.
NEAR_DEG = 0.0025

def cell(lat, lon):
    return (int(lat / NEAR_DEG), int(lon / NEAR_DEG))

grid = {}
for s in bundle:
    grid.setdefault(cell(s["lat"], s["lon"]), []).append(s)

# Dedup ONLY against what was already in the catalogue — never Mérimée against itself.
# The register's own `reference` is a unique key, so within-source identity is already
# guaranteed and a name check can only produce false positives. It duly produced 3,943 of
# them: 2,717 buildings titled "Maison" and 2,124 titled "Immeuble" are not one building
# recorded repeatedly, they are separately protected buildings on the same street that
# the register gives a generic editorial title. The grid is therefore frozen here and
# newly added rows are not fed back into it.

# Titles repeat because the register names a building by what it is when it has no name
# of its own: 2,717 "Maison", 2,448 "Eglise", 465 "Eglise Saint-Martin". Qualifying any
# repeated title with its commune makes the row legible on a map pin and in search, where
# "Eglise" alone tells a reader nothing.
title_counts = Counter((r.get("titre_editorial_de_la_notice") or "").strip()
                       for r in records)

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

history, rows, skipped = {}, [], Counter()

for r in records:
    name = (r.get("titre_editorial_de_la_notice") or "").strip()
    coords = r.get("coordonnees_au_format_wgs84") or {}
    lat, lon = coords.get("lat"), coords.get("lon")
    if not name or lat is None or lon is None:
        skipped["no name or location"] += 1
        continue

    # Mérimée covers the overseas départements, but a handful of records carry
    # placeholder coordinates at (0, 0) in the Gulf of Guinea.
    if abs(lat) < 0.01 and abs(lon) < 0.01:
        skipped["null-island coordinates"] += 1
        continue

    sid = "mh-" + r["reference"]
    commune = (r.get("commune_forme_editoriale") or "").strip()

    # Addresses list every frontage the building touches, semicolon separated
    # ("place de l'Hôtel-de-Ville ; rue de Rivoli ; rue Lobau"). The first is enough to
    # find it and keeps the name readable on a map pin.
    address = (r.get("adresse_forme_editoriale") or "").split(";")[0].strip()

    # Prefer the street over the commune when disambiguating. Qualifying by commune alone
    # produced four consecutive rows reading "Immeuble, Paris 4e Arrondissement" in the
    # Explore list, which tells a reader standing on the street nothing at all —
    # arrondissements hold hundreds of protected buildings. "Immeuble, 12 rue de Rivoli"
    # is a place you can walk to. Only 17,215 records carry an address, so the commune
    # remains the fallback.
    if title_counts[name] > 1:
        if address:
            name = f"{name}, {address}"
        elif commune:
            name = f"{name}, {commune}"

    if norm(name) in cur_names or any(
            abs(lat - la) < 0.0005 and abs(lon - lo) < 0.0005 for la, lo in cur_points):
        skipped["duplicates a curated site"] += 1
        continue
    if duplicate_of(name, lat, lon):
        skipped["duplicate of a site already in the catalogue"] += 1
        continue

    denomination = (r.get("denomination_de_l_edifice") or "").strip()
    century = (r.get("siecle_de_la_campagne_principale_de_construction") or "").strip()

    # The list row wants one short line. `historique` is a 525-character paragraph, so the
    # building type and its century do that job and the prose lives in the detail sheet.
    tagline = " · ".join(x for x in (denomination.capitalize() or None, century or None) if x)
    if not tagline:
        tagline = address

    row = {
        "id": sid,
        "name": name,
        "lat": round(lat, 5),
        "lon": round(lon, 5),
        "type": site_type(denomination),
        "era": era_from_century(century, r.get("datation_de_l_edifice")),
        "country": f"{commune}, France" if commune else "France",
        "desc": tagline,
        "src": "merimee",
    }
    if r["reference"] in images:
        row["img"] = images[r["reference"]]

    hist = (r.get("historique") or "").strip()
    if hist:
        history[sid] = hist

    bundle.append(row)
    rows.append(row)

bundle.sort(key=lambda s: s["id"])
json.dump(bundle, open(BUNDLE, "w"), ensure_ascii=False, separators=(",", ":"))
json.dump(history, open(HISTORY, "w"), ensure_ascii=False, separators=(",", ":"))

print(f"added {len(rows)} French monuments historiques")
for reason, n in skipped.most_common():
    print(f"  skipped {n:>6}  {reason}")
print(f"\n  with photo:      {sum(1 for r in rows if r.get('img'))} "
      f"({sum(1 for r in rows if r.get('img')) * 100 // max(len(rows), 1)}%)")
print(f"  with historique: {len(history)}")
print(f"  by type: {dict(Counter(r['type'] for r in rows).most_common())}")
print(f"  by era:  {dict(Counter(r['era'] for r in rows).most_common())}")
print(f"\nbundle now:  {len(bundle)} bulk sites, {len(open(BUNDLE).read()) // 1024} KB")
print(f"history file: {len(open(HISTORY).read()) // 1024} KB")

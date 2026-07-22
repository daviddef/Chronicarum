"""Which present-day country is a coordinate standing in.

Used by [`derive_country.py`](derive_country.py) to settle the `country` field, and kept
separate because "where is this point" is a question the import scripts will want again.

**Natural Earth 10m admin-0 boundaries**, public domain, ~13 MB of GeoJSON fetched into the
scratchpad rather than committed — it is a third-party dataset with its own release
cadence, and nothing in the app reads it at runtime. 10m rather than 50m because the sites
this exists for sit *on* borders: Hadrian's Wall, the Curonian Spit, Muskau Park astride
the Neisse. At 50m the Neisse is a suggestion.

Pure Python, no geo dependencies: ray casting against a 1-degree grid index, so each query
tests a handful of polygons rather than 258. About 40 µs a point on the 22k rows this runs
over — the SPARQL fetch dominates.

**Country names come from Wikidata, not Natural Earth**, keyed on ISO 3166-1 alpha-2. The
catalogue's existing labels are Wikidata labels ("Czech Republic", not Natural Earth's
"Czechia"; "The Gambia", not "Gambia"), and a repair pass that silently renamed half of
Europe would split every collection in two.
"""
import json, os, subprocess, sys
from collections import defaultdict

NE_URL = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master"
          "/geojson/ne_10m_admin_0_countries.geojson")

# Wikidata gives NL to Q29999 "Kingdom of the Netherlands", the sovereign state; every
# site in the catalogue says "Netherlands", the constituent country, which has no ISO code
# of its own. The only case in the dataset where the two disagree.
ALIAS = {"Kingdom of the Netherlands": "Netherlands"}


def _in_ring(x, y, ring):
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i]
        xj, yj = ring[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


class CountryIndex:
    CELL = 1.0                     # degrees; ~110 km, so most cells hold one country

    def __init__(self, geojson_path, iso_labels):
        self.grid = defaultdict(list)
        self.polygons = []
        for feature in json.load(open(geojson_path))["features"]:
            props = feature["properties"]
            # ISO_A2_EH resolves the codes Natural Earth leaves as -99 on the main field
            # (France, Norway). What is still -99 after it is genuinely unassigned:
            # Somaliland, Northern Cyprus, the Cyprus buffer zone, Bir Tawil. Those are
            # skipped, so a site inside one resolves to None and keeps whatever it had.
            entry = iso_labels.get(props.get("ISO_A2_EH") or props.get("ISO_A2"))
            if entry is None:
                continue
            label = ALIAS.get(entry["label"], entry["label"])
            geometry = feature["geometry"]
            parts = (geometry["coordinates"] if geometry["type"] == "MultiPolygon"
                     else [geometry["coordinates"]])
            for rings in parts:
                xs = [p[0] for p in rings[0]]
                ys = [p[1] for p in rings[0]]
                box = (min(xs), min(ys), max(xs), max(ys))
                index = len(self.polygons)
                self.polygons.append((label, box, rings))
                for cx in range(int(box[0] // self.CELL), int(box[2] // self.CELL) + 1):
                    for cy in range(int(box[1] // self.CELL), int(box[3] // self.CELL) + 1):
                        self.grid[(cx, cy)].append(index)

    def country(self, lat, lon):
        """The country whose land boundary contains this point, or None.

        None is the honest answer surprisingly often — 9,452 catalogue rows, nearly all of
        them harbour walls, piers, lighthouses and offshore rocks that fall a few metres
        outside a coastline drawn at 1:10m. Callers keep the existing value rather than
        guessing a nearest country."""
        for index in self.grid.get((int(lon // self.CELL), int(lat // self.CELL)), ()):
            label, (x0, y0, x1, y1), rings = self.polygons[index]
            if not (x0 <= lon <= x1 and y0 <= lat <= y1):
                continue
            if not _in_ring(lon, lat, rings[0]):
                continue
            if any(_in_ring(lon, lat, hole) for hole in rings[1:]):
                continue
            return label
        return None


def boundaries(scratch):
    """Fetch the Natural Earth file into `scratch` if it is not already there."""
    path = os.path.join(scratch, "ne_10m_admin_0_countries.geojson")
    if not os.path.exists(path):
        sys.stderr.write("fetching Natural Earth 10m boundaries...\n")
        subprocess.run(["curl", "-sSL", "--max-time", "300", "-o", path, NE_URL], check=True)
    return path

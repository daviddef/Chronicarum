"""Download real heritage footprints for the UK, to establish containment geometrically.

## Why only scheduled monuments

The roadmap said "several registers publish polygon layers; only points were imported",
and assumed that was the route to real containment coverage. Checking it first was worth
more than building on it, because it is largely **wrong**:

  * **Historic England listed buildings.** There *is* a polygon layer, and it has exactly
    the same record count as the point layer (379,680), which makes it look like full
    coverage. It is not. Only listings created or amended since 4 April 2011 carry a real
    mapped extent — about 2.6%. Every older record is a **2.5 m placeholder triangle** at
    the point location: sampling returned 4-vertex rings spanning 2.4 m for Grade I
    buildings in central London. Dense historic cities are almost entirely pre-2011, so the
    places where containment matters most are precisely the ones with no geometry.
  * **Historic Environment Scotland listed buildings.** Points only — 67,480 points against
    740 boundary polygons, 1.1%. Edinburgh, which is the single most clustered city in our
    catalogue at 7,547 sites within 250 m of each other, gets nothing.

**Scheduled monuments are the exception and are genuinely mapped** — HE ~20,000 and HES
~8,072 real boundaries, tens to hundreds of metres across with 14–154 vertices. That is the
one honest source of geometric containment in the UK, so it is the only thing this script
takes. It bounds what the whole approach can achieve: precincts, forts, abbey grounds and
castle earthworks that physically contain other listed things — not terraces.

## Licence

Both bodies publish under **Open Government Licence v3.0**, which permits commercial use
and redistribution with attribution. The geometry is derived from Ordnance Survey MasterMap,
so the required credit includes the Crown copyright line — see `ATTRIBUTION` below. Note we
ship only the *derived relations*, never the polygons themselves.
"""
import json, subprocess, sys, time

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"

HE = ("https://services-eu1.arcgis.com/ZOdPfBS3aqqDYPUQ/ArcGIS/rest/services"
      "/National_Heritage_List_for_England_NHLE_v02_VIEW/FeatureServer/6/query")

ATTRIBUTION = ("Contains Historic England data © Historic England. Contains Ordnance "
               "Survey data © Crown copyright and database right. Licensed under the Open "
               "Government Licence v3.0.")

PAGE = 1000


def fetch_page(offset):
    """One page of scheduled monuments as GeoJSON in WGS84."""
    url = (f"{HE}?where=1%3D1&outFields=ListEntry,Name&f=geojson&outSR=4326"
           f"&resultOffset={offset}&resultRecordCount={PAGE}")
    for attempt in range(4):
        out = subprocess.run(["curl", "-sS", "--max-time", "180", url],
                             capture_output=True, text=True)
        try:
            return json.loads(out.stdout).get("features", [])
        except Exception:
            sys.stderr.write(f"    ! offset {offset} attempt {attempt + 1} failed\n")
            time.sleep(5)
    return None


def rings_of(geometry):
    """Every outer ring in a Polygon or MultiPolygon, as [[lon, lat], ...].

    Holes are deliberately ignored. A scheduled area with a hole in it is rare, and
    treating a site in the hole as contained is a far smaller error than dropping the
    monument entirely.
    """
    if geometry is None:
        return []
    kind, coords = geometry["type"], geometry["coordinates"]
    if kind == "Polygon":
        return [coords[0]]
    if kind == "MultiPolygon":
        return [poly[0] for poly in coords]
    return []


def main():
    features, offset = [], 0
    while True:
        page = fetch_page(offset)
        if page is None:
            sys.stderr.write(f"  ! gave up at offset {offset} — coverage incomplete\n")
            break
        if not page:
            break
        features.extend(page)
        print(f"  fetched {len(features):>6} monuments", flush=True)
        offset += PAGE
        if len(page) < PAGE:
            break

    out = []
    stub = 0
    for f in features:
        rings = rings_of(f.get("geometry"))
        if not rings:
            continue
        # Guard against the placeholder-triangle problem even here: a "polygon" only a few
        # metres across contains nothing and would only add noise.
        span = 0.0
        for ring in rings:
            xs = [p[0] for p in ring]
            ys = [p[1] for p in ring]
            span = max(span, (max(ys) - min(ys)) * 111_000,
                       (max(xs) - min(xs)) * 111_000 * 0.6)
        if span < 10:
            stub += 1
            continue
        props = f.get("properties") or {}
        out.append({"ref": str(props.get("ListEntry")),
                    "name": props.get("Name"),
                    "rings": rings})

    json.dump(out, open(f"{SP}/footprints_uk.json", "w"))
    print(f"\n{len(out)} usable scheduled-monument footprints -> footprints_uk.json")
    print(f"  {stub} dropped as sub-10 m stubs")


if __name__ == "__main__":
    main()

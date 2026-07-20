"""Fetch the US National Register of Historic Places from the NPS ArcGIS service.

Source:  mapservices.nps.gov, cultural_resources/nrhp_locations, layer 0 (points)
Licence: public domain — a work of the US federal government, 17 U.S.C. §105. Nothing is
         owed, though the NPS is credited anyway because it costs nothing.

Two things to know about this dataset before trusting it as a map layer:

  * It is explicitly the "public, NON-SENSITIVE OR RESTRICTED" subset. Archaeological
    sites withheld under ARPA and NHPA §304 are simply absent — 72,668 points against
    roughly 95,000 actual listings. The gap is deliberate and must not be "fixed".

  * `CertDate` is when a property was *listed*, not when it was built. Deriving an era
    from it would date every American site to the late twentieth century. Construction
    dates come from the Wikidata join instead, and are left unknown where that misses.

The register carries no descriptions and no images, so both come from Wikidata via P649
(NRHP reference number): 75,526 refs resolve to a Commons photo and 82,640 to an English
description — better coverage than the register itself offers.

Paged at the service's 2,000-record ceiling; `resultOffset` needs a stable sort, so the
query orders by OBJECTID rather than trusting the default order across pages.
"""
import json, subprocess, sys, time, urllib.parse

SP = "/private/tmp/claude-501/-Users-daviddefranceski-Claude-Projects-Chronicarum/2e1454ca-a069-4f93-baf5-8ff725f648bc/scratchpad"
UA = "ChronicarumHeritageApp/0.1 (david.defranceski@gmail.com)"
LAYER = ("https://mapservices.nps.gov/arcgis/rest/services/cultural_resources"
         "/nrhp_locations/MapServer/0/query")

PAGE = 2000
FIELDS = "RESNAME,ResType,Address,City,County,State,NRIS_Refnum,Is_NHL,IS_EXTANT"

def fetch_page(offset):
    args = [
        "curl", "-sS", "-G", "--max-time", "180", LAYER,
        "--data-urlencode", "where=1=1",
        "--data-urlencode", f"outFields={FIELDS}",
        "--data", "returnGeometry=true",
        "--data", "outSR=4326",
        "--data", "orderByFields=OBJECTID",
        "--data", f"resultOffset={offset}",
        "--data", f"resultRecordCount={PAGE}",
        "--data", "f=json",
        "-H", f"User-Agent: {UA}",
    ]
    for attempt in range(4):
        out = subprocess.run(args, capture_output=True, text=True)
        try:
            payload = json.loads(out.stdout)
            if "features" in payload:
                return payload["features"]
            sys.stderr.write(f"    ! offset {offset}: {str(payload)[:120]}\n")
        except Exception:
            sys.stderr.write(f"    ! offset {offset} attempt {attempt + 1} failed\n")
        time.sleep(6)
    return None

rows, offset, failed = {}, 0, []

while True:
    features = fetch_page(offset)
    if features is None:
        failed.append(offset)
        sys.stderr.write(f"  ! GAVE UP at offset {offset} — coverage incomplete\n")
        offset += PAGE
        if offset > 100_000:
            break
        continue
    if not features:
        break

    for f in features:
        a = f.get("attributes") or {}
        g = f.get("geometry") or {}
        ref = (a.get("NRIS_Refnum") or "").strip()
        lon, lat = g.get("x"), g.get("y")
        if not ref or lat is None or lon is None:
            continue
        # Same reference can appear more than once when a listing has several mapped
        # points; the first is enough for a pin.
        rows.setdefault(ref, {
            "ref": ref,
            "name": (a.get("RESNAME") or "").strip(),
            "lat": round(float(lat), 5),
            "lon": round(float(lon), 5),
            "restype": a.get("ResType"),
            "address": (a.get("Address") or "").strip(),
            "city": (a.get("City") or "").strip(),
            "county": (a.get("County") or "").strip(),
            "state": (a.get("State") or "").strip(),
            "nhl": a.get("Is_NHL") == "X",
            "extant": a.get("IS_EXTANT"),
        })

    print(f"  offset {offset:>6}: +{len(features)} rows (unique {len(rows)})", flush=True)
    offset += PAGE

out = list(rows.values())
json.dump(out, open(f"{SP}/heritage_us.json", "w"), ensure_ascii=False)

print(f"\n{len(out)} NRHP listings -> heritage_us.json")
print(f"  National Historic Landmarks: {sum(1 for r in out if r['nhl'])}")
print(f"  recorded as not extant:      {sum(1 for r in out if r['extant'] == 'False')}")
if failed:
    print(f"  ! offsets that failed and were skipped: {failed}")

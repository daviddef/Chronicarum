"""Convert the row-wise catalogue into the columnar form the app actually ships.

`bulk_sites.json` stays row-wise because that is what every import script reads and
writes, and a list of records is what a human wants to inspect. It is NOT bundled — see
the exclude in project.yml. This produces `bulk_columnar.json`, which is.

Why bother, measured on a Release build at 187,507 rows:

    JSONDecoder over [BulkSite]          1,457 ms      40 MB
    JSONSerialization, row dictionaries  1,918 ms      40 MB   <- slower, see below
    JSONSerialization, columnar            967 ms      29 MB

The middle row is the interesting one. Replacing `Codable` with `JSONSerialization` looked
like an obvious win and made things 32% worse: it hands back `NSDictionary`, so every
`row["name"] as? String` crosses the Objective-C bridge, and at ten fields over 187k rows
that is ~1.9M bridged casts — more expensive than the reflection it was meant to avoid.

Columnar wins because it pays those costs once per *field* instead of once per *row*: ten
array casts total, then plain indexed access. It is also 26% smaller on disk, because a
row-wise file repeats all ten key names 187,507 times.
"""
import json, os, sys

RESOURCES = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Resources"
SRC = f"{RESOURCES}/bulk_sites.json"
OUT = f"{RESOURCES}/bulk_columnar.json"

# Order matters only for readability; the loader reads by key.
FIELDS = ("id", "name", "lat", "lon", "type", "era", "country", "desc", "img", "src", "th", "dur", "par")
NUMERIC = {"lat", "lon", "th", "dur"}   # theme bitmask + estimated visit minutes
# The only fields genuinely absent from source records. Everything else is always written
# by the import scripts, so dropping an empty one on expand would not round-trip.
OPTIONAL = {"img", "src", "par"}

def build():
    """Row-wise -> columnar, the form the app bundles."""
    rows = json.load(open(SRC))
    columns = {field: [] for field in FIELDS}

    for row in rows:
        for field in FIELDS:
            value = row.get(field)
            if value is None:
                # Empty string rather than null keeps every column a homogeneous [String],
                # so the Swift side casts each column once instead of unwrapping per element.
                value = (0 if field in ("th", "dur", "par") else 0.0) if field in NUMERIC else ""
            columns[field].append(value)

    json.dump(columns, open(OUT, "w"), ensure_ascii=False, separators=(",", ":"))

    print(f"{len(rows)} rows -> {OUT}")
    print(f"  row-wise : {os.path.getsize(SRC) // 1024:>6} KB (not bundled, git-ignored)")
    print(f"  columnar : {os.path.getsize(OUT) // 1024:>6} KB (bundled, committed)")
    print(f"  saving   : {(os.path.getsize(SRC) - os.path.getsize(OUT)) // 1024:>6} KB")


def expand():
    """Rebuild the row-wise file from the columnar one.

    `bulk_sites.json` is git-ignored: it is 39 MB, it is what the import scripts read and
    write, and it is fully derivable from the 29 MB columnar file that actually ships.
    Committing both would add ~68 MB to every import commit to store the same catalogue
    twice. Run this first if `bulk_sites.json` is missing.
    """
    columns = json.load(open(OUT))
    count = len(columns["id"])
    rows = []
    for i in range(count):
        row = {}
        for field in FIELDS:
            value = columns[field][i]
            # Empty strings were written to keep columns homogeneous. Drop them again for
            # the optional fields only — dropping an empty `desc` would not round-trip,
            # because the import scripts always write that key even when it is blank.
            if value == "" and field in OPTIONAL:
                continue
            row[field] = value
        rows.append(row)
    json.dump(rows, open(SRC, "w"), ensure_ascii=False, separators=(",", ":"))
    print(f"expanded {count} rows -> {SRC}")


if __name__ == "__main__":
    expand() if "--expand" in sys.argv else build()

import Foundation
import CoreLocation

/// On-demand local places. The bundled catalogue is deep where it's deep — Bath, London, the
/// heritage-dense regions — and thin in a small coastal town like Senj, where a day would
/// otherwise be two stops or an hour in the car to pad it out. This fills that gap: when a
/// plan is asked for somewhere the bundle is thin, it fetches the local historic sites,
/// museums, viewpoints, parks, playgrounds and beaches live from OpenStreetMap, caches them to
/// disk, and hands them to the planner. First visit needs the network; after that it's instant
/// and offline.
///
/// Deliberately gap-filling, not always-on: a dense city already has plenty bundled, so the
/// fetch is skipped there — which also keeps it off the slow public Overpass servers except
/// where it actually earns its keep. Everything it returns is `dataSource: .openStreetMap`,
/// ODbL, attributed like the rest of the OSM layers.
actor LocalPlacesService {
    static let shared = LocalPlacesService()

    /// Cached local sites, keyed by a coarse area cell (~28 km). In memory for the session,
    /// backed by disk so it survives a relaunch and works offline.
    private var byArea: [String: [Site]] = [:]
    private var inFlight: Set<String> = []

    private let endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
    ]

    // "Thin" is about the *local* area, not the county: enough worthwhile heritage within a
    // short reach, and some family places within a slightly wider one. Senj clears neither —
    // three heritage sites within 12 km and no playground within 15 km — while a real city
    // clears both and is left alone.
    private static let heritageRadiusKm = 12.0
    private static let heritageThreshold = 15
    private static let familyRadiusKm = 15.0
    private static let familyThreshold = 5

    // MARK: - Public

    /// Ensure local places for the area around `origin` are loaded, fetching once if the
    /// bundle is thin there and nothing is cached. Safe to call on every plan; it returns
    /// immediately when the area is already known or the bundle is rich enough.
    func ensureLoaded(around origin: CLLocationCoordinate2D) async {
        let key = Self.areaKey(origin)
        if byArea[key] != nil || inFlight.contains(key) { return }

        if let disk = loadFromDisk(key) {
            byArea[key] = disk
            return
        }
        // Only reach for the network where the bundle can't build a decent local day.
        guard Self.bundleIsThin(around: origin) else {
            byArea[key] = []          // remember that we looked and didn't need to
            return
        }
        inFlight.insert(key)
        defer { inFlight.remove(key) }
        let sites = await fetch(around: origin)
        byArea[key] = sites
        saveToDisk(key, sites)
    }

    /// The local sites known for the area around a point — whatever `ensureLoaded` has put in
    /// the cache. Empty until then.
    func sites(around origin: CLLocationCoordinate2D) -> [Site] {
        byArea[Self.areaKey(origin)] ?? []
    }

    // MARK: - Thinness

    /// Thin if the *local* area lacks heritage or lacks family places — either gap is worth
    /// filling from OSM.
    nonisolated static func bundleIsThin(around origin: CLLocationCoordinate2D) -> Bool {
        var heritage = 0, family = 0
        for site in SiteData.all {
            let d = site.approxDistanceKm(from: origin)
            if d <= heritageRadiusKm, site.significance >= 25, site.visitMinutes >= 10 {
                heritage += 1
            }
            if d <= familyRadiusKm, SiteType.family.contains(site.type) {
                family += 1
            }
            if heritage >= heritageThreshold && family >= familyThreshold { return false }
        }
        return heritage < heritageThreshold || family < familyThreshold
    }

    // MARK: - Area keys & cache files

    /// ~0.25° cells (~28 km), so a plan reuses a neighbour's fetch and the cache stays small.
    nonisolated private static func areaKey(_ c: CLLocationCoordinate2D) -> String {
        let la = (c.latitude / 0.25).rounded() * 0.25
        let lo = (c.longitude / 0.25).rounded() * 0.25
        return String(format: "%.2f_%.2f", la, lo)
    }

    nonisolated private func cacheURL(_ key: String) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalPlaces", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(key).json")
    }

    private func loadFromDisk(_ key: String) -> [Site]? {
        guard let data = try? Data(contentsOf: cacheURL(key)) else { return nil }
        return try? JSONDecoder().decode([Site].self, from: data)
    }

    private func saveToDisk(_ key: String, _ sites: [Site]) {
        if let data = try? JSONEncoder().encode(sites) {
            try? data.write(to: cacheURL(key), options: .atomic)
        }
    }

    // MARK: - Fetch

    private func fetch(around origin: CLLocationCoordinate2D) async -> [Site] {
        // ~35 km box, enough to fill a day's dayReachKm around the origin.
        let dLat = 0.32, dLon = 0.32 / max(0.2, cos(origin.latitude * .pi / 180))
        let s = origin.latitude - dLat, n = origin.latitude + dLat
        let w = origin.longitude - dLon, e = origin.longitude + dLon
        let bbox = String(format: "%.4f,%.4f,%.4f,%.4f", s, w, n, e)
        let query = """
        [out:json][timeout:20];
        (
          nwr["historic"]["name"](\(bbox));
          nwr["tourism"~"^(museum|gallery|artwork|attraction|viewpoint|zoo|theme_park|aquarium)$"]["name"](\(bbox));
          nwr["leisure"~"^(playground|park|nature_reserve|water_park)$"](\(bbox));
          nwr["natural"="beach"]["name"](\(bbox));
        );
        out center tags 500;
        """
        guard let raw = await request(query) else { return [] }
        return parse(raw, around: origin)
    }

    private func request(_ query: String) async -> [String: Any]? {
        let body = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")"
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.httpBody = body.data(using: .utf8)
            req.timeoutInterval = 18       // forgiving enough for a real query, still bounded
            req.setValue("Chronicarum/local (ODbL)", forHTTPHeaderField: "User-Agent")
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               (resp as? HTTPURLResponse)?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
        }
        return nil   // offline, or the servers are busy — the plan falls back to the bundle
    }

    // MARK: - Parse & map

    private func parse(_ raw: [String: Any], around origin: CLLocationCoordinate2D) -> [Site] {
        guard let elements = raw["elements"] as? [[String: Any]] else { return [] }

        // Bundled sites near the box, to skip OSM copies of what we already have.
        let nearbyBundled = SiteData.all.filter { $0.approxDistanceKm(from: origin) <= 45 }

        var out: [Site] = []
        var placed: [(lat: Double, lon: Double)] = []

        for el in elements {
            let tags = el["tags"] as? [String: String] ?? [:]
            guard let (la, lo) = coordinate(el) else { continue }
            guard let mapped = classify(tags) else { continue }
            let name = (tags["name"] ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            // Skip a place we already hold (bundled) or already added (this batch).
            let coord = CLLocationCoordinate2D(latitude: la, longitude: lo)
            if nearbyBundled.contains(where: {
                $0.approxDistanceKm(from: coord) < 0.15 && similar($0.name, name)
            }) { continue }
            if placed.contains(where: {
                Site.haversineKmPair($0.lat, $0.lon, la, lo) < 0.12
            }) { continue }

            let id = "osm/\((el["type"] as? String)?.first.map(String.init) ?? "n")\(el["id"] as? Int ?? 0)"
            out.append(Site(
                id: id, name: name, location: tags["addr:city"] ?? "",
                latitude: la, longitude: lo,
                era: .unknown, type: mapped.type, tier: 2,
                builtDescription: "—", civilisation: "—",
                tagline: mapped.tagline, chapters: [],
                nearestAirport: nil, bestTimeToVisit: nil, visaNote: nil,
                imageFile: nil, dataSource: .openStreetMap,
                themeMask: mapped.themes.rawValue,
                visitMinutes: mapped.minutes,
                parentID: nil,
                significance: score(mapped.base, tags)))
            placed.append((la, lo))
        }
        return out
    }

    private func coordinate(_ el: [String: Any]) -> (Double, Double)? {
        if let la = el["lat"] as? Double, let lo = el["lon"] as? Double { return (la, lo) }
        if let c = el["center"] as? [String: Any],
           let la = c["lat"] as? Double, let lo = c["lon"] as? Double { return (la, lo) }
        return nil
    }

    /// OSM tags → our type, themes, duration, tagline, base significance. Nil for anything not
    /// worth a stop.
    private func classify(_ t: [String: String]) -> (type: SiteType, themes: Theme, minutes: Int, tagline: String, base: Int)? {
        if let h = t["historic"] {
            switch h {
            case "castle", "fort", "fortress", "citadel":
                return (.castle, .castles, 60, "Castle or fort", 42)
            case "ruins", "archaeological_site":
                return (.ruin, .archaeology, 45, "Ruins", 38)
            case "monastery":
                return (.sacred, .sacred, 45, "Monastery", 36)
            case "church", "chapel", "monument", "memorial", "wayside_shrine":
                let sacred = (h == "church" || h == "chapel")
                return (sacred ? .sacred : .monument, sacred ? .sacred : .monuments,
                        sacred ? 30 : 20, sacred ? "Historic church" : "Monument", 30)
            case "manor", "mansion", "palace":
                return (.heritage, .grandHouses, 45, "Historic house", 36)
            default:
                return (.heritage, .monuments, 30, "Historic site", 30)   // tower, gate, walls…
            }
        }
        switch t["tourism"] {
        case "museum", "gallery": return (.museum, .museums, 90, "Museum", 40)
        case "artwork":           return (.monument, .monuments, 15, "Public artwork", 26)
        case "attraction":        return (.heritage, .townscape, 40, "Local attraction", 30)
        case "viewpoint":         return (.natural, .gardens, 15, "Viewpoint", 30)
        case "zoo", "aquarium":   return (.wildlife, [.family], 120, "Wildlife", 55)
        case "theme_park":        return (.themepark, [.family], 180, "Theme park", 60)
        default: break
        }
        switch t["leisure"] {
        case "playground":     return (.playground, [.family, .gardens], 45, "Playground", 44)
        case "park":           return (.park, [.family, .gardens], 60, "Park", 40)
        case "nature_reserve": return (.park, [.family, .gardens], 90, "Nature reserve", 44)
        case "water_park":     return (.waterplay, [.family], 150, "Water park", 55)
        default: break
        }
        if t["natural"] == "beach" { return (.beach, [.family, .maritime], 120, "Beach", 48) }
        return nil
    }

    /// Local places score modestly — enough to fill a thin local day once the tier relaxes,
    /// never enough to outrank a curated flagship. A wiki link is a small vote of notability.
    private func score(_ base: Int, _ tags: [String: String]) -> Int {
        var s = base
        if tags["wikidata"] != nil { s += 8 }
        if tags["wikipedia"] != nil { s += 4 }
        if tags["heritage"] != nil { s += 4 }
        return min(68, s)
    }

    private func similar(_ a: String, _ b: String) -> Bool {
        let x = a.lowercased(), y = b.lowercased()
        return x.contains(y) || y.contains(x)
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&+=?")
        return set
    }()
}

extension Site {
    static func haversineKmPair(_ la1: Double, _ lo1: Double, _ la2: Double, _ lo2: Double) -> Double {
        let r = 6371.0
        let dLat = (la2 - la1) * .pi / 180, dLon = (lo2 - lo1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(la1 * .pi / 180) * cos(la2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}

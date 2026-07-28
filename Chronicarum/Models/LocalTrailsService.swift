import Foundation
import CoreLocation

/// On-demand trails, the line-shaped sibling of `LocalPlacesService`. The bundled trail layer
/// keeps only national and international routes, so in a place like Senj the nearest walk is
/// 60 km away while the local Velebit paths — real, waymarked, on the ground — are invisible.
/// When someone browses trails somewhere the bundle is thin, this fetches the *local* routes
/// (every network tier, not just national) live from OpenStreetMap, assembles and simplifies
/// their geometry into the same shape the bundle ships, and caches them to disk.
///
/// Gap-triggered like the places service: it only fetches where the nearest bundled trail is
/// far, so it leaves well-covered regions — and the busy public servers — alone.
actor LocalTrailsService {
    static let shared = LocalTrailsService()

    private var byArea: [String: [Trail]] = [:]
    /// One unstructured in-flight fetch per area — see the twin note in `LocalPlacesService`.
    /// The caller runs inside a SwiftUI `.task(id:)` that cancels on any control change; a
    /// structured await would carry that cancellation into the network request and kill it in
    /// milliseconds. Awaiting an unstructured task's `.value` shields the fetch from that.
    private var inFlightTasks: [String: Task<Void, Never>] = [:]

    private let endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.openstreetmap.fr/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    ]

    /// Thin unless a bundled trail that's actually a *local walk option* passes nearby: close,
    /// and short enough to be a walk rather than a multi-week through-route. A 761 km national
    /// route grazing Senj is not a walk near Senj, so its presence must not suppress the fetch
    /// of the real local paths — that was the trails twin of the places-layer thinness bug.
    private static let thinRadiusKm = 12.0
    private static let localTrailMaxKm = 40.0

    // MARK: - Public

    func ensureLoaded(around origin: CLLocationCoordinate2D) async {
        let key = Self.areaKey(origin)
        if byArea[key] != nil { return }
        if let disk = loadFromDisk(key) { byArea[key] = disk; return }
        guard Self.bundleIsThin(around: origin) else { byArea[key] = []; return }
        let task = inFlightTasks[key] ?? {
            let created = Task { await performFetch(key: key, origin: origin) }
            inFlightTasks[key] = created
            return created
        }()
        await task.value
    }

    /// The network fetch, shielded from view-task cancellation by its unstructured task. Don't
    /// cache a failed fetch (nil) — retry next time rather than blank the area.
    private func performFetch(key: String, origin: CLLocationCoordinate2D) async {
        defer { inFlightTasks[key] = nil }
        if let trails = await fetch(around: origin), !trails.isEmpty {
            byArea[key] = trails
            saveToDisk(key, trails)
        }
    }

    func trails(around origin: CLLocationCoordinate2D) -> [Trail] {
        byArea[Self.areaKey(origin)] ?? []
    }

    nonisolated static func bundleIsThin(around origin: CLLocationCoordinate2D) -> Bool {
        !TrailData.all.contains { trail in
            trail.km <= localTrailMaxKm && trail.nearestDistanceKm(from: origin) <= thinRadiusKm
        }
    }

    // MARK: - Area & cache

    nonisolated private static func areaKey(_ c: CLLocationCoordinate2D) -> String {
        let la = (c.latitude / 0.25).rounded() * 0.25
        let lo = (c.longitude / 0.25).rounded() * 0.25
        return String(format: "%.2f_%.2f", la, lo)
    }

    nonisolated private func cacheURL(_ key: String) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalTrails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(key).json")
    }

    /// Cached as the same columnar dict the bundle uses, decoded back through `TrailData`.
    private func loadFromDisk(_ key: String) -> [Trail]? {
        guard let data = try? Data(contentsOf: cacheURL(key)),
              let cols = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let trails = TrailData.decode(cols)
        return trails.isEmpty ? nil : trails      // empty cache is a stale failure — retry it
    }

    private func saveToDisk(_ key: String, _ trails: [Trail]) {
        let cols = Self.columns(from: trails)
        if let data = try? JSONSerialization.data(withJSONObject: cols) {
            try? data.write(to: cacheURL(key), options: .atomic)
        }
    }

    // MARK: - Fetch

    private static let activityFor = ["hiking": "walk", "foot": "walk",
                                      "bicycle": "bike", "mtb": "bike"]

    private func fetch(around origin: CLLocationCoordinate2D) async -> [Trail]? {
        let dLat = 0.30, dLon = 0.30 / max(0.2, cos(origin.latitude * .pi / 180))
        let bbox = String(format: "%.4f,%.4f,%.4f,%.4f",
                          origin.latitude - dLat, origin.longitude - dLon,
                          origin.latitude + dLat, origin.longitude + dLon)
        let query = """
        [out:json][timeout:25];
        (
          relation["route"~"^(hiking|foot|bicycle|mtb)$"]["name"](\(bbox));
        );
        out geom 250;
        """
        guard let raw = await request(query) else { return nil }   // nil = fetch failed
        return parse(raw)
    }

    /// Race every mirror; first to answer wins. Returns nil only when all fail.
    private func request(_ query: String) async -> [String: Any]? {
        let body = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlTrailQueryAllowed) ?? "")"
        return await withTaskGroup(of: [String: Any]?.self) { group in
            for endpoint in endpoints {
                group.addTask { await Self.hit(endpoint, body: body) }
            }
            for await result in group where result != nil {
                group.cancelAll()
                return result
            }
            return nil
        }
    }

    private static func hit(_ endpoint: String, body: String) async -> [String: Any]? {
        guard let url = URL(string: endpoint) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: .utf8)
        req.timeoutInterval = 20
        req.setValue("Chronicarum/localtrails (ODbL)", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    // MARK: - Parse geometry

    private func parse(_ raw: [String: Any]) -> [Trail] {
        guard let elements = raw["elements"] as? [[String: Any]] else { return [] }
        let bundledNames = Set(TrailData.all.map { $0.name.lowercased() })

        var seen = Set<String>()
        var ids = [String](), names = [String](), acts = [String](), tiers = [String]()
        var kms = [Double](), lats = [Double](), lons = [Double](), polys = [String]()
        var ascents = [Int](), urls = [String](), loops = [Int]()

        for el in elements {
            let tags = el["tags"] as? [String: String] ?? [:]
            guard let name = tags["name"]?.trimmingCharacters(in: .whitespaces), !name.isEmpty,
                  let route = tags["route"], let activity = Self.activityFor[route]
            else { continue }
            let lower = name.lowercased()
            if bundledNames.contains(lower) || seen.contains(lower) { continue }

            let points = assemble(el)
            guard points.count >= 2 else { continue }
            let km = Self.length(points)
            guard km >= 0.5, km <= 400 else { continue }
            let simplified = Self.simplify(points, epsilon: 0.0004, cap: 160)
            let mid = simplified[simplified.count / 2]

            seen.insert(lower)
            ids.append("localtrail/\(el["id"] as? Int ?? 0)")
            names.append(name)
            acts.append(activity)
            tiers.append(tags["network"] ?? "lwn")
            kms.append((km * 10).rounded() / 10)
            lats.append(mid.latitude); lons.append(mid.longitude)
            polys.append(TrailData.encodePolyline(simplified))
            ascents.append(Int(tags["ascent"] ?? "") ?? 0)
            urls.append(tags["website"] ?? tags["url"] ?? "")
            loops.append(tags["roundtrip"] == "yes" ? 1 : 0)
        }
        return TrailData.decode([
            "id": ids, "name": names, "activity": acts, "tier": tiers, "km": kms,
            "lat": lats, "lon": lons, "poly": polys,
            "ascent": ascents, "url": urls, "loop": loops,
        ])
    }

    /// Concatenate member way geometries, joining each to whichever end is nearer.
    private func assemble(_ el: [String: Any]) -> [CLLocationCoordinate2D] {
        guard let members = el["members"] as? [[String: Any]] else { return [] }
        var pts: [CLLocationCoordinate2D] = []
        for m in members where (m["type"] as? String) == "way" {
            guard let geom = m["geometry"] as? [[String: Any]] else { continue }
            var seg = geom.compactMap { g -> CLLocationCoordinate2D? in
                guard let la = g["lat"] as? Double, let lo = g["lon"] as? Double else { return nil }
                return CLLocationCoordinate2D(latitude: la, longitude: lo)
            }
            if let last = pts.last, let first = seg.first, let end = seg.last,
               Trail.haversineKm(last, first) > Trail.haversineKm(last, end) {
                seg.reverse()
            }
            pts.append(contentsOf: seg)
        }
        return pts
    }

    private static func length(_ p: [CLLocationCoordinate2D]) -> Double {
        guard p.count > 1 else { return 0 }
        return (1..<p.count).reduce(0.0) { $0 + Trail.haversineKm(p[$1 - 1], p[$1]) }
    }

    /// Ramer–Douglas–Peucker, then a uniform trim if still over the cap.
    private static func simplify(_ pts: [CLLocationCoordinate2D], epsilon: Double, cap: Int) -> [CLLocationCoordinate2D] {
        var out = rdp(pts, epsilon)
        if out.count > cap {
            let stride = Double(out.count) / Double(cap)
            var trimmed = (0..<cap).map { out[Int(Double($0) * stride)] }
            if let last = out.last, trimmed.last?.latitude != last.latitude { trimmed.append(last) }
            out = trimmed
        }
        return out
    }

    private static func rdp(_ pts: [CLLocationCoordinate2D], _ eps: Double) -> [CLLocationCoordinate2D] {
        guard pts.count > 2 else { return pts }
        var dmax = 0.0, index = 0
        let a = pts[0], b = pts[pts.count - 1]
        for i in 1..<(pts.count - 1) {
            let d = perpendicular(pts[i], a, b)
            if d > dmax { dmax = d; index = i }
        }
        if dmax > eps {
            let left = rdp(Array(pts[0...index]), eps)
            let right = rdp(Array(pts[index...]), eps)
            return left.dropLast() + right
        }
        return [a, b]
    }

    private static func perpendicular(_ p: CLLocationCoordinate2D, _ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dx = b.longitude - a.longitude, dy = b.latitude - a.latitude
        if dx == 0 && dy == 0 { return hypot(p.longitude - a.longitude, p.latitude - a.latitude) }
        let num = abs(dx * (a.latitude - p.latitude) - (a.longitude - p.longitude) * dy)
        return num / hypot(dx, dy)
    }

    // MARK: - Columnar helpers

    private static func columns(from trails: [Trail]) -> [String: Any] {
        [
            "id": trails.map(\.id), "name": trails.map(\.name),
            "activity": trails.map { $0.activity.rawValue }, "tier": trails.map(\.tier),
            "km": trails.map(\.km), "lat": trails.map(\.latitude), "lon": trails.map(\.longitude),
            "poly": trails.map { $0.segments.map(TrailData.encodePolyline).joined(separator: ";") },
            "ascent": trails.map(\.ascentM),
            "url": trails.map { $0.website?.absoluteString ?? "" },
            "loop": trails.map { $0.isLoop ? 1 : 0 },
        ]
    }
}

private extension CharacterSet {
    static let urlTrailQueryAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&+=?")
        return set
    }()
}

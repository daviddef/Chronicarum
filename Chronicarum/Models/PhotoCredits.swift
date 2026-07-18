import Foundation

/// Author and licence for one Wikimedia Commons photo.
///
/// Keys are single letters because this table covers ~22k photos and ships in the app
/// bundle; the long names would cost more than the data.
struct PhotoCredit: Decodable {
    let a: String?   // artist
    let l: String?   // licence, e.g. "CC BY-SA 4.0"

    var artist: String? { a?.isEmpty == false ? a : nil }
    var licence: String? { l?.isEmpty == false ? l : nil }

    /// One-line credit for display under a photo, e.g. "David Hawgood · CC BY-SA 2.0".
    /// Most of these licences require naming the author, so this is an obligation
    /// rather than a nicety.
    var summary: String? {
        switch (artist, licence) {
        case let (name?, lic?): return "\(name) · \(lic)"
        case let (name?, nil):  return name
        case let (nil, lic?):   return lic
        default:                return nil
        }
    }
}

/// Lookup from Commons filename to its credit, decoded from the bundled table.
enum PhotoCredits {

    /// Loaded on first use — a detail sheet needs it, the map never does, so the ~1.8 MB
    /// table stays off the launch path.
    private static let byFilename: [String: PhotoCredit] = {
        guard let url = Bundle.main.url(forResource: "attribution", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: PhotoCredit].self, from: data)
        else { return [:] }
        return table
    }()

    static func credit(for filename: String?) -> PhotoCredit? {
        guard let filename, !filename.isEmpty else { return nil }
        return byFilename[filename]
    }
}

extension Site {
    /// Author and licence for this site's photo, when known.
    var photoCredit: PhotoCredit? { PhotoCredits.credit(for: imageFile) }
}

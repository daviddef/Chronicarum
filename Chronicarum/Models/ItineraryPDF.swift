import Foundation
import UIKit

/// Renders a trip plan as a printable PDF worth keeping.
///
/// Drawn with `UIGraphicsPDFRenderer` and `NSAttributedString` rather than by rasterising
/// SwiftUI views: this needs real pagination — a fourteen-day trip does not fit on a page —
/// and selectable, searchable text at print resolution. Rendering views to images gives
/// neither.
///
/// **It is meant to look like something, not like a receipt.** A cover with the trip's best
/// photograph, gold rules, numbered stops, and a colour chip per era — because the printed
/// itinerary is the artefact that survives the trip, gets folded into a pocket and looked at
/// again afterwards.
///
/// The caveats are carried onto every page just as deliberately. Print is where a plan stops
/// being questioned: it leaves the app, and with it every bit of context about what is known
/// and what is guessed. Travel times are estimates and opening hours are unknown; the page
/// says so whatever else it is doing.
enum ItineraryPDF {

    private static let pageSize = CGSize(width: 595, height: 842)   // A4 at 72 dpi
    private static let margin: CGFloat = 48
    private static var contentWidth: CGFloat { pageSize.width - margin * 2 }

    private static let gold = UIColor(red: 0.788, green: 0.659, blue: 0.298, alpha: 1)
    private static let ink  = UIColor(red: 0.09, green: 0.082, blue: 0.071, alpha: 1)

    private enum Style {
        static let coverTitle = attributes(size: 40, weight: .bold, design: .serif,
                                           color: .white)
        static let coverSub   = attributes(size: 13, weight: .regular, color: UIColor(white: 0.85, alpha: 1))
        static let statValue  = attributes(size: 19, weight: .semibold, color: gold)
        static let statLabel  = attributes(size: 8, weight: .regular, color: UIColor(white: 0.75, alpha: 1))
        static let dayHeading = attributes(size: 17, weight: .bold, design: .serif)
        static let daySummary = attributes(size: 10, weight: .medium, color: gold.darkened())
        static let stopName   = attributes(size: 12.5, weight: .semibold)
        static let stopDetail = attributes(size: 9.5, weight: .regular, grey: 0.42)
        static let stopNumber = attributes(size: 11, weight: .bold, color: .white)
        static let leg        = attributes(size: 9, weight: .medium, grey: 0.5)
        static let chip       = attributes(size: 7.5, weight: .semibold, color: .white)
        static let warning    = attributes(size: 9, weight: .regular, color: UIColor(red: 0.65, green: 0.36, blue: 0.05, alpha: 1))
        static let footnote   = attributes(size: 7.5, weight: .regular, grey: 0.5)

        static func attributes(size: CGFloat,
                               weight: UIFont.Weight,
                               design: UIFontDescriptor.SystemDesign = .default,
                               grey: CGFloat = 0.05,
                               color: UIColor? = nil) -> [NSAttributedString.Key: Any] {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let font = base.fontDescriptor.withDesign(design)
                .map { UIFont(descriptor: $0, size: size) } ?? base
            return [.font: font,
                    .foregroundColor: color ?? UIColor(white: grey, alpha: 1)]
        }
    }

    // MARK: - Photographs

    /// Fetches the photographs the document will use, before any drawing starts.
    ///
    /// PDF rendering is synchronous, so the images have to be in hand first. This is
    /// deliberately best-effort and short-fused: a few seconds is worth a cover photograph,
    /// but nobody should be left staring at a spinner because Commons is slow, and the
    /// document is designed to look right with none of them — every stop falls back to a
    /// block of its era's colour.
    private static func photographs(for plan: TripPlan, limit: Int) -> [String: UIImage] {
        let wanted = plan.days.flatMap(\.stops).map(\.site)
            .filter { $0.imageURL() != nil }
            .prefix(limit)
        guard !wanted.isEmpty else { return [:] }

        var found: [String: UIImage] = [:]
        let lock = NSLock()
        let group = DispatchGroup()
        let session = URLSession(configuration: {
            let c = URLSessionConfiguration.ephemeral
            c.timeoutIntervalForRequest = 6
            return c
        }())

        for site in wanted {
            guard let url = site.imageURL(width: 500) else { continue }
            group.enter()
            session.dataTask(with: url) { data, _, _ in
                defer { group.leave() }
                guard let data, let image = UIImage(data: data) else { return }
                lock.lock(); found[site.id] = image; lock.unlock()
            }.resume()
        }
        // A hard ceiling on the whole batch, not just each request.
        _ = group.wait(timeout: .now() + 12)
        return found
    }

    // MARK: - Rendering

    static func render(_ plan: TripPlan, placeName: String?) -> Data {
        let photos = photographs(for: plan, limit: 24)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        return renderer.pdfData { context in
            var y: CGFloat = margin

            // ── Cover ─────────────────────────────────────────────────────
            context.beginPage()
            drawCover(context, plan: plan, placeName: placeName, photos: photos)

            context.beginPage()
            y = margin

            func ensureRoom(for height: CGFloat) {
                if y + height > pageSize.height - margin - 30 {
                    drawFooter(context, plan: plan)
                    context.beginPage()
                    y = margin
                }
            }

            func draw(_ text: String,
                      _ attributes: [NSAttributedString.Key: Any],
                      indent: CGFloat = 0,
                      spacing: CGFloat = 4) {
                let width = contentWidth - indent
                let string = NSAttributedString(string: text, attributes: attributes)
                let bounds = string.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                ensureRoom(for: bounds.height + spacing)
                string.draw(with: CGRect(x: margin + indent, y: y,
                                         width: width, height: bounds.height),
                            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y += bounds.height + spacing
            }

            for day in plan.days where !day.stops.isEmpty {
                ensureRoom(for: 110)

                // Day banner: a gold rule and the day in serif, so flicking through a
                // printed week finds the right page instantly.
                gold.setFill()
                UIBezierPath(rect: CGRect(x: margin, y: y, width: 46, height: 3)).fill()
                y += 12
                draw("Day \(day.index + 1) · \(day.weekdayName)", Style.dayHeading, spacing: 2)
                draw(day.summary.uppercased(), Style.daySummary, spacing: 12)

                for (index, stop) in day.stops.enumerated() {
                    let rowHeight: CGFloat = 62
                    ensureRoom(for: rowHeight + 8)
                    let top = y

                    // Photograph, or a block of the era's own colour.
                    let thumb = CGRect(x: margin, y: top, width: 78, height: rowHeight)
                    let clip = UIBezierPath(roundedRect: thumb, cornerRadius: 5)
                    context.cgContext.saveGState()
                    clip.addClip()
                    if let image = photos[stop.site.id] {
                        image.draw(in: aspectFill(image.size, in: thumb))
                    } else {
                        UIColor(hex: stop.site.era.color).setFill()
                        UIBezierPath(rect: thumb).fill()
                    }
                    context.cgContext.restoreGState()

                    // Numbered gold disc, so the order survives being read at a glance.
                    let disc = CGRect(x: margin + 62, y: top - 6, width: 22, height: 22)
                    gold.setFill()
                    UIBezierPath(ovalIn: disc).fill()
                    let number = NSAttributedString(string: "\(index + 1)", attributes: Style.stopNumber)
                    let numberSize = number.size()
                    number.draw(at: CGPoint(x: disc.midX - numberSize.width / 2,
                                            y: disc.midY - numberSize.height / 2))

                    // Text column
                    let textX = margin + 92
                    let textWidth = contentWidth - 92
                    var ty = top

                    let legText = "\(stop.travelMinutes) min \(stop.isWalk ? "walk" : (plan.mode == .transit ? "by transport" : "drive"))"
                    let leg = NSAttributedString(string: legText.uppercased(), attributes: Style.leg)
                    leg.draw(at: CGPoint(x: textX, y: ty))
                    ty += 12

                    let name = NSAttributedString(string: stop.site.name, attributes: Style.stopName)
                    let nameRect = name.boundingRect(
                        with: CGSize(width: textWidth, height: 34),
                        options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    name.draw(with: CGRect(x: textX, y: ty, width: textWidth, height: nameRect.height),
                              options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                    ty += min(nameRect.height, 30) + 2

                    var detail: [String] = []
                    if let duration = stop.site.visitDurationLabel { detail.append(duration) }
                    if !stop.site.location.isEmpty { detail.append(stop.site.location) }
                    if !detail.isEmpty {
                        NSAttributedString(string: detail.joined(separator: " · "),
                                           attributes: Style.stopDetail)
                            .draw(at: CGPoint(x: textX, y: ty))
                        ty += 12
                    }

                    // Era + first theme, as coloured chips.
                    var chipX = textX
                    if stop.site.era != .unknown {
                        chipX = drawChip(stop.site.era.displayName,
                                         fill: UIColor(hex: stop.site.era.color),
                                         at: CGPoint(x: chipX, y: ty))
                    }
                    if let theme = stop.site.themes.components.first {
                        _ = drawChip(theme.label, fill: gold.darkened(), at: CGPoint(x: chipX, y: ty))
                    }

                    y = top + rowHeight + 10
                }

                let unreachable = day.unreachableStops
                if !unreachable.isEmpty {
                    draw("No route to: \(unreachable.map(\.name).joined(separator: ", ")). "
                         + "You would need a boat, a lift, or another way there.",
                         Style.warning, indent: 4, spacing: 6)
                }

                let closed = day.commonlyClosedStops()
                if !closed.isEmpty {
                    draw("Commonly closed on a \(day.weekdayName): "
                         + "\(closed.map(\.name).joined(separator: ", ")). Worth checking.",
                         Style.warning, indent: 4, spacing: 14)
                } else {
                    y += 10
                }
            }

            drawFooter(context, plan: plan)
        }
    }

    // MARK: - Cover

    private static func drawCover(_ context: UIGraphicsPDFRendererContext,
                                  plan: TripPlan,
                                  placeName: String?,
                                  photos: [String: UIImage]) {
        let full = CGRect(origin: .zero, size: pageSize)

        // The best photograph in the trip, as a full-bleed background.
        let hero = plan.days.flatMap(\.stops).map(\.site)
            .sorted { $0.significance > $1.significance }
            .compactMap { photos[$0.id] }
            .first

        if let hero {
            hero.draw(in: aspectFill(hero.size, in: full))
            // Darkened so the type stays readable over any photograph.
            UIColor.black.withAlphaComponent(0.55).setFill()
            UIBezierPath(rect: full).fill()
        } else {
            ink.setFill()
            UIBezierPath(rect: full).fill()
        }

        var y: CGFloat = 250
        gold.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: y, width: 64, height: 4)).fill()
        y += 24

        let title = placeName ?? "Your itinerary"
        let heading = NSAttributedString(string: title, attributes: Style.coverTitle)
        let headingRect = heading.boundingRect(
            with: CGSize(width: contentWidth, height: 260),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        heading.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: headingRect.height),
                     options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        y += headingRect.height + 10

        let dayCount = plan.days.filter { !$0.stops.isEmpty }.count
        var subtitle = "\(dayCount) \(dayCount == 1 ? "day" : "days") · "
            + plan.startDate.formatted(.dateTime.day().month(.wide).year())
        if !plan.themes.isEmpty {
            subtitle += "\n" + plan.themes.components.map(\.label).formatted(.list(type: .and))
        }
        NSAttributedString(string: subtitle, attributes: Style.coverSub)
            .draw(with: CGRect(x: margin, y: y, width: contentWidth, height: 60),
                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

        // A stats strip — the shape of the trip in four numbers.
        let totalMinutes = plan.days.reduce(0) { $0 + $1.totalMinutes }
        let stats: [(String, String)] = [
            ("\(plan.totalStops)", "PLACES"),
            ("\(dayCount)", dayCount == 1 ? "DAY" : "DAYS"),
            ("\(totalMinutes / 60)h", "IN TOTAL"),
            (plan.mode.label.uppercased(), "GETTING AROUND"),
        ]
        var x = margin
        let statY = pageSize.height - 150
        for (value, label) in stats {
            NSAttributedString(string: value, attributes: Style.statValue)
                .draw(at: CGPoint(x: x, y: statY))
            NSAttributedString(string: label, attributes: Style.statLabel)
                .draw(at: CGPoint(x: x, y: statY + 24))
            x += 124
        }

        gold.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: pageSize.height - 92, width: contentWidth, height: 1)).fill()
        NSAttributedString(string: "CHRONICARUM",
                           attributes: Style.attributes(size: 10, weight: .bold, color: gold))
            .draw(at: CGPoint(x: margin, y: pageSize.height - 80))
    }

    // MARK: - Bits and pieces

    /// Fills the box while keeping the image's proportions — a squashed castle looks wrong
    /// in a way a cropped one does not.
    private static func aspectFill(_ size: CGSize, in rect: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return rect }
        let scale = max(rect.width / size.width, rect.height / size.height)
        let scaled = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: rect.midX - scaled.width / 2,
                      y: rect.midY - scaled.height / 2,
                      width: scaled.width, height: scaled.height)
    }

    /// Draws a rounded colour chip and returns where the next one should start.
    @discardableResult
    private static func drawChip(_ text: String, fill: UIColor, at point: CGPoint) -> CGFloat {
        let string = NSAttributedString(string: text.uppercased(), attributes: Style.chip)
        let size = string.size()
        let box = CGRect(x: point.x, y: point.y, width: size.width + 12, height: size.height + 5)
        fill.setFill()
        UIBezierPath(roundedRect: box, cornerRadius: box.height / 2).fill()
        string.draw(at: CGPoint(x: box.minX + 6, y: box.minY + 2.5))
        return box.maxX + 5
    }

    /// Both caveats, on every page. See the type comment: print is where a plan stops
    /// being questioned.
    private static func drawFooter(_ context: UIGraphicsPDFRendererContext, plan: TripPlan) {
        gold.withAlphaComponent(0.5).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: pageSize.height - margin - 26,
                                  width: contentWidth, height: 0.7)).fill()
        let text = plan.travelCaveat
            + " Opening hours are not known for any site — no heritage register records "
            + "them — so any closures noted are what's typical for that kind of place, not "
            + "fact. Check before you set out."
        let string = NSAttributedString(string: text, attributes: Style.footnote)
        let height: CGFloat = 26
        string.draw(with: CGRect(x: margin, y: pageSize.height - margin - height + 4,
                                 width: contentWidth, height: height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    /// Written to a temp file so it can be shared with a sensible filename rather than
    /// "Untitled".
    static func writeTemporaryFile(_ plan: TripPlan, placeName: String?) -> URL? {
        let data = render(plan, placeName: placeName)
        let stamp = plan.startDate.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
            .replacingOccurrences(of: "/", with: "-")
        let name = placeName.map { "Chronicarum — \($0), \(stamp).pdf" }
            ?? "Chronicarum — \(stamp).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private extension UIColor {
    /// Mirrors `Color(hex:)` so the printed page uses the same era palette as the map.
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(red: CGFloat((int >> 16) & 0xFF) / 255,
                  green: CGFloat((int >> 8) & 0xFF) / 255,
                  blue: CGFloat(int & 0xFF) / 255,
                  alpha: 1)
    }

    /// A darker sibling, for chips and rules that need to sit under white text.
    func darkened(by amount: CGFloat = 0.22) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: s, brightness: max(0, b - amount), alpha: a)
    }
}

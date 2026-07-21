import Foundation
import UIKit

/// Renders a trip plan as a printable PDF.
///
/// Drawn with `UIGraphicsPDFRenderer` and `NSAttributedString` rather than by rasterising
/// SwiftUI views: this needs real pagination — a fourteen-day trip does not fit on a page
/// — and selectable, searchable text at print resolution. Rendering views to images gives
/// neither.
///
/// The caveats are carried onto the page deliberately. A printed itinerary is the artefact
/// most likely to be trusted without question and least likely to be re-checked, since it
/// leaves the app behind. Travel times are estimates and opening hours are unknown; both
/// say so in print.
enum ItineraryPDF {

    private static let pageSize = CGSize(width: 595, height: 842)   // A4 at 72 dpi
    private static let margin: CGFloat = 48
    private static var contentWidth: CGFloat { pageSize.width - margin * 2 }

    private enum Style {
        static let title = attributes(size: 22, weight: .bold)
        static let subtitle = attributes(size: 11, weight: .regular, grey: 0.35)
        static let dayHeading = attributes(size: 14, weight: .semibold)
        static let daySummary = attributes(size: 10, weight: .regular, grey: 0.4)
        static let stopName = attributes(size: 11.5, weight: .medium)
        static let stopDetail = attributes(size: 9.5, weight: .regular, grey: 0.4)
        static let leg = attributes(size: 9, weight: .regular, grey: 0.45)
        static let warning = attributes(size: 9, weight: .regular, grey: 0.3)
        static let footnote = attributes(size: 8, weight: .regular, grey: 0.45)

        static func attributes(size: CGFloat,
                               weight: UIFont.Weight,
                               grey: CGFloat = 0) -> [NSAttributedString.Key: Any] {
            [.font: UIFont.systemFont(ofSize: size, weight: weight),
             .foregroundColor: UIColor(white: grey, alpha: 1)]
        }
    }

    static func render(_ plan: TripPlan, placeName: String?) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        return renderer.pdfData { context in
            var y: CGFloat = margin
            context.beginPage()

            /// Starts a new page when the next block would run past the bottom margin.
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

            // ── Heading ───────────────────────────────────────────────────
            let dayCount = plan.days.count
            draw("Chronicarum", Style.title, spacing: 2)
            let where_ = placeName.map { " from \($0)" } ?? ""
            var subtitle = "\(dayCount) \(dayCount == 1 ? "day" : "days")\(where_), "
                + "starting \(plan.startDate.formatted(.dateTime.day().month(.wide).year()))"
            if !plan.themes.isEmpty {
                subtitle += " · " + plan.themes.components.map(\.label)
                    .formatted(.list(type: .and))
            }
            draw(subtitle, Style.subtitle, spacing: 18)

            // ── Days ──────────────────────────────────────────────────────
            for day in plan.days where !day.stops.isEmpty {
                ensureRoom(for: 60)
                draw("Day \(day.index + 1) · \(day.weekdayName)", Style.dayHeading, spacing: 1)
                draw(day.summary, Style.daySummary, spacing: 8)

                for stop in day.stops {
                    let leg = stop.isWalk
                        ? "\(stop.travelMinutes) min walk"
                        : "\(stop.travelMinutes) min drive"
                    draw(leg, Style.leg, indent: 4, spacing: 2)
                    draw(stop.site.name, Style.stopName, indent: 16, spacing: 1)

                    var detail: [String] = []
                    if let duration = stop.site.visitDurationLabel { detail.append(duration) }
                    if let theme = stop.site.themes.components.first { detail.append(theme.label) }
                    if !stop.site.location.isEmpty { detail.append(stop.site.location) }
                    if !detail.isEmpty {
                        draw(detail.joined(separator: " · "), Style.stopDetail,
                             indent: 16, spacing: 8)
                    }
                }

                let unreachable = day.unreachableStops
                if !unreachable.isEmpty {
                    let names = unreachable.map(\.name).joined(separator: ", ")
                    draw("No road route to: \(names). Likely an island — you would need a "
                         + "boat, and the times above do not include the crossing.",
                         Style.warning, indent: 4, spacing: 6)
                }

                let closed = day.commonlyClosedStops()
                if !closed.isEmpty {
                    let names = closed.map(\.name).joined(separator: ", ")
                    draw("Commonly closed on a \(day.weekdayName): \(names). Worth checking.",
                         Style.warning, indent: 4, spacing: 14)
                } else {
                    y += 8
                }
            }

            drawFooter(context, plan: plan)
        }
    }

    /// Both caveats, on every page. See the type comment: print is where a plan stops
    /// being questioned.
    private static func drawFooter(_ context: UIGraphicsPDFRendererContext, plan: TripPlan) {
        let text = plan.travelCaveat
            + " Opening hours are not known for any site — no heritage register records "
            + "them — so any closures noted are what's typical for that kind of place, not "
            + "fact. Check before you set out."
        let string = NSAttributedString(string: text, attributes: Style.footnote)
        let height: CGFloat = 28
        string.draw(with: CGRect(x: margin, y: pageSize.height - margin - height + 8,
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

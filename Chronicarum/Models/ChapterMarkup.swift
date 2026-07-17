import Foundation

/// Renders the small HTML subset used by chapter bodies into an `AttributedString`.
///
/// Chapter bodies only ever use `<p>` and `<strong>` (plus `<em>`/`<br>`, handled here
/// for safety). That makes both heavyweight options a bad trade: a `WKWebView` costs a
/// web process per chapter and needs manual height syncing, while `NSAttributedString`'s
/// HTML importer bakes its own fonts and colours into the output, overriding Dynamic Type
/// and dark mode. Emitting semantic `inlinePresentationIntent` instead leaves styling to
/// SwiftUI.
///
/// Unknown tags are dropped but their text is kept, so unexpected markup degrades to
/// readable prose rather than showing literal angle brackets.
enum ChapterMarkup {

    static func attributedString(from html: String) -> AttributedString {
        var output = AttributedString()
        var pending = ""
        var boldDepth = 0
        var italicDepth = 0

        func flushText() {
            guard !pending.isEmpty else { return }
            var run = AttributedString(decodeEntities(collapseWhitespace(pending)))
            var intent: InlinePresentationIntent = []
            if boldDepth > 0 { intent.insert(.stronglyEmphasized) }
            if italicDepth > 0 { intent.insert(.emphasized) }
            if !intent.isEmpty { run.inlinePresentationIntent = intent }
            output.append(run)
            pending = ""
        }

        var index = html.startIndex
        while index < html.endIndex {
            let character = html[index]

            // Only treat "<" as a tag when what follows actually looks like one: a name
            // or "/", closed by ">" with no "<" in between. Otherwise a bare "<" (as in
            // "5 < 6") would swallow everything up to the next real tag's ">".
            guard character == "<",
                  case let rest = html[html.index(after: index)...],
                  let first = rest.first, first.isLetter || first == "/",
                  let tagEnd = rest.firstIndex(of: ">"),
                  !rest[rest.startIndex..<tagEnd].contains("<")
            else {
                pending.append(character)
                index = html.index(after: index)
                continue
            }

            flushText()
            let name = tagName(in: html[html.index(after: index)..<tagEnd])
            switch name {
            case "strong", "b":  boldDepth += 1
            case "/strong", "/b": boldDepth = max(0, boldDepth - 1)
            case "em", "i":      italicDepth += 1
            case "/em", "/i":    italicDepth = max(0, italicDepth - 1)
            case "/p":           output.append(AttributedString("\n\n"))
            case "br", "br/":    output.append(AttributedString("\n"))
            default:             break   // <p> and anything unrecognised
            }
            index = html.index(after: tagEnd)
        }
        flushText()

        return trimmingEdgeWhitespace(output)
    }

    /// `<p class="x">` -> `p`, `</p>` -> `/p`
    private static func tagName(in raw: Substring) -> String {
        let name = raw.prefix { !$0.isWhitespace }
        return name.lowercased()
    }

    /// HTML collapses runs of whitespace to a single space; source strings may be
    /// wrapped or indented. Edge whitespace must survive as a single space — it's what
    /// separates a text run from an adjacent tag's run ("by " + "<strong>Vespasian").
    private static func collapseWhitespace(_ string: String) -> String {
        let core = string.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !core.isEmpty else { return string.isEmpty ? "" : " " }
        let leading  = string.first?.isWhitespace == true ? " " : ""
        let trailing = string.last?.isWhitespace  == true ? " " : ""
        return leading + core + trailing
    }

    private static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = string
        // "&amp;" last so "&amp;lt;" doesn't turn into "<".
        for (entity, replacement) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
                                      ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", "\u{00A0}"),
                                      ("&mdash;", "—"), ("&ndash;", "–"), ("&amp;", "&")] {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }

    /// Trailing `</p>` always emits a blank line; leading indentation is common in
    /// source strings. Neither should reach the view.
    private static func trimmingEdgeWhitespace(_ attributed: AttributedString) -> AttributedString {
        var result = attributed
        while let last = result.characters.last, last.isWhitespace {
            result.removeSubrange(result.index(beforeCharacter: result.endIndex)..<result.endIndex)
        }
        while let first = result.characters.first, first.isWhitespace {
            result.removeSubrange(result.startIndex..<result.index(afterCharacter: result.startIndex))
        }
        return result
    }
}

extension Chapter {
    /// Chapter body rendered for SwiftUI `Text`.
    var attributedBody: AttributedString {
        ChapterMarkup.attributedString(from: body)
    }
}

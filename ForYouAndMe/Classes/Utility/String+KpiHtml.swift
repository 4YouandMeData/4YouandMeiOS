//
//  String+KpiHtml.swift
//  ForYouAndMe
//
//  FUAM-4315 (D14): the KPI widget body is Redcarpet HTML. This small tag scanner turns it into
//  attributed text with the same behaviour as Android's `kpiAnnotatedString()`: bold and italic
//  runs, line breaks, curly quotes; every other tag dropped. The system HTML importer is avoided
//  on purpose (main-thread WebKit, unpredictable fonts and margins).
//

import UIKit

extension String {

    func kpiAttributedString(regular: UIFont,
                             bold: UIFont,
                             italic: UIFont,
                             color: UIColor,
                             lineHeightMultiple: CGFloat) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
        paragraphStyle.paragraphSpacing = 0
        let boldItalic = bold.withTraits(.traitItalic) ?? bold

        let result = NSMutableAttributedString()
        for run in KpiHtmlScanner.scan(self) {
            let font: UIFont
            switch (run.bold, run.italic) {
            case (true, true): font = boldItalic
            case (true, false): font = bold
            case (false, true): font = italic
            case (false, false): font = regular
            }
            result.append(NSAttributedString(string: run.text, attributes: [.font: font,
                                                                             .foregroundColor: color,
                                                                             .paragraphStyle: paragraphStyle]))
        }
        return result
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(self.fontDescriptor.symbolicTraits.union(traits)) else {
            return nil
        }
        return UIFont(descriptor: descriptor, size: self.pointSize)
    }
}

struct KpiHtmlRun: Equatable {
    let text: String
    let bold: Bool
    let italic: Bool
}

enum KpiHtmlScanner {

    private static let tagRegex = try? NSRegularExpression(pattern: "<\\s*(/?)\\s*([a-zA-Z][a-zA-Z0-9]*)[^>]*>")

    private struct Glyph {
        let character: Character
        let bold: Bool
        let italic: Bool
    }

    static func scan(_ html: String) -> [KpiHtmlRun] {
        var glyphs: [Glyph] = []
        var boldDepth = 0
        var italicDepth = 0
        var paragraphClosed = false

        func append(_ character: Character) {
            glyphs.append(Glyph(character: character, bold: boldDepth > 0, italic: italicDepth > 0))
        }
        func appendText(_ text: String) {
            for character in text {
                if character.isWhitespace {
                    // Collapse runs; never start a line with a space.
                    guard let last = glyphs.last?.character, last != " ", last != "\n" else { continue }
                    append(" ")
                } else {
                    append(character)
                }
            }
        }
        func appendNewline() {
            while glyphs.last?.character == " " { glyphs.removeLast() }
            append("\n")
        }

        let source = html as NSString
        var cursor = 0
        let matches = self.tagRegex?.matches(in: html, range: NSRange(location: 0, length: source.length)) ?? []
        for match in matches {
            appendText(self.decodeEntities(source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))))
            cursor = match.range.location + match.range.length

            let isClosing = source.substring(with: match.range(at: 1)) == "/"
            let tag = source.substring(with: match.range(at: 2)).lowercased()
            switch tag {
            case "strong", "b": boldDepth = max(0, boldDepth + (isClosing ? -1 : 1))
            case "em", "i": italicDepth = max(0, italicDepth + (isClosing ? -1 : 1))
            case "br": appendNewline()
            case "q": append(isClosing ? "\u{201D}" : "\u{201C}")
            case "p":
                if isClosing {
                    paragraphClosed = true
                } else {
                    if paragraphClosed { appendNewline() }
                    paragraphClosed = false
                }
            default: break
            }
        }
        appendText(self.decodeEntities(source.substring(from: cursor)))

        // Trim leading and trailing whitespace (spaces never lead, see appendText).
        while let first = glyphs.first, first.character == "\n" { glyphs.removeFirst() }
        while let last = glyphs.last, last.character == " " || last.character == "\n" { glyphs.removeLast() }

        // Group consecutive glyphs with the same style into runs.
        var runs: [KpiHtmlRun] = []
        for glyph in glyphs {
            if let last = runs.last, last.bold == glyph.bold, last.italic == glyph.italic {
                runs[runs.count - 1] = KpiHtmlRun(text: last.text + String(glyph.character), bold: last.bold, italic: last.italic)
            } else {
                runs.append(KpiHtmlRun(text: String(glyph.character), bold: glyph.bold, italic: glyph.italic))
            }
        }
        return runs
    }

    private static func decodeEntities(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&") // last, so "&amp;lt;" stays "&lt;"
    }
}

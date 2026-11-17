import CoreText
import Foundation
import SwiftUI

/// The bundled typefaces, built straight from their files, so nothing has to be registered with the system.
enum Typeface {
    /// Source Serif 4 italic at weight 400, 17.5 points, with old-style figures.
    static let write = Font(writeFont)
    /// The spacing that brings a line of `write` to 28 points.
    static let writeLineSpacing = 28 - lineHeight(of: writeFont)

    private static let writeFont = sourceSerifItalic(size: 17.5)

    private static func sourceSerifItalic(size: CGFloat) -> CTFont {
        guard
            let url = Bundle.module.url(
                forResource: "SourceSerif4-Italic", withExtension: "ttf", subdirectory: "Fonts"),
            let file = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first
        else {
            fatalError("Fonts/SourceSerif4-Italic.ttf is missing from NoteUI's bundle or isn't a font")
        }
        let attributes: [CFString: Any] = [
            kCTFontVariationAttribute: [axis("wght"): 400, axis("opsz"): size],
            kCTFontFeatureSettingsAttribute: [
                [kCTFontOpenTypeFeatureTag: "onum", kCTFontOpenTypeFeatureValue: 1]
            ],
        ]
        return CTFontCreateWithFontDescriptor(
            CTFontDescriptorCreateCopyWithAttributes(file, attributes as CFDictionary), size, nil)
    }

    /// A variation axis's identifier: its four-letter tag read as a big-endian number.
    private static func axis(_ tag: String) -> Int {
        tag.utf8.reduce(0) { $0 << 8 | Int($1) }
    }

    private static func lineHeight(of font: CTFont) -> CGFloat {
        CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }
}

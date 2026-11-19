import CoreText
import Foundation
import SwiftUI

/// The bundled typefaces, built straight from their files, so nothing has to be registered with the system.
enum Typeface {
    /// Source Serif 4 italic at weight 400, 17.5 points, with old-style figures.
    static let write = Font(writeFont)
    /// The spacing that brings a line of `write` to 28 points.
    static let writeLineSpacing = 28 - lineHeight(of: writeFont)
    /// Bodoni Moda italic at weight 400, 28 points, for the `Unsorted` drawer.
    static let unsorted = Font(font("BodoniModa-Italic", size: 28))

    private static let writeFont = font("SourceSerif4-Italic", size: 17.5)

    /// The bundled variable font `Fonts/<file>.ttf` at weight 400, with its optical size set to `size`, and old-style
    /// figures.
    private static func font(_ file: String, size: CGFloat) -> CTFont {
        guard
            let url = Bundle.module.url(forResource: file, withExtension: "ttf", subdirectory: "Fonts"),
            let face = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first
        else {
            fatalError("Fonts/\(file).ttf is missing from NoteUI's bundle or isn't a font")
        }
        let attributes: [CFString: Any] = [
            kCTFontVariationAttribute: [axis("wght"): 400, axis("opsz"): size],
            kCTFontFeatureSettingsAttribute: [
                [kCTFontOpenTypeFeatureTag: "onum", kCTFontOpenTypeFeatureValue: 1]
            ],
        ]
        return CTFontCreateWithFontDescriptor(
            CTFontDescriptorCreateCopyWithAttributes(face, attributes as CFDictionary), size, nil)
    }

    /// A variation axis's identifier: its four-letter tag read as a big-endian number.
    private static func axis(_ tag: String) -> Int {
        tag.utf8.reduce(0) { $0 << 8 | Int($1) }
    }

    private static func lineHeight(of font: CTFont) -> CGFloat {
        CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }
}

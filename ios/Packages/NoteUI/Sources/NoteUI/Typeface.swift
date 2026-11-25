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
    /// Source Serif 4 italic at weight 400, 17 points: a note's first words in the notes list.
    static let preview = Font(font("SourceSerif4-Italic", size: 17))
    /// Source Serif 4 at weight 400, 13 points: the notes list's date column.
    static let date = Font(font("SourceSerif4-Roman", size: 13))
    /// Source Serif 4 at weight 600, 10.5 points: the drawer label under a note in a list.
    static let label = Font(font("SourceSerif4-Roman", weight: 600, size: 10.5))
    /// Source Serif 4 at weight 500, 17 points: a saved note's title in the notes list.
    static let title = Font(font("SourceSerif4-Roman", weight: 500, size: 17))
    /// Source Serif 4 at weight 400, 14 points, with old-style figures: a drawer's note count.
    static let count = Font(font("SourceSerif4-Roman", size: 14))
    /// Bodoni Moda at weight 500, 26 points: the save sheet's title field.
    static let titleField = Font(font("BodoniModa-Roman", weight: 500, size: 26))
    /// Source Serif 4 italic at weight 400, 26 points: the title field's placeholder.
    static let titlePlaceholder = Font(font("SourceSerif4-Italic", size: 26))
    /// Source Serif 4 at weight 500, 17.5 points: the save sheet's save button.
    static let saveButton = Font(font("SourceSerif4-Roman", weight: 500, size: 17.5))

    /// Source Serif 4 italic at weight 400, 15.5 points: the words in a message pill or bubble.
    static let message = Font(font("SourceSerif4-Italic", size: 15.5))

    private static let writeFont = font("SourceSerif4-Italic", size: 17.5)

    /// The bundled variable font `Fonts/<file>.ttf` at `weight`, with its optical size set to `size`, and old-style
    /// figures.
    private static func font(_ file: String, weight: Int = 400, size: CGFloat) -> CTFont {
        guard
            let url = Bundle.module.url(forResource: file, withExtension: "ttf", subdirectory: "Fonts"),
            let face = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first
        else {
            fatalError("Fonts/\(file).ttf is missing from NoteUI's bundle or isn't a font")
        }
        let attributes: [CFString: Any] = [
            kCTFontVariationAttribute: [axis("wght"): weight, axis("opsz"): size],
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

import AppKit

enum MenuBarStyle {
    static func usageTitle(_ percentage: String?) -> NSAttributedString {
        guard let percentage else { return NSAttributedString(string: "") }
        return NSAttributedString(
            string: "\u{2009}\(percentage)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .baselineOffset: 0.5
            ]
        )
    }
}

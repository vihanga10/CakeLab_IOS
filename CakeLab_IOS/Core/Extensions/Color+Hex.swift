import SwiftUI
import Foundation
import UIKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }

    static var cakeBackground: Color {
        adaptive(light: "FFFFFF", dark: "12100F")
    }

    static var cakeSurface: Color {
        adaptive(light: "FFFFFF", dark: "1D1A17")
    }

    static var cakeInsetSurface: Color {
        adaptive(light: "F8F6F3", dark: "26211D")
    }

    static var cakePrimaryText: Color {
        adaptive(light: "1A1A1A", dark: "F5EFE8")
    }

    static var cakeSecondaryText: Color {
        adaptive(light: "676767", dark: "C6B9AD")
    }

    static var cakeTertiaryText: Color {
        adaptive(light: "7B7B7B", dark: "A99A8D")
    }

    static var cakeStroke: Color {
        adaptive(light: "000000", dark: "F1E8DE").opacity(0.08)
    }

    static var cakeIconTile: Color {
        adaptive(light: "EFEAE2", dark: "332C25")
    }

    static var cakeAvatarRing: Color {
        adaptive(light: "FFFFFF", dark: "241F1B")
    }

    private static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traitCollection in
            UIColor(cakeHex: traitCollection.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(cakeHex: String) {
        let hex = cakeHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1
        )
    }
}

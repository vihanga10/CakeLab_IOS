import SwiftUI

// MARK: - Urbanist font helpers
// Usage examples:
//   .font(.urbanist(.bold, size: 26))
//   .font(.urbanistBold(26))
//   .font(.urbanistRegular(14))

extension Font {

    enum UrbanistWeight: String {
        case regular   = "Urbanist-Regular"
        case medium    = "Urbanist-Medium"
        case semiBold  = "Urbanist-SemiBold"
        case bold      = "Urbanist-Bold"
    }

    static func urbanist(_ weight: UrbanistWeight, size: CGFloat) -> Font {
        .custom(weight.rawValue, size: size)
    }

    // Convenience shorthands
    static func urbanistBold(_ size: CGFloat)     -> Font { urbanist(.bold,     size: size) }
    static func urbanistSemiBold(_ size: CGFloat) -> Font { urbanist(.semiBold, size: size) }
    static func urbanistMedium(_ size: CGFloat)   -> Font { urbanist(.medium,   size: size) }
    static func urbanistRegular(_ size: CGFloat)  -> Font { urbanist(.regular,  size: size) }
}

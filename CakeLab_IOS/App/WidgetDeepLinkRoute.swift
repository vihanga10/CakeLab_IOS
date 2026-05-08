import Foundation

// Represents all possible deep link destinations that a widget tap can navigate to
enum WidgetDeepLinkRoute: Equatable {
    case customerStatus       // Customer's current order status screen
    case customerActiveList   // Customer's list of active orders
    case bakerStatus          // Baker's current order status screen
    case bakerMatching        // Baker's order matching/discovery screen

    // Parses a widget deep link URL into a route
    // Expected URL format: cakelab://widget/<role>/<target>
    // Example: cakelab://widget/customer/status → .customerStatus
    init?(url: URL) {
        // Only handle URLs with the "cakelab" custom scheme
        guard url.scheme?.lowercased() == "cakelab" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }

        // Must come from the "widget" host and have at least role + target path segments
        guard url.host?.lowercased() == "widget", parts.count >= 2 else {
            return nil
        }

        let role = parts[0].lowercased()     // e.g. "customer" or "baker"
        let target = parts[1].lowercased()   // e.g. "status", "active-list", "matching"

        // Map role + target combination to the correct route
        switch (role, target) {
        case ("customer", "status"):
            self = .customerStatus
        case ("customer", "active-list"):
            self = .customerActiveList
        case ("baker", "status"):
            self = .bakerStatus
        case ("baker", "matching"):
            self = .bakerMatching
        default:
            return nil   // Unrecognized URL — ignore the deep link
        }
    }
}

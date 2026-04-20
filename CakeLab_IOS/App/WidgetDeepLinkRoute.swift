import Foundation

enum WidgetDeepLinkRoute: Equatable {
    case customerStatus
    case customerActiveList
    case bakerStatus
    case bakerMatching

    init?(url: URL) {
        guard url.scheme?.lowercased() == "cakelab" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }

        guard url.host?.lowercased() == "widget", parts.count >= 2 else {
            return nil
        }

        let role = parts[0].lowercased()
        let target = parts[1].lowercased()

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
            return nil
        }
    }
}

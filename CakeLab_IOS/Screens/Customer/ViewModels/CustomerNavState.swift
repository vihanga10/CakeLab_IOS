import Foundation
import Combine

// MARK: - CustomerNavState
/// Singleton navigation state for the customer tab bar.
/// All views reference this directly — no environment propagation needed,
/// so it works correctly through NavigationStack pushes.
final class CustomerNavState: ObservableObject {
    static let shared = CustomerNavState()

    @Published var selectedTab: Int = 0
    @Published var depth: Int = 0
    /// Per-tab reset counters — incrementing forces a NavigationStack to recreate (pops to root).
    @Published var tabResetIDs: [Int: Int] = [0: 0, 1: 0, 2: 0, 3: 0]

    var isOnSubScreen: Bool { depth > 0 }

    private init() {}

    func navigateTo(_ tag: Int) {
        tabResetIDs[tag, default: 0] += 1
        selectedTab = tag
    }

    func reset() {
        selectedTab = 0
        depth = 0
        tabResetIDs = [0: 0, 1: 0, 2: 0, 3: 0]
    }
}

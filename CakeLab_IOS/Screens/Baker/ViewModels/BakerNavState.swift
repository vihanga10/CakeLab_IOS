import Foundation
import Combine

// MARK: - BakerNavState
/// Shared navigation state for the baker tab bar. Singleton so any screen can
/// trigger a tab switch or track push depth without threading through bindings.
final class BakerNavState: ObservableObject {
    static let shared = BakerNavState()

    @Published var selectedTab: Int = 0
    @Published var depth: Int = 0

    var isOnSubScreen: Bool { depth > 0 }

    private init() {}

    func navigateTo(_ tag: Int) {
        selectedTab = tag
    }

    func reset() {
        selectedTab = 0
        depth = 0
    }
}

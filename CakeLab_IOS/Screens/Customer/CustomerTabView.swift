import SwiftUI
import Combine

// MARK: - Singleton nav state
// All views reference CustomerNavState.shared directly — no environment
// propagation needed, so it works correctly through NavigationStack pushes.
final class CustomerNavState: ObservableObject {
    static let shared = CustomerNavState()
    @Published var selectedTab: Int = 0
    @Published var depth: Int = 0
    // Per-tab reset counters — incrementing a tab's counter forces its
    // NavigationStack to recreate (pops to root), even if selectedTab doesn't change.
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

// MARK: - All-unselected tab bar embedded inside every sub-screen
struct CustomerSubScreenTabBar: View {
    let onSelectTab: (Int) -> Void

    private let tabs: [(icon: String, tag: Int)] = [
        ("house.fill",          0),
        ("birthday.cake.fill",  1),
        ("list.clipboard.fill", 2),
        ("person.fill",         3)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.tag) { index, tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        onSelectTab(tab.tag)
                    }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color(red: 0.9, green: 0.9, blue: 0.9).opacity(0.45))
                        )
                }
                .buttonStyle(.plain)
                if index < tabs.count - 1 { Spacer(minLength: 12) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 68)
        .background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.94, green: 0.94, blue: 0.94).opacity(0.75),
                        Color(red: 0.92, green: 0.92, blue: 0.92).opacity(0.85)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Color(red: 0.93, green: 0.93, blue: 0.93).opacity(0.5)
                Color(red: 0.96, green: 0.96, blue: 0.96).opacity(0.2)
            }
        )
        .cornerRadius(26)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.6),
                            Color(red: 0.88, green: 0.88, blue: 0.88).opacity(0.3),
                            Color(red: 0.9,  green: 0.9,  blue: 0.9 ).opacity(0.4)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 18)
        .padding(.bottom, 1)
    }
}

// MARK: - ViewModifier applied to every sub-screen
// Embeds the tab bar directly inside the pushed view via safeAreaInset,
// and tracks navigation depth on the singleton so CustomerTabBar reflects
// the unselected state while on a sub-screen.
struct CustomerSubScreenModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            // Content first — painted underneath
            content
                .onAppear  { CustomerNavState.shared.depth += 1 }
                .onDisappear { CustomerNavState.shared.depth = max(0, CustomerNavState.shared.depth - 1) }

            // Tab bar last — always on top, always receives touches
            CustomerSubScreenTabBar { tag in
                CustomerNavState.shared.navigateTo(tag)
                dismiss()
            }
        }
    }
}

extension View {
    func asCustomerSubScreen() -> some View {
        modifier(CustomerSubScreenModifier())
    }
}

// MARK: - Customer Tab View
@MainActor
struct CustomerTabView: View {
    let user: AppUser
    @Binding var widgetRoute: WidgetDeepLinkRoute?
    @State private var notificationsShown = false
    @ObservedObject private var navState = CustomerNavState.shared
    @EnvironmentObject var notificationManager: NotificationManager

    private var selectedTabBinding: Binding<Int> {
        Binding(
            get: { CustomerNavState.shared.selectedTab },
            set: { CustomerNavState.shared.selectedTab = $0 }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch navState.selectedTab {
                case 0: CustomerHomeView(user: user, selectedTab: selectedTabBinding)
                    .id(navState.tabResetIDs[0])
                case 1: CustomerBidsView(user: user)
                    .id(navState.tabResetIDs[1])
                case 2: CustomerOrdersView(user: user)
                    .id(navState.tabResetIDs[2])
                case 3: CustomerProfileDetailView(user: user)
                    .id(navState.tabResetIDs[3])
                default: CustomerHomeView(user: user, selectedTab: selectedTabBinding)
                    .id(navState.tabResetIDs[0])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomerTabBar(selectedTab: selectedTabBinding)
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: widgetRoute) { _, newRoute in
            guard let newRoute else { return }
            switch newRoute {
            case .customerStatus:     CustomerNavState.shared.selectedTab = 2
            case .customerActiveList: CustomerNavState.shared.selectedTab = 0
            default: break
            }
            widgetRoute = nil
        }
        .task {
            if !notificationsShown {
                await notificationManager.syncNewBidReceivedNotifications(customerID: user.id)
                notificationManager.reloadNotifications(for: "customer", userID: user.id)
                notificationsShown = true
                print("Customer notifications loaded and displayed once on login")
            }
        }
        .onAppear {
            CustomerNavState.shared.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidAuthenticate)) { _ in
            CustomerNavState.shared.reset()
            notificationsShown = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidSignOut)) { _ in
            CustomerNavState.shared.reset()
            notificationsShown = false
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomerTabBar: View {
    @Binding var selectedTab: Int
    @ObservedObject private var navState = CustomerNavState.shared

    private struct TabItem {
        let icon: String
        let label: String
        let tag: Int
    }

    private let tabs: [TabItem] = [
        TabItem(icon: "house.fill",          label: "Home",    tag: 0),
        TabItem(icon: "birthday.cake.fill",  label: "Bids",    tag: 1),
        TabItem(icon: "list.clipboard.fill", label: "Orders",  tag: 2),
        TabItem(icon: "person.fill",         label: "Profile", tag: 3)
    ]

    private func changePage(to tag: Int) {
        CustomerNavState.shared.navigateTo(tag)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.tag) { index, tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        changePage(to: tab.tag)
                    }
                } label: {
                    ZStack {
                        if !navState.isOnSubScreen && selectedTab == tab.tag {
                            HStack(spacing: 8) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(tab.label)
                                    .font(.urbanistSemiBold(15))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .frame(height: 44)
                            .padding(.horizontal, 20)
                            .background(Color(red: 93/255, green: 55/255, blue: 20/255))
                            .clipShape(Capsule())
                        } else {
                            Image(systemName: tab.icon)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.9, green: 0.9, blue: 0.9).opacity(0.45))
                                )
                        }
                    }
                }
                .buttonStyle(.plain)

                if index < tabs.count - 1 {
                    Spacer(minLength: 12)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 68)
        .background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.94, green: 0.94, blue: 0.94).opacity(0.75),
                        Color(red: 0.92, green: 0.92, blue: 0.92).opacity(0.85)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Color(red: 0.93, green: 0.93, blue: 0.93).opacity(0.5)
                Color(red: 0.96, green: 0.96, blue: 0.96).opacity(0.2)
            }
        )
        .cornerRadius(26)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.6),
                            Color(red: 0.88, green: 0.88, blue: 0.88).opacity(0.3),
                            Color(red: 0.9, green: 0.9, blue: 0.9).opacity(0.4)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 18)
        .padding(.bottom, 1)
    }
}

#Preview {
    CustomerTabView(user: AppUser.mock, widgetRoute: .constant(nil))
}

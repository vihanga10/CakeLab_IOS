import SwiftUI

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

            if !navState.isOnSubScreen {
                CustomerTabBar(selectedTab: selectedTabBinding)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingSpeakButton()
                        .padding(.trailing, 20)
                        .padding(.bottom, 96)
                }
            }
            .zIndex(3)
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
                await notificationManager.syncCustomerOrderStatusNotifications(customerID: user.id)
                notificationManager.reloadNotifications(for: "customer", userID: user.id)
                notificationsShown = true
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

#Preview {
    CustomerTabView(user: AppUser.mock, widgetRoute: .constant(nil))
}

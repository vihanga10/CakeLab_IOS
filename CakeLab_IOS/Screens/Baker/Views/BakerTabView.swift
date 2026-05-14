import SwiftUI

// MARK: - Baker Tab View
@MainActor
struct BakerTabView: View {
    let user: AppUser
    @Binding var widgetRoute: WidgetDeepLinkRoute?
    @State private var notificationsShown = false
    @ObservedObject private var navState = BakerNavState.shared
    @StateObject private var tabVM = BakerTabViewModel()
    @EnvironmentObject var notificationManager: NotificationManager

    private var selectedTabBinding: Binding<Int> {
        Binding(
            get: { BakerNavState.shared.selectedTab },
            set: { BakerNavState.shared.selectedTab = $0 }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch navState.selectedTab {
                case 0: BakerHomeView(user: user, selectedTab: selectedTabBinding)
                case 1: BakerMatchingRequestsView()
                case 2: BakerOrdersView(user: user)
                case 3: BakerProfileView(user: user, parentTabSelection: selectedTabBinding)
                default: BakerHomeView(user: user, selectedTab: selectedTabBinding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !navState.isOnSubScreen {
                BakerTabBar(selectedTab: selectedTabBinding)
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
            case .bakerStatus:   BakerNavState.shared.selectedTab = 2
            case .bakerMatching: BakerNavState.shared.selectedTab = 1
            default: break
            }
            widgetRoute = nil
        }
        .task {
            if !notificationsShown {
                await notificationManager.syncBakerOrderAndPaymentNotifications(bakerID: user.id)
                notificationManager.reloadNotifications(for: "baker", userID: user.id)
                notificationsShown = true
            }
            await tabVM.loadMatchingRequestsAndNotify(user: user, notificationManager: notificationManager)
        }
        .onAppear {
            BakerNavState.shared.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidAuthenticate)) { _ in
            BakerNavState.shared.reset()
            notificationsShown = false
            tabVM.matchingRequestsLoaded = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidSignOut)) { _ in
            BakerNavState.shared.reset()
            notificationsShown = false
            tabVM.matchingRequestsLoaded = false
        }
    }
}

import SwiftUI

// Customer Tab View
struct CustomerTabView: View {
    let user: AppUser
    @Binding var widgetRoute: WidgetDeepLinkRoute?
    @State private var selectedTab: Int = 0
    @State private var notificationsShown = false
    @EnvironmentObject var notificationManager: NotificationManager

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content area
            Group {
                switch selectedTab {
                case 0: CustomerHomeView(user: user, selectedTab: $selectedTab)
                case 1: CustomerBidsView(user: user)
                case 2: CustomerOrdersView(user: user)
                case 3: CustomerProfileDetailView(user: user)
                default: CustomerHomeView(user: user, selectedTab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            CustomerTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: widgetRoute) { _, newRoute in
            guard let newRoute else { return }

            switch newRoute {
            case .customerStatus:
                selectedTab = 2
            case .customerActiveList:
                selectedTab = 0
            default:
                break
            }

            widgetRoute = nil
        }
        .task {
            // Show customer notifications only once on login
            if !notificationsShown {
                notificationManager.reloadNotifications(for: "customer")
                notificationsShown = true
                print("Customer notifications loaded and displayed once on login")
            }
        }
    }
}

// Custom Tab Bar
struct CustomerTabBar: View {
    @Binding var selectedTab: Int

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

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.tag) { index, tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab.tag
                    }
                } label: {
                    ZStack {
                        if selectedTab == tab.tag {
                            // Selected tab: centered capsule with icon and label
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
                            // Unselected tab: icon centered in a circular touch target
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
                // Premium liquid glass background - iOS 26 style with gray tint
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.94, green: 0.94, blue: 0.94).opacity(0.75),
                        Color(red: 0.92, green: 0.92, blue: 0.92).opacity(0.85)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Glass morphism frost layer - more gray
                Color(red: 0.93, green: 0.93, blue: 0.93)
                    .opacity(0.5)
                
                // Subtle blur simulation with gray overlay
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

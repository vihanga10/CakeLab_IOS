import SwiftUI

// MARK: - Customer Tab View
struct CustomerTabView: View {
    let user: AppUser
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            Group {
                switch selectedTab {
                case 0: CustomerHomeView(user: user, selectedTab: $selectedTab)
                case 1: CustomerBidsView()
                case 2: CustomerOrdersView()
                case 3: CustomerProfileView(user: user)
                default: CustomerHomeView(user: user, selectedTab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            CustomerTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomerTabBar: View {
    @Binding var selectedTab: Int

    private struct TabItem {
        let icon: String
        let selectedIcon: String
        let tag: Int
    }

    private let tabs: [TabItem] = [
        TabItem(icon: "house",          selectedIcon: "house.fill",          tag: 0),
        TabItem(icon: "birthday.cake",  selectedIcon: "birthday.cake.fill",  tag: 1),
        TabItem(icon: "list.clipboard", selectedIcon: "list.clipboard.fill", tag: 2),
        TabItem(icon: "person",         selectedIcon: "person.fill",         tag: 3)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab.tag
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.91, green: 0.91, blue: 0.91))
                            .frame(width: 54, height: 54)

                        Image(systemName: selectedTab == tab.tag ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(
                                selectedTab == tab.tag
                                    ? Color(red: 93/255, green: 55/255, blue: 20/255)
                                    : Color(red: 0.4, green: 0.4, blue: 0.4)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .padding(.bottom, 4)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(red: 0.88, green: 0.88, blue: 0.88))
                .frame(height: 1),
            alignment: .top
        )
    }
}

#Preview {
    CustomerTabView(user: AppUser.mock)
}

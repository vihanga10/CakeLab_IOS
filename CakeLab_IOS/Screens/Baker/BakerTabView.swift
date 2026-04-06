import SwiftUI

// MARK: - Baker Tab View
struct BakerTabView: View {
    let user: AppUser
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case 0: BakerHomeView(user: user)
                case 1: BakerMatchingRequestsView()
                case 2: BakerOrdersView()
                case 3: BakerProfileView(user: user)
                default: BakerHomeView(user: user)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BakerTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Baker Custom Tab Bar
struct BakerTabBar: View {
    @Binding var selectedTab: Int

    private struct TabItem {
        let icon: String
        let selectedIcon: String
        let label: String
        let tag: Int
    }

    private let tabs: [TabItem] = [
        TabItem(icon: "house",              selectedIcon: "house.fill",              label: "Home",     tag: 0),
        TabItem(icon: "birthday.cake",      selectedIcon: "birthday.cake.fill",      label: "Requests", tag: 1),
        TabItem(icon: "list.clipboard",     selectedIcon: "list.clipboard.fill",     label: "Orders",   tag: 2),
        TabItem(icon: "person.crop.circle", selectedIcon: "person.crop.circle.fill", label: "Profile",  tag: 3)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab.tag
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(selectedTab == tab.tag
                                      ? Color.cakeBrown.opacity(0.12)
                                      : Color(red: 0.91, green: 0.91, blue: 0.91))
                                .frame(width: 48, height: 48)

                            Image(systemName: selectedTab == tab.tag ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(
                                    selectedTab == tab.tag
                                        ? Color.cakeBrown
                                        : Color(red: 0.4, green: 0.4, blue: 0.4)
                                )
                        }
                        Text(tab.label)
                            .font(.urbanistMedium(10))
                            .foregroundColor(
                                selectedTab == tab.tag ? Color.cakeBrown : Color(red: 0.55, green: 0.55, blue: 0.55)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
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
    BakerTabView(user: AppUser.mockBaker)
}

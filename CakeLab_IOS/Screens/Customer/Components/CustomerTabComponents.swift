import SwiftUI

// MARK: - CustomerSubScreenTabBar
/// Floating tab bar shown on pushed sub-screens. All tabs appear unselected
/// so the customer can jump directly to any tab from any sub-screen.
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
                    withAnimation(.easeInOut(duration: 0.15)) { onSelectTab(tab.tag) }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color(red: 0.9, green: 0.9, blue: 0.9).opacity(0.45)))
                }
                .buttonStyle(.plain)
                if index < tabs.count - 1 { Spacer(minLength: 12) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 68)
        .background(tabBarBackground)
        .cornerRadius(26)
        .overlay(tabBarBorder)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 18)
        .padding(.bottom, 1)
    }
}

// MARK: - CustomerSubScreenModifier
/// Overlays the floating sub-screen tab bar and tracks navigation depth.
struct CustomerSubScreenModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
                .onAppear  { CustomerNavState.shared.depth += 1 }
                .onDisappear { CustomerNavState.shared.depth = max(0, CustomerNavState.shared.depth - 1) }

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

// MARK: - CustomerTabBar
/// Main tab bar shown at the root level of the customer tab view.
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

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element.tag) { index, tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        CustomerNavState.shared.navigateTo(tab.tag)
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
                                .background(Circle().fill(Color(red: 0.9, green: 0.9, blue: 0.9).opacity(0.45)))
                        }
                    }
                }
                .buttonStyle(.plain)
                if index < tabs.count - 1 { Spacer(minLength: 12) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 68)
        .background(tabBarBackground)
        .cornerRadius(26)
        .overlay(tabBarBorder)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 18)
        .padding(.bottom, 1)
    }
}

// MARK: - Shared tab bar styling
private var tabBarBackground: some View {
    ZStack {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.94, green: 0.94, blue: 0.94).opacity(0.75),
                Color(red: 0.92, green: 0.92, blue: 0.92).opacity(0.85)
            ]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        Color(red: 0.93, green: 0.93, blue: 0.93).opacity(0.5)
        Color(red: 0.96, green: 0.96, blue: 0.96).opacity(0.2)
    }
}

private var tabBarBorder: some View {
    RoundedRectangle(cornerRadius: 26)
        .stroke(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.85, green: 0.85, blue: 0.85).opacity(0.6),
                    Color(red: 0.88, green: 0.88, blue: 0.88).opacity(0.3),
                    Color(red: 0.9,  green: 0.9,  blue: 0.9 ).opacity(0.4)
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            lineWidth: 1.5
        )
}

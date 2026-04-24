import SwiftUI
import FirebaseFirestore

// MARK: - Baker Tab View
struct BakerTabView: View {
    let user: AppUser
    @Binding var widgetRoute: WidgetDeepLinkRoute?
    @State private var selectedTab: Int = 0
    @State private var notificationsShown = false
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var matchingRequestsLoaded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case 0: BakerHomeView(user: user)
                case 1: BakerMatchingRequestsView()
                case 2: BakerOrdersView(user: user)
                case 3: BakerProfileView(user: user, parentTabSelection: $selectedTab)
                default: BakerHomeView(user: user)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            BakerTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: widgetRoute) { _, newRoute in
            guard let newRoute else { return }
            
            switch newRoute {
            case .bakerStatus:
                selectedTab = 2
            case .bakerMatching:
                selectedTab = 1
            default:
                break
            }
            
            widgetRoute = nil
        }
        .task {
            // Load matching requests and trigger notifications on login
            await loadMatchingRequestsAndNotify()
            
            // Show baker saved notifications (bid accepted, order confirmed, etc.) only once on login
            if !notificationsShown {
                notificationManager.reloadNotifications(for: "baker")
                notificationsShown = true
                print("✅ Baker notifications loaded and displayed once on login")
            }
        }
    }
    
    // MARK: - Load Matching Requests for Notifications
    private func loadMatchingRequestsAndNotify() async {
        guard !matchingRequestsLoaded else { return }
        
        let db = Firestore.firestore()
        
        do {
            // Fetch open requests from Firestore
            let snapshot = try await db.collection("cakeRequests")
                .whereField("status", isEqualTo: "open")
                .limit(to: 10)
                .getDocuments()
            
            var requests: [CakeRequestRecord] = []
            for document in snapshot.documents {
                if let request = CakeRequestRecord(document: document) {
                    // Filter for matching categories if baker has specialties
                    requests.append(request)
                }
            }
            
            // Show notifications for first 3 matching requests
            if !requests.isEmpty {
                DispatchQueue.main.async {
                    for (index, request) in requests.prefix(3).enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                            notificationManager.notifyNewMatchingRequest(
                                requestTitle: request.title,
                                category: request.category,
                                budget: request.budgetMax,
                                customerID: request.customerID,
                                bakerID: user.id,
                                orderID: request.id
                            )
                        }
                    }
                    matchingRequestsLoaded = true
                }
            } else {
                matchingRequestsLoaded = true
            }
        } catch {
            print("❌ Error loading matching requests: \(error.localizedDescription)")
            matchingRequestsLoaded = true
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
}

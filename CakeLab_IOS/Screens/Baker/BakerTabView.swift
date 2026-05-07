import SwiftUI
import FirebaseFirestore

// MARK: - Baker Tab View
@MainActor
struct BakerTabView: View {
    let user: AppUser
    @Binding var widgetRoute: WidgetDeepLinkRoute?
    @State private var selectedTab: Int = 0
    @State private var notificationsShown = false
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var matchingRequestsLoaded = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0: BakerHomeView(user: user, selectedTab: $selectedTab)
                case 1: BakerMatchingRequestsView()
                case 2: BakerOrdersView(user: user)
                case 3: BakerProfileView(user: user, parentTabSelection: $selectedTab)
                default: BakerHomeView(user: user, selectedTab: $selectedTab)
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
            // Show baker saved notifications (bid accepted, order confirmed, etc.) only once on login
            if !notificationsShown {
                notificationManager.reloadNotifications(for: "baker", userID: user.id)
                notificationsShown = true
                print(" Baker notifications loaded and displayed once on login")
            }

            // Load matching requests and trigger notifications on login
            await loadMatchingRequestsAndNotify()
        }
        .onAppear {
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidAuthenticate)) { _ in
            selectedTab = 0
            notificationsShown = false
            matchingRequestsLoaded = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidSignOut)) { _ in
            selectedTab = 0
            notificationsShown = false
            matchingRequestsLoaded = false
        }
    }
    
    // MARK: - Load Matching Requests for Notifications
    private func loadMatchingRequestsAndNotify() async {
        guard !matchingRequestsLoaded else { return }
        
        let db = Firestore.firestore()
        
        do {
            let bidsSnapshot = try await db.collection("bids")
                .whereField("bakerID", isEqualTo: user.id)
                .getDocuments()
            let placedBidRequestIDs = Set(
                bidsSnapshot.documents.compactMap { document in
                    document.data()["requestDocumentID"] as? String
                }
            )

            // Fetch open requests from Firestore
            let snapshot = try await db.collection("cakeRequests")
                .whereField("status", isEqualTo: "open")
                .limit(to: 10)
                .getDocuments()
            
            var requests: [CakeRequestRecord] = []
            for document in snapshot.documents {
                if let request = CakeRequestRecord(document: document) {
                    guard !placedBidRequestIDs.contains(request.id) else { continue }
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
            print(" Error loading matching requests: \(error.localizedDescription)")
            matchingRequestsLoaded = true
        }
    }
    
    // MARK: - Baker Custom Tab Bar
    struct BakerTabBar: View {
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

        private func changePage(to tag: Int) {
            selectedTab = tag
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
                            if selectedTab == tab.tag {
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
}

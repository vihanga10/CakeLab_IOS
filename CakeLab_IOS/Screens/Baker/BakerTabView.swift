import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - Baker nav state
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

// MARK: - All-unselected baker tab bar for pushed sub-screens
struct BakerSubScreenTabBar: View {
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

struct BakerSubScreenModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
                .onAppear { BakerNavState.shared.depth += 1 }
                .onDisappear { BakerNavState.shared.depth = max(0, BakerNavState.shared.depth - 1) }

            BakerSubScreenTabBar { tag in
                BakerNavState.shared.navigateTo(tag)
                dismiss()
            }
        }
    }
}

extension View {
    func asBakerSubScreen() -> some View {
        modifier(BakerSubScreenModifier())
    }
}

// MARK: - Baker Tab View
@MainActor
struct BakerTabView: View {
    let user: AppUser
    @Binding var widgetRoute: WidgetDeepLinkRoute?
    @State private var notificationsShown = false
    @ObservedObject private var navState = BakerNavState.shared
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var matchingRequestsLoaded = false

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
            case .bakerStatus:
                BakerNavState.shared.selectedTab = 2
            case .bakerMatching:
                BakerNavState.shared.selectedTab = 1
            default:
                break
            }
            
            widgetRoute = nil
        }
        .task {
            // Show baker saved notifications (bid accepted, order confirmed, etc.) only once on login
            if !notificationsShown {
                await notificationManager.syncBakerOrderAndPaymentNotifications(bakerID: user.id)
                notificationManager.reloadNotifications(for: "baker", userID: user.id)
                notificationsShown = true
                print(" Baker notifications loaded and displayed once on login")
            }

            // Load matching requests and trigger notifications on login
            await loadMatchingRequestsAndNotify()
        }
        .onAppear {
            BakerNavState.shared.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidAuthenticate)) { _ in
            BakerNavState.shared.reset()
            notificationsShown = false
            matchingRequestsLoaded = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .appUserDidSignOut)) { _ in
            BakerNavState.shared.reset()
            notificationsShown = false
            matchingRequestsLoaded = false
        }
    }
    
    // MARK: - Load Matching Requests for Notifications
    private func loadMatchingRequestsAndNotify() async {
        guard !matchingRequestsLoaded else { return }
        
        let db = Firestore.firestore()
        
        do {
            let bakerSpecialties = try await loadBakerSpecialties(db: db)
            guard !bakerSpecialties.isEmpty else {
                matchingRequestsLoaded = true
                return
            }

            let bidsSnapshot = try await db.collection("bids")
                .whereField("bakerID", isEqualTo: user.id)
                .getDocuments()
            let placedBidRequestIDs = Set(
                bidsSnapshot.documents.compactMap { document in
                    document.data()["requestDocumentID"] as? String
                }
            )

            // Fetch open requests from Firestore. Only category-matched requests
            // should trigger "New Matching Request" notifications.
            let snapshot = try await db.collection("cakeRequests")
                .whereField("status", isEqualTo: "open")
                .limit(to: 50)
                .getDocuments()
            
            var requests: [CakeRequestRecord] = []
            for document in snapshot.documents {
                if let request = CakeRequestRecord(document: document) {
                    guard !placedBidRequestIDs.contains(request.id) else { continue }
                    guard requestMatchesBakerSpecialties(request, specialties: bakerSpecialties) else { continue }
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
                                category: request.displayCategory,
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

    private func loadBakerSpecialties(db: Firestore) async throws -> [String] {
        let snapshot = try await db.collection("artisans").document(user.id).getDocument()
        return snapshot.data()?["specialties"] as? [String] ?? []
    }

    private func requestMatchesBakerSpecialties(_ request: CakeRequestRecord, specialties: [String]) -> Bool {
        if request.isDirectRequest {
            return request.targetArtisanId == user.id
        }

        let normalizedSpecialties = Set(specialties.map(normalizedCakeCategory).filter { !$0.isEmpty })
        guard !normalizedSpecialties.isEmpty else { return false }

        let requestCategories = request.categories.isEmpty ? [request.category] : request.categories
        let categories = requestCategories.isEmpty ? [request.displayCategory] : requestCategories
        let normalizedRequestCategories = Set(categories.map(normalizedCakeCategory).filter { !$0.isEmpty })

        return !normalizedRequestCategories.isDisjoint(with: normalizedSpecialties)
    }

    private func normalizedCakeCategory(_ raw: String) -> String {
        let cleaned = raw
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "cakes", with: "")
            .replacingOccurrences(of: "cake", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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

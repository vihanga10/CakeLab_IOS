import SwiftUI
import FirebaseFirestore

// MARK: - Baker Matching Requests View (Nav Tab 1)
@MainActor
struct BakerMatchingRequestsView: View {
    @State private var searchText = ""
    @State private var selectedFilter: RequestFilter = .all
    @State private var publishedRequests: [CakeRequestRecord] = []
    @State private var isLoading = false
    
    enum RequestFilter: String, CaseIterable {
        case all = "All"
        case wedding = "Wedding"
        case birthday = "Birthday"
        case anniversary = "Anniversary"
        case cupcakes = "Cupcakes"
        case babyShower = "Baby Shower"
    }
    
    private var filtered: [CakeRequestRecord] {
        publishedRequests.filter { request in
            let matchesSearch = searchText.isEmpty || request.displayTitle.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = selectedFilter == .all ||
                request.categories.contains { $0.localizedCaseInsensitiveContains(selectedFilter.rawValue) } ||
                request.displayCategory.localizedCaseInsensitiveContains(selectedFilter.rawValue)
            return matchesSearch && matchesFilter
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.cakeGrey)
                        TextField("Search requests...", text: $searchText)
                            .font(.urbanistRegular(14))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(RequestFilter.allCases, id: \.self) { filter in
                                Button {
                                    withAnimation { selectedFilter = filter }
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(selectedFilter == filter ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedFilter == filter ? Color.cakeBrown : Color.white)
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 14)
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Loading requests...")
                            .tint(.cakeBrown)
                        Spacer()
                    } else if filtered.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(Color.cakeGrey.opacity(0.5))
                            Text("No matching requests")
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.cakeGrey)
                            Text("Published customer requests will appear here once they match your search or category filter")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                HStack {
                                    Text("\(filtered.count) published requests")
                                        .font(.urbanistRegular(13))
                                        .foregroundColor(.cakeGrey)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                ForEach(filtered) { request in
                                    NavigationLink(destination: BakerBidDetailView(request: request.toCakeRequest())) {
                                        MatchingRequestCard(request: request.toCakeRequest())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("Matching Requests")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await fetchPublishedRequests()
            }
            .refreshable {
                await fetchPublishedRequests()
            }
        }
    }
    
    private func fetchPublishedRequests() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await Firestore.firestore()
                .collection("cakeRequests")
                .whereField("status", isEqualTo: "open")
                .getDocuments()
            
            publishedRequests = snapshot.documents
                .compactMap(CakeRequestRecord.init(document:))
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("Error fetching published requests: \(error)")
        }
    }
}

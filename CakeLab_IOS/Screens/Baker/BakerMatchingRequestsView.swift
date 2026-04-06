import SwiftUI

// MARK: - Baker Matching Requests View (Nav Tab 1)
@MainActor
struct BakerMatchingRequestsView: View {
    @State private var searchText = ""
    @State private var selectedFilter: RequestFilter = .all

    enum RequestFilter: String, CaseIterable {
        case all = "All"
        case wedding = "Wedding"
        case birthday = "Birthday"
        case corporate = "Corporate"
        case custom = "Custom"
    }

    var filtered: [CakeRequest] {
        mockMatchingRequests.filter { req in
            let matchSearch = searchText.isEmpty || req.title.localizedCaseInsensitiveContains(searchText)
            let matchFilter = selectedFilter == .all || req.category.name.localizedCaseInsensitiveContains(selectedFilter.rawValue)
            return matchSearch && matchFilter
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
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

                    // Filter chips
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

                    if filtered.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(Color.cakeGrey.opacity(0.5))
                            Text("No matching requests")
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.cakeGrey)
                            Text("Try changing your filter or location settings")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                // Header info
                                HStack {
                                    Text("\(filtered.count) requests match your categories")
                                        .font(.urbanistRegular(13))
                                        .foregroundColor(.cakeGrey)
                                    Spacer()
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 11))
                                    Text("Colombo")
                                        .font(.urbanistMedium(12))
                                }
                                .foregroundColor(.cakeGrey)
                                .padding(.horizontal, 20)

                                ForEach(filtered) { req in
                                    NavigationLink(destination: BakerBidDetailView(request: req)) {
                                        MatchingRequestCard(request: req)
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
        }
    }
}

// MARK: - Baker Other Open Requests View
@MainActor
struct BakerOtherRequestsView: View {
    @State private var searchText = ""

    var filtered: [CakeRequest] {
        mockOtherRequests.filter { req in
            searchText.isEmpty || req.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()
            VStack(spacing: 0) {
                // Info Banner
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color(red: 0.3, green: 0.45, blue: 0.8))
                    Text("These requests are outside your published categories. You can still place bids!")
                        .font(.urbanistRegular(12))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                }
                .padding(14)
                .background(Color(red: 0.3, green: 0.45, blue: 0.8).opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(.cakeGrey)
                    TextField("Search open requests...", text: $searchText)
                        .font(.urbanistRegular(14))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(filtered) { req in
                            NavigationLink(destination: BakerBidDetailView(request: req)) {
                                OtherRequestCard(request: req)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Other Open Requests")
        .navigationBarTitleDisplayMode(.large)
    }
}

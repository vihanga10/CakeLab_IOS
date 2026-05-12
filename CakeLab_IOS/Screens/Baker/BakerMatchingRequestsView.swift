import SwiftUI
import FirebaseFirestore

// MARK: - Baker Matching Requests View (Nav Tab 1)
@MainActor
struct BakerMatchingRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedSpecialty: String = "All"
    @State private var selectedRequest: CakeRequest?
    @State private var showBidDetail = false
    @StateObject private var viewModel = BakerMatchingRequestsViewModel()

    private var filtered: [CakeRequestRecord] {
        let baseRequests = viewModel.matchingRequests

        let afterSearch = searchText.isEmpty ? baseRequests : baseRequests.filter { request in
            request.displayTitle.localizedCaseInsensitiveContains(searchText)
        }

        if selectedSpecialty == "All" {
            return afterSearch
        } else {
            return afterSearch.filter { viewModel.matches(request: $0, specialty: selectedSpecialty) }
        }
    }

    private var filterOptions: [String] {
        ["All"] + viewModel.bakerSpecialties
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cakeBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Custom Header
                    HStack {
                        Spacer()
                        Text("Matching Requests")
                            .font(.urbanistBold(18))
                            .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(Color.cakeSurface)

                    // MARK: - Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.cakeGrey)
                        TextField("Search requests...", text: $searchText)
                            .font(.urbanistRegular(14))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                    // MARK: - Specialty Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(filterOptions, id: \.self) { specialty in
                                Button {
                                    withAnimation { selectedSpecialty = specialty }
                                } label: {
                                    Text(specialty)
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(selectedSpecialty == specialty ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedSpecialty == specialty ? Color.cakeBrown : Color(red: 0.95, green: 0.95, blue: 0.95))
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 14)

                    // MARK: - Content
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading matching requests...")
                            .tint(.cakeBrown)
                        Spacer()
                    } else if !viewModel.bakerSpecialties.isEmpty && filtered.isEmpty {
                        emptyState(
                            icon: "sparkles",
                            title: "No matching requests yet",
                            message: "Requests that match your specialties will appear here.",
                            iconColor: Color.cakeBrown.opacity(0.35)
                        )
                    } else if viewModel.bakerSpecialties.isEmpty {
                        emptyState(
                            icon: "person.crop.circle.badge.plus",
                            title: "Complete your profile",
                            message: "Add specialties to see matching cake requests from customers.",
                            iconColor: Color.cakeBrown.opacity(0.35)
                        )
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                HStack {
                                    Text("\(filtered.count) matching request\(filtered.count == 1 ? "" : "s")")
                                        .font(.urbanistRegular(13))
                                        .foregroundColor(.cakeGrey)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)

                                ForEach(filtered) { request in
                                    let cakeRequest = request.toCakeRequest()
                                    MatchingRequestCard(request: cakeRequest) {
                                        selectedRequest = cakeRequest
                                        showBidDetail = true
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 100)
                        }
                    }
                }

                NavigationLink(
                    destination: Group {
                        if let req = selectedRequest {
                            BakerBidDetailView(request: req)
                        }
                    },
                    isActive: $showBidDetail
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadMatchingRequests()
            }
            .refreshable {
                await viewModel.loadMatchingRequests()
            }
            .onReceive(NotificationCenter.default.publisher(for: .bidDidChange)) { _ in
                Task {
                    await viewModel.loadMatchingRequests()
                }
            }
        }
    }

    private func emptyState(
        icon: String,
        title: String,
        message: String,
        iconColor: Color
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundColor(iconColor)
            Text(title)
                .font(.urbanistSemiBold(14))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

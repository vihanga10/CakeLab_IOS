import SwiftUI


// MARK: - Baker Other Open Requests View
@MainActor
struct BakerOtherRequestsView: View {
    @ObservedObject var viewModel: BakerMatchingRequestsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedRequest: CakeRequest?
    @State private var showBidDetail = false

    private var filtered: [CakeRequestRecord] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return viewModel.otherOpenRequests
        }
        let text = searchText.lowercased()
        return viewModel.otherOpenRequests.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(text) ||
            $0.customerCity.localizedCaseInsensitiveContains(text) ||
            $0.category.localizedCaseInsensitiveContains(text)
        }
    }

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.cakeBrown)
                    }
                    Spacer()
                    Text("Other Open Requests")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
                    Spacer()
                    Color.clear.frame(width: 24)
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

                // MARK: - Other Requests Content
                if viewModel.isLoading {
                    // Loading state while open requests are fetched.
                    Spacer()
                    ProgressView("Loading requests...")
                        .tint(.cakeBrown)
                    Spacer()
                } else if viewModel.otherOpenRequests.isEmpty {
                    // Empty state when no outside-specialty requests exist.
                    emptyState(
                        icon: "tray",
                        title: "No other open requests yet",
                        message: "Requests outside your specialties will appear here when available."
                    )
                } else {
                    // Request cards outside baker matching specialties.
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            HStack {
                                Text("\(filtered.count) request\(filtered.count == 1 ? "" : "s")")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)
                                Spacer()
                            }
                            .padding(.horizontal, 20)

                            ForEach(filtered) { record in
                                let req = record.toCakeRequest()
                                MatchingRequestCard(
                                    request: req,
                                    onPlaceBid: {
                                        // Open bid detail form for this request.
                                        selectedRequest = req
                                        showBidDetail = true
                                    },
                                    buttonTitle: "Can you do this?"
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 100)
                    }
                }
            }

            NavigationLink(
                // Hidden navigation link used to push bid detail view.
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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            // Refresh open requests list.
            await viewModel.loadMatchingRequests()
        }
        .asBakerSubScreen()
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundColor(Color.cakeBrown.opacity(0.35))
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

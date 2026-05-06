import SwiftUI

// MARK: - Baker Other Requests View
// Shows all open cake requests that do NOT match the baker's specialties
// and have not yet been confirmed by another baker (status == "open").
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
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
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
                    .background(Color.white)

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

                    // MARK: - Content
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading requests...")
                            .tint(.cakeBrown)
                        Spacer()
                    } else if viewModel.otherOpenRequests.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(Color.cakeGrey.opacity(0.5))
                            Text("No other open requests")
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.cakeGrey)
                            Text("All open requests match your specialties, or there are no open requests right now.")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
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
            .refreshable {
                await viewModel.loadMatchingRequests()
            }
        }
    }
}

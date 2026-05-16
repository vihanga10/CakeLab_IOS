import SwiftUI

// MARK: - Baker Bid History
@MainActor
struct BakerBidHistoryView: View {
    let user: AppUser
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BakerBidHistoryViewModel()
    @State private var selectedItem: BakerBidHistoryItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cakeBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar

                    if viewModel.isLoading {
                        // Loading state while baker bid history is fetched.
                        Spacer()
                        ProgressView("Loading bid history...")
                            .tint(.cakeBrown)
                        Spacer()
                    } else if let errorMessage = viewModel.errorMessage {
                        // Error state when bids cannot be loaded.
                        emptyState(icon: "exclamationmark.circle", title: "Could Not Load Bids", message: errorMessage)
                    } else if viewModel.items.isEmpty {
                        // Empty state before baker places any bids.
                        emptyState(
                            icon: "tray",
                            title: "No Bid History",
                            message: "Requests you place bids on will move here from Matching Requests."
                        )
                    } else {
                        // Bid history cards, each opens a detail view.
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                HStack {
                                    Text("\(viewModel.items.count) placed bid\(viewModel.items.count == 1 ? "" : "s")")
                                        .font(.urbanistRegular(13))
                                        .foregroundColor(.cakeGrey)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)

                                ForEach(viewModel.items) { item in
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        BakerBidHistoryCard(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 104)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                // Bid history detail screen.
                BakerBidHistoryDetailView(item: item)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                // Load placed bids for this baker.
                await viewModel.loadBidHistory(bakerID: user.id)
            }
            .refreshable {
                await viewModel.loadBidHistory(bakerID: user.id)
            }
        }
        .asBakerSubScreen()
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }

            Spacer()

            Text("Bid History")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color.cakeGrey.opacity(0.5))
            Text(title)
                .font(.urbanistSemiBold(17))
                .foregroundColor(.cakeBrown)
            Text(message)
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

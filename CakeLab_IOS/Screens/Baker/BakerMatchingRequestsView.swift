import SwiftUI
import FirebaseFirestore

// MARK: - Baker Matching Requests View (Nav Tab 1)
@MainActor
struct BakerMatchingRequestsView: View {
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
                            ForEach(filterOptions, id: \.self) { specialty in
                                Button {
                                    withAnimation { selectedSpecialty = specialty }
                                } label: {
                                    Text(specialty)
                                        .font(.urbanistSemiBold(13))
                                        .foregroundColor(selectedSpecialty == specialty ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedSpecialty == specialty ? Color.cakeBrown : Color.white)
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 14)
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading matching requests...")
                            .tint(.cakeBrown)
                        Spacer()
                    } else if !viewModel.bakerSpecialties.isEmpty && filtered.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(Color.cakeGrey.opacity(0.5))
                            Text("No matching requests")
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.cakeGrey)
                            Text("We'll show customer requests that match your specialties: \(viewModel.bakerSpecialties.joined(separator: ", "))")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.bakerSpecialties.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 48))
                                .foregroundColor(Color.orange)
                            Text("Complete Your Profile")
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.cakeGrey)
                            Text("Add your specialties to see matching cake requests from customers")
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
            .navigationTitle("Matching Requests")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadMatchingRequests()
            }
            .refreshable {
                await viewModel.loadMatchingRequests()
            }
        }
    }
}

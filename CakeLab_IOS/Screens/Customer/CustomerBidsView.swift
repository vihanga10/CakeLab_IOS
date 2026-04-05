import SwiftUI

// MARK: - Mock Bid Request (frontend only)
struct BidRequest: Identifiable {
    let id       = UUID()
    let title: String
    let date: String
    let time: String
    let category: String
    let budgetMin: Int
    let budgetMax: Int
    let bidCount: Int
    let imageName: String
}

// MARK: - Customer Bids View
struct CustomerBidsView: View {

    private let bids: [BidRequest] = [
        BidRequest(title: "3-Tier Elegant Wedding Cake with Fresh Flowers",
                   date: "09/ 04/ 2026", time: "12.00 pm",
                   category: "Wedding Cake",
                   budgetMin: 22000, budgetMax: 28000, bidCount: 3,
                   imageName: "wedding_req"),
        BidRequest(title: "Baby Shower Cake with Teddy Bear Theme",
                   date: "12/ 04/ 2026", time: "10.00 pm",
                   category: "Baby Shower",
                   budgetMin: 11000, budgetMax: 14000, bidCount: 4,
                   imageName: "babyshower_req"),
        BidRequest(title: "Birthday Butterfly Cake for 7 Year Old",
                   date: "22/ 04/ 2026", time: "05.30 pm",
                   category: "Birthday Cake",
                   budgetMin: 8000, budgetMax: 12000, bidCount: 3,
                   imageName: "birthday_req"),
        BidRequest(title: "Pink 25th Anniversary Heart Shape Cake",
                   date: "10/ 05/ 2026", time: "07.00 pm",
                   category: "Anniversary Cake",
                   budgetMin: 14000, budgetMax: 18000, bidCount: 2,
                   imageName: "anniversary_req")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(bids) { bid in
                            BidRequestCard(bid: bid)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Bids On My Requests")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                }
            }
        }
    }
}

// MARK: - Bid Request Card
struct BidRequestCard: View {
    let bid: BidRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Top row: image + details
            HStack(alignment: .top, spacing: 12) {

                // Cake image placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 95, height: 105)
                    if UIImage(named: bid.imageName) != nil {
                        Image(bid.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 95, height: 105)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "birthday.cake.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.cakeBrown.opacity(0.4))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(bid.title)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Date & Time
                    HStack(spacing: 6) {
                        Text(bid.date)
                            .font(.urbanistRegular(12))
                            .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                        Rectangle()
                            .fill(Color(red: 0.70, green: 0.70, blue: 0.70))
                            .frame(width: 1, height: 12)
                        Text(bid.time)
                            .font(.urbanistRegular(12))
                            .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                    }

                    // Category
                    Text("Category : \(bid.category)")
                        .font(.urbanistRegular(12))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.35))
                }

                Spacer()
            }

            // Budget
            HStack(spacing: 6) {
                Text("Budget (LKR) :")
                    .font(.urbanistRegular(12))
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                Text("\(bid.budgetMin.formatted()) – \(bid.budgetMax.formatted())")
                    .font(.urbanistBold(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            }

            // Buttons row
            HStack(spacing: 10) {
                Button {} label: {
                    Text("View Bids Received (\(bid.bidCount))")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.cakeBrown)
                        .clipShape(Capsule())
                }

                Button {} label: {
                    Text("View Full Details")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.80, green: 0.80, blue: 0.80), lineWidth: 1.5)
                        )
                }

                Spacer()
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    CustomerBidsView()
}

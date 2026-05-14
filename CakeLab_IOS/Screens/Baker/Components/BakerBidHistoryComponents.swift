import SwiftUI
import UIKit

// Card shown in the bid history list
struct BakerBidHistoryCard: View {
    let item: BakerBidHistoryItem

    private var request: BakerBidHistoryRequest { item.request }
    private var bid: BakerBidHistoryBid { item.bid }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                requestImage

                VStack(alignment: .leading, spacing: 7) {
                    Text(request.displayTitle)
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakePrimaryText)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Label(request.customerName, systemImage: "person.fill")
                        Spacer()
                        Label(request.customerCity.isEmpty ? "Customer Location" : request.customerCity, systemImage: "mappin.and.ellipse")
                    }
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)

                    // Bid status badge and submitted date
                    HStack(spacing: 8) {
                        statusChip
                        Spacer()
                        Text(Self.submittedFormatter.string(from: bid.submittedAt))
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                    }
                }
            }

            Divider()

            HStack {
                metric(label: "Bid Amount", value: "LKR \(Int(bid.amount).formatted())")
                Divider().frame(height: 34)
                metric(label: "Budget", value: request.budgetText)
                Divider().frame(height: 34)
                metric(label: "Delivery", value: request.expectedDateText)
            }
        }
        .padding(14)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var requestImage: some View {
        Group {
            if let firstImage = request.referenceImages.first,
               let imageData = Data(base64Encoded: firstImage),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cakeBrown.opacity(0.12))
                    Image(systemName: categoryIcon(for: request.displayCategory))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.cakeBrown)
                }
            }
        }
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // Small pill showing the current bid status
    private var statusChip: some View {
        Text(bid.status.capitalized)
            .font(.urbanistMedium(11))
            .foregroundColor(.cakeBrown)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.cakeBrown.opacity(0.1))
            .cornerRadius(6)
    }

    // Reusable label + value pair used in the bottom metrics row
    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.urbanistRegular(10))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistBold(12))
                .foregroundColor(.cakePrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Date formatter for the submitted date
    private static let submittedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter
    }()
}


// Full detail screen that opens when the baker taps a bid history card
struct BakerBidHistoryDetailView: View {
    let item: BakerBidHistoryItem
    @Environment(\.dismiss) private var dismiss

    private var request: BakerBidHistoryRequest { item.request }
    private var bid: BakerBidHistoryBid { item.bid }

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        summarySection
                        cakeDetailsSection
                        bidDetailsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // Custom nav bar with a back button and centered title
    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }

            Spacer()

            Text("Bid Details")
                .font(.urbanistBold(18))
                .foregroundColor(Color(hex: "5D3714"))

            Spacer()

            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    // Top card
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(request.displayTitle)
                .font(.urbanistBold(20))
                .foregroundColor(.cakePrimaryText)

            Text(request.description.isEmpty ? "No description provided." : request.description)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineSpacing(4)

            HStack(spacing: 10) {
                summaryChip(icon: "person.fill", text: request.customerName)
                summaryChip(icon: "birthday.cake.fill", text: request.displayCategory)
            }
        }
        .padding(18)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    // All the cake specs the customer entered when creating the request
    private var cakeDetailsSection: some View {
        detailSection(title: "Cake Details") {
            detailRow(label: "Customer Location", value: request.customerCity.isEmpty ? "Customer Location" : request.customerCity)
            detailRow(label: "Delivery Date", value: request.expectedDateText)
            detailRow(label: "Delivery Time", value: request.expectedTimeText)
            detailRow(label: "Budget", value: request.budgetText)
            detailRow(label: "Tiers", value: request.tier > 0 ? "\(request.tier)" : "Not specified")
            detailRow(label: "Cake Size", value: fallback(request.cakeSize))
            detailRow(label: "Sugar Level", value: "\(Int((request.sugarLevel * 100).rounded()))%")
            detailRow(label: "Flavours", value: joined(request.flavours))
            detailRow(label: "Styles", value: joined(request.styles))
            detailRow(label: "Dietary", value: joined(request.dietary))
            detailRow(label: "Filling Flavour", value: fallback(request.fillingFlavour))
            detailRow(label: "Special Instructions", value: fallback(request.specialInstructions))
        }
    }

    // The baker's own bid info 
    private var bidDetailsSection: some View {
        detailSection(title: "Bid Details") {
            detailRow(label: "Bid Amount", value: "LKR \(Int(bid.amount).formatted())")
            detailRow(label: "Status", value: bid.status.capitalized)
            detailRow(label: "Submitted", value: Self.dateTimeFormatter.string(from: bid.submittedAt))
            detailRow(
                label: "Delivery Promise",
                value: bid.canDeliverOnTime
                    ? "Can deliver on requested date"
                    : "Alternative: \(bid.alternativeDate.map { formattedDate($0) } ?? "Not provided")"
            )
            detailRow(label: "Message to Customer", value: fallback(bid.message))
            detailRow(label: "Delivery Note", value: fallback(bid.deliveryNote))
        }
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.urbanistBold(16))
                .foregroundColor(.cakePrimaryText)

            content()
        }
        .padding(18)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistSemiBold(13))
                .foregroundColor(.cakePrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.cakeInsetSurface)
        .cornerRadius(12)
    }

    private func summaryChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.urbanistMedium(12))
        .foregroundColor(.cakeBrown)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.cakeBrown.opacity(0.1))
        .cornerRadius(8)
    }

    private func fallback(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not specified" : trimmed
    }

    private func joined(_ values: [String]) -> String {
        let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return cleaned.isEmpty ? "Not specified" : cleaned.joined(separator: ", ")
    }
 
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"
        return formatter
    }()
}

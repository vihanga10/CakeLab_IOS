import SwiftUI

// MARK: - Published Cake Detail View
@MainActor
struct PublishedCakeDetailView: View {
    let request: CakeRequestRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header matching PublishRequestView pattern
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title and Description
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Title")
                                .font(.urbanistMedium(12))
                                .foregroundColor(.cakeGrey)
                            Text(request.displayTitle)
                                .font(.urbanistSemiBold(16))
                                .foregroundColor(.cakePrimaryText)
                                .lineLimit(nil)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description")
                                .font(.urbanistMedium(12))
                                .foregroundColor(.cakeGrey)
                            Text(request.description.isEmpty ? "No description provided" : request.description)
                                .font(.urbanistRegular(14))
                                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                                .lineSpacing(2)
                                .lineLimit(nil)
                        }

                        // Reference Images
                        if !request.referenceImages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Reference Images")
                                    .font(.urbanistSemiBold(12))
                                    .foregroundColor(.cakeGrey)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(request.referenceImages.indices, id: \.self) { index in
                                            if let imageData = Data(base64Encoded: request.referenceImages[index]),
                                               let uiImage = UIImage(data: imageData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 120, height: 120)
                                                    .cornerRadius(10)
                                                    .clipped()
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // Placeholder when no images
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.93, green: 0.91, blue: 0.88))
                                
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.cakeBrown.opacity(0.5))
                                    Text("No Reference Images")
                                        .font(.urbanistSemiBold(14))
                                        .foregroundColor(.cakeBrown)
                                }
                            }
                            .frame(height: 120)
                        }

                        // Budget
                        infoRow(label: "Budget (LKR)", value: request.budgetText)

                        // Category
                        infoRow(label: "Category", value: request.displayCategory)

                        // Cake Style
                        infoRow(label: "Cake Style", value: request.styles.isEmpty ? "Not specified" : request.styles.joined(separator: ", "))

                        // Dietary
                        infoRow(label: "Dietary", value: request.dietary.isEmpty ? "None" : request.dietary.joined(separator: ", "))

                        // Tiers
                        infoRow(label: "Tiers", value: "\(request.tier)")

                        // Cake Size
                        infoRow(label: "Cake Size", value: request.cakeSize.isEmpty ? "Not specified" : request.cakeSize)

                        // Sugar Level
                        infoRow(label: "Sugar Level", value: String(format: "%.0f", request.sugarLevel * 100))

                        // Cake Flavour
                        infoRow(label: "Cake Flavour", value: request.flavours.isEmpty ? "Not specified" : request.flavours.joined(separator: ", "))

                        // Filling Flavour
                        infoRow(label: "Filling Flavour", value: request.fillingFlavour.isEmpty ? "Not specified" : request.fillingFlavour)

                        // Special Instructions
                        if !request.specialInstructions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Special Instructions")
                                    .font(.urbanistMedium(12))
                                    .foregroundColor(.cakeGrey)
                                Text(request.specialInstructions)
                                    .font(.urbanistRegular(14))
                                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                                    .lineSpacing(2)
                                    .lineLimit(nil)
                            }
                        }

                        // Expected Date
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Expected Date")
                                .font(.urbanistMedium(12))
                                .foregroundColor(.cakeGrey)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.cakeBrown)
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text(formattedDate(request.expectedDate))
                                    .font(.urbanistRegular(14))
                                    .foregroundColor(.cakePrimaryText)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
                            .cornerRadius(10)
                        }

                        // Expected Time
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Expected Time")
                                .font(.urbanistMedium(12))
                                .foregroundColor(.cakeGrey)

                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.cakeBrown)
                                    .font(.system(size: 14, weight: .semibold))

                                Text(formattedTime(request.expectedTime))
                                    .font(.urbanistRegular(14))
                                    .foregroundColor(.cakePrimaryText)

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
                            .cornerRadius(10)
                        }

                        // Baker — shown only when this is a direct request to a specific artisan
                        if request.isDirectRequest, let bakerName = request.targetArtisanName, !bakerName.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Baker")
                                    .font(.urbanistMedium(12))
                                    .foregroundColor(.cakeGrey)

                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.cakeBrown.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.cakeBrown)
                                    }
                                    Text(bakerName)
                                        .font(.urbanistSemiBold(14))
                                        .foregroundColor(.cakePrimaryText)
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.98, green: 0.96, blue: 0.93))
                                .cornerRadius(10)
                            }
                        }

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .asCustomerSubScreen()
    }

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Cake Details")
                    .font(.urbanistBold(18))
                    .foregroundColor(.cakeBrown)
            }
            Spacer()
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.urbanistMedium(12))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistRegular(14))
                .foregroundColor(.cakePrimaryText)
                .lineLimit(nil)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        PublishedCakeDetailView(request: CakeRequestRecord.mock)
    }
}

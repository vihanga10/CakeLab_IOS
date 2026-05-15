import SwiftUI


struct LocationPickerSheet: View {
    @Binding var filterCity: String?
    @Environment(\.dismiss) private var dismiss

    @State private var localSelection: String?

    private let districts = SriLankaDistricts.all

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Select City to Filter")
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(.cakePrimaryText)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        districtButton(title: "None", isSelected: localSelection == nil) {
                            localSelection = nil
                        }

                        ForEach(districts, id: \.self) { district in
                            districtButton(title: district, isSelected: localSelection == district) {
                                localSelection = district
                            }
                        }
                    }

                    Button {
                        filterCity = localSelection
                        dismiss()
                    } label: {
                        Text("Confirm")
                            .font(.urbanistBold(16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.cakeBrown)
                            .cornerRadius(16)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("Filter by City")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { localSelection = filterCity }
        .presentationDetents([.medium, .large])
    }

    private func districtButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.urbanistMedium(14))
                .foregroundColor(isSelected ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.cakeBrown : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color(red: 0.88, green: 0.88, blue: 0.88), lineWidth: 1)
                )
        }
    }
}

// MARK: - MatchingRequestCard
// Card displaying a cake request that matches the baker's specialties.
struct MatchingRequestCard: View {
    let request: CakeRequest
    var onPlaceBid: (() -> Void)? = nil
    var buttonTitle: String = "Place Bid"

    private let pastelPalette: [Color] = [
        Color(red: 0.95, green: 0.84, blue: 0.92),
        Color(red: 0.98, green: 0.86, blue: 0.82),
        Color(red: 0.97, green: 0.93, blue: 0.78),
        Color(red: 0.86, green: 0.93, blue: 0.98),
        Color(red: 0.87, green: 0.95, blue: 0.88),
        Color(red: 0.91, green: 0.88, blue: 0.98)
    ]

    private var chipColor: Color {
        let index = abs(request.category.name.hashValue) % pastelPalette.count
        return pastelPalette[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                if !request.referenceImages.isEmpty,
                   let imageData = Data(base64Encoded: request.referenceImages[0]),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                        .clipped()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(chipColor.opacity(0.8))
                            .frame(width: 80, height: 80)
                        Image(systemName: request.category.icon)
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.32, green: 0.23, blue: 0.16))
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(request.title)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                        .lineLimit(2)

                    Spacer()

                    HStack(spacing: 6) {
                        Text(request.category.name)
                            .font(.urbanistMedium(10))
                            .foregroundColor(Color(red: 0.32, green: 0.23, blue: 0.16))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(chipColor)
                            .cornerRadius(6)

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(request.deliveryDate)
                                .font(.urbanistRegular(10))
                        }
                        .foregroundColor(.cakeGrey)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                            .foregroundColor(.cakeGrey)
                        Text(request.location)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(request.bidCount) bids")
                                .font(.urbanistMedium(10))
                        }
                        .foregroundColor(.cakeBrown)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cakeBrown.opacity(0.10))
                        .cornerRadius(6)
                    }
                }
                .frame(height: 80)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 14)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Budget (LKR)")
                        .font(.urbanistRegular(10))
                        .foregroundColor(.cakeGrey)
                    Text(request.budgetRange)
                        .font(.urbanistBold(13))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))
                }

                Spacer()

                if let onPlaceBid = onPlaceBid {
                    Button(action: onPlaceBid) {
                        Text(buttonTitle)
                            .font(buttonTitle == "Can you do this?" ? .urbanistSemiBold(12) : .urbanistSemiBold(13))
                            .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.082))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.906, green: 0.871, blue: 0.847))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 155)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.09), radius: 10, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - OtherRequestCard
// Card displaying an open cake request outside the baker's specialties.
struct OtherRequestCard: View {
    let request: CakeRequest

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.3, green: 0.45, blue: 0.8).opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: request.category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.3, green: 0.45, blue: 0.8))
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(request.title)
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(.cakePrimaryText)
                    Spacer()
                    Text(request.budgetRange)
                        .font(.urbanistBold(13))
                        .foregroundColor(Color(red: 0.3, green: 0.45, blue: 0.8))
                }
                HStack(spacing: 6) {
                    Image(systemName: "birthday.cake")
                        .font(.system(size: 10))
                    Text(request.category.name)
                        .font(.urbanistRegular(12))
                    Text("•")
                    Text(request.location)
                        .font(.urbanistRegular(12))
                }
                .foregroundColor(.cakeGrey)

                HStack {
                    Text(request.deliveryDate)
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    Spacer()
                    Text("Can you do this?")
                        .font(.urbanistSemiBold(11))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.cakeBrown)
                        .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color.cakeSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - BakerActiveOrderCard
// Compact card showing a baker's active order.
struct BakerActiveOrderCard: View {
    let order: BakerOrder

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(order.statusColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "bag.fill")
                    .font(.system(size: 22))
                    .foregroundColor(order.statusColor)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(order.cakeName)
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(.cakePrimaryText)
                    Spacer()
                    Text(order.statusLabel)
                        .font(.urbanistMedium(11))
                        .foregroundColor(order.statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(order.statusColor.opacity(0.1))
                        .cornerRadius(8)
                }
                Text("Customer: \(order.customerName)")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("Deliver by \(order.deliveryDate)")
                        .font(.urbanistRegular(12))
                    Spacer()
                    Text(order.amount)
                        .font(.urbanistBold(14))
                        .foregroundColor(.cakeBrown)
                }
                .foregroundColor(.cakeGrey)
            }
        }
        .padding(14)
        .background(Color.cakeSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

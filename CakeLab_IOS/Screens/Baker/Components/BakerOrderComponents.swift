import SwiftUI

// MARK: - BakerOrderFullCard
// Full order card with a progress bar, used for active orders.
struct BakerOrderFullCard: View {
    let order: BakerOrderFull

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(order.cakeName)
                        .font(.urbanistBold(16))
                        .foregroundColor(.cakePrimaryText)
                    HStack(spacing: 5) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.cakeBrown)
                        Text(order.customerName)
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(order.statusLabel)
                        .font(.urbanistSemiBold(11))
                        .foregroundColor(order.statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(order.statusColor.opacity(0.12))
                        .cornerRadius(8)
                    Text(order.amount)
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakeBrown)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    Spacer()
                    Text("\(order.progressPercent)%")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(.cakeBrown)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.cakeBrown.opacity(0.12))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.cakeBrown)
                            .frame(width: geo.size.width * CGFloat(order.progressPercent) / 100, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            HStack {
                Label(order.deliveryDate, systemImage: "calendar")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
                Spacer()
                Label(order.location, systemImage: "location")
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - BakerCompletedOrderCard
// Compact card showing a completed order with star rating.
struct BakerCompletedOrderCard: View {
    let order: BakerOrderFull

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.green)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(order.cakeName)
                    .font(.urbanistSemiBold(14))
                    .foregroundColor(.cakePrimaryText)
                Text(order.customerName)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < order.rating ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.2))
                    }
                    Text("(\(order.rating).0)")
                        .font(.urbanistRegular(11))
                        .foregroundColor(.cakeGrey)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(order.amount)
                    .font(.urbanistBold(14))
                    .foregroundColor(.cakeBrown)
                Text(order.deliveryDate)
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
            }
        }
        .padding(14)
        .background(Color.cakeSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Completed order card built directly from a CakeOrder Firestore model.
struct BakerCompletedOrderCardFromCakeOrder: View {
    let order: CakeOrder
    let customer: BakerOrderCustomerProfile
    let amount: Double

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            orderImage

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    Text(order.cakeName)
                        .font(.urbanistSemiBold(15))
                        .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.10))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(amountText)
                            .font(.urbanistBold(13))
                            .foregroundColor(.cakeBrown)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(red: 0.70, green: 0.70, blue: 0.70))
                    }
                    .frame(minWidth: 76, alignment: .trailing)
                }

                HStack(spacing: 6) {
                    customerProfileImage
                    VStack(alignment: .leading, spacing: 1) {
                        Text(customer.name)
                            .font(.urbanistSemiBold(12))
                            .foregroundColor(Color(red: 0.22, green: 0.22, blue: 0.22))
                            .lineLimit(1)
                        Text(customer.displayLocation)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10, weight: .semibold))
                        Text(order.formattedDeliveryDate)
                            .font(.urbanistSemiBold(11))
                    }
                    .foregroundColor(.cakeBrown)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.96, green: 0.94, blue: 0.91))
                    .clipShape(Capsule())

                    statusBadge
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cakeSurface)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var amountText: String {
        amount > 0 ? "LKR \(Int(amount).formatted())" : "LKR 0"
    }

    private var orderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.95, green: 0.93, blue: 0.90))

            if let firstReferenceImage = order.referenceImages.first,
               let imageData = Data(base64Encoded: firstReferenceImage),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipped()
            } else if let imageURL = order.imageURL, !imageURL.isEmpty, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        orderImageFallback
                    }
                }
                .frame(width: 72, height: 72)
                .clipped()
            } else {
                orderImageFallback
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var orderImageFallback: some View {
        Image(systemName: "birthday.cake.fill")
            .font(.system(size: 28))
            .foregroundColor(.cakeBrown.opacity(0.42))
    }

    private var customerProfileImage: some View {
        Group {
            if let image = decodeBase64Image(customer.profileImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: customer.imageURL), !customer.imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        customerProfileFallback
                    }
                }
            } else {
                customerProfileFallback
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }

    private var customerProfileFallback: some View {
        Circle()
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.cakeBrown.opacity(0.5))
            )
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Delivered")
                .font(.urbanistSemiBold(11))
        }
        .foregroundColor(Color(red: 0.18, green: 0.58, blue: 0.25))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(red: 0.90, green: 0.97, blue: 0.91))
        .clipShape(Capsule())
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            payload = trimmed
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Active order card with progress tracker and customer info, built from a CakeOrder.
struct BakerActiveOrderCardFromCakeOrder: View {
    let order: CakeOrder
    let customer: BakerOrderCustomerProfile

    private let stepLabels = ["Confirmed", "Baking", "Decorating", "Quality\nChecking", "Delivered"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
                        .frame(width: 80, height: 80)

                    if !order.referenceImages.isEmpty,
                       let imageData = Data(base64Encoded: order.referenceImages[0]),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "birthday.cake.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.cakeBrown.opacity(0.4))
                    }
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 0) {
                    Text(order.cakeName)
                        .font(.urbanistBold(15))
                        .foregroundColor(.cakePrimaryText)
                        .lineLimit(2)

                    HStack(alignment: .top, spacing: 10) {
                        Text(order.statusLabel)
                            .font(.urbanistSemiBold(11))
                            .foregroundColor(order.statusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(order.statusColor.opacity(0.12))
                            .cornerRadius(8)

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Delivery Date:")
                                .font(.urbanistRegular(11))
                                .foregroundColor(.cakeGrey)
                            Text(order.formattedDeliveryDate)
                                .font(.urbanistSemiBold(12))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                        }
                    }
                    .padding(.top, 14)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            OrderProgressTracker(currentStep: order.currentStep, labels: stepLabels)
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 18)

            HStack(spacing: 12) {
                customerProfileImage

                VStack(alignment: .leading, spacing: 3) {
                    Text(customer.name)
                        .font(.urbanistBold(14))
                        .foregroundColor(.cakePrimaryText)

                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cakeGrey)
                            .padding(.top, 2)
                        Text(customer.displayLocation)
                            .font(.urbanistRegular(11))
                            .foregroundColor(.cakeGrey)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color.cakeSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 3)
    }

    private var customerProfileImage: some View {
        Group {
            if let image = decodeBase64Image(customer.profileImageBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: customer.imageURL), !customer.imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        customerProfilePlaceholder
                    }
                }
            } else {
                customerProfilePlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    private var customerProfilePlaceholder: some View {
        Circle()
            .fill(Color(red: 0.92, green: 0.90, blue: 0.87))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.cakeBrown.opacity(0.5))
            )
    }

    private func decodeBase64Image(_ rawBase64: String) -> UIImage? {
        let trimmed = rawBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let payload: String
        if let commaIndex = trimmed.firstIndex(of: ",") {
            payload = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            payload = trimmed
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return UIImage(data: data)
    }
}

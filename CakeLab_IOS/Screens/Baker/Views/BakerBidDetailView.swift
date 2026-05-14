import SwiftUI

// MARK: - Baker Bid Detail View
@MainActor
struct BakerBidDetailView: View {
    let request: CakeRequest

    @EnvironmentObject var notificationManager: NotificationManager
    @StateObject private var vm = BakerBidDetailViewModel()
    @State private var showAllSpecifications = false
    @State private var bidAmount = ""
    @State private var deliveryNote = ""
    @State private var canDeliverOnTime = true
    @State private var alternativeDate = Date()
    @State private var showDatePicker = false
    @State private var bidMessage = ""
    @State private var showConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private var formattedAlternativeDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, yyyy"
        return f.string(from: alternativeDate)
    }

    private var parsedBidAmount: Double? {
        let normalized = bidAmount
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    private var canPlaceBid: Bool {
        parsedBidAmount != nil && !vm.isSubmittingBid
    }

    var body: some View {
        ZStack {
            Color.cakeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        
                        requestDetailsCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 20)

                        
                        specsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        
                        bidFormSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if showConfirmation { confirmationOverlay }
            }
        )
        .alert(
            "Unable to Submit Bid",
            isPresented: Binding(
                get: { vm.submissionError != nil },
                set: { if !$0 { vm.submissionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { vm.submissionError = nil }
        } message: {
            Text(vm.submissionError ?? "")
        }
    }

    // MARK: - Request Details Card
    private var requestDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(request.title)
                        .font(.urbanistBold(18))
                        .foregroundColor(.cakePrimaryText)
                        .lineLimit(nil)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cakeBrown)
                    Text(request.customerName)
                        .font(.urbanistSemiBold(13))
                        .foregroundColor(.cakeGrey)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(request.postedTime)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeGrey)
                    .lineLimit(1)
            }

            Divider()

            Text(request.description)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineSpacing(4)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    categoryMetaBlock
                    metaDivider
                    compactMetaItem(label: "Customer Location", value: request.location)
                    metaDivider
                    compactMetaItem(label: "Bids", value: "\(request.bidCount) bid\(request.bidCount == 1 ? "" : "s")")
                }
                HStack(spacing: 12) {
                    categoryMetaBlock
                    metaDivider
                    compactMetaItem(label: "Customer Location", value: request.location)
                }
            }
        }
        .padding(18)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private var categoryMetaBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Category")
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
                .lineLimit(1)

            Text(request.category.name)
                .font(.urbanistMedium(12))
                .foregroundColor(categoryTextColor(for: request.category.name))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(categoryBackgroundColor(for: request.category.name))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.12))
            .frame(width: 1, height: 34)
    }

    private func compactMetaItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)
            Text(value)
                .font(.urbanistSemiBold(12))
                .foregroundColor(.cakePrimaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoLine(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.cakeBrown)
                .frame(width: 18)

            Text(label)
                .font(.urbanistRegular(12))
                .foregroundColor(.cakeGrey)

            Text(value)
                .font(.urbanistSemiBold(12))
                .foregroundColor(.cakePrimaryText)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }

    // MARK: - Customer Specs
    private var specsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Cake Specifications")
                    .font(.urbanistBold(16))
                    .foregroundColor(.cakePrimaryText)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllSpecifications.toggle()
                    }
                } label: {
                    Text(showAllSpecifications ? "See less" : "See all")
                        .font(.urbanistSemiBold(12))
                        .foregroundColor(.cakeBrown)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                specItem(icon: "banknote.fill", label: "Budget", value: request.budgetRange)
                specItem(icon: "calendar", label: "Delivery Date", value: request.deliveryDate)
                specItem(icon: "clock.fill", label: "Delivery Time", value: request.deliveryTime)
                specItem(icon: "birthday.cake.fill", label: "Cake Size", value: request.cakeSize)
            }

            if showAllSpecifications {
                VStack(spacing: 12) {
                    expandedSpecRow(label: "Category", value: request.category.name)
                    expandedSpecRow(label: "Tiers", value: request.servings > 0 ? "\(request.servings)" : "Not specified")
                    expandedSpecRow(label: "Budget", value: request.budgetRange)
                    expandedSpecRow(label: "Delivery Date", value: request.deliveryDate)
                    expandedSpecRow(label: "Delivery Time", value: request.deliveryTime)
                    expandedSpecRow(label: "Cake Size", value: request.cakeSize)
                    expandedSpecRow(label: "Sugar Level", value: sugarLevelText)
                    expandedSpecRow(label: "Flavours", value: joinedOrFallback(request.flavours))
                    expandedSpecRow(label: "Styles", value: joinedOrFallback(request.styles))
                    expandedSpecRow(label: "Dietary", value: joinedOrFallback(request.dietary))
                    expandedSpecRow(label: "Filling Flavour", value: fallbackText(request.fillingFlavour))
                    expandedSpecRow(label: "Special Instructions", value: fallbackText(request.specialInstructions), multiline: true)

                    if !request.referenceImages.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Customer Uploaded Images")
                                .font(.urbanistSemiBold(12))
                                .foregroundColor(.cakeGrey)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(request.referenceImages.indices, id: \.self) { index in
                                        if let imageData = Data(base64Encoded: request.referenceImages[index]),
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 78, height: 78)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func specItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cakeBrown.opacity(0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.cakeBrown)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.urbanistRegular(10))
                    .foregroundColor(.cakeGrey)
                Text(value)
                    .font(.urbanistSemiBold(12))
                    .foregroundColor(.cakePrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(red: 236/255, green: 230/255, blue: 225/255))
        .cornerRadius(12)
    }

    // MARK: - Bid Form
    private var bidFormSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Place Your Bid")
                .font(.urbanistBold(16))
                .foregroundColor(.cakePrimaryText)

            // Bid Amount
            VStack(alignment: .leading, spacing: 8) {
                Label("Your Bid Amount (LKR)", systemImage: "banknote")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                HStack {
                    Text("LKR")
                        .font(.urbanistBold(16))
                        .foregroundColor(.cakeBrown)
                        .padding(.leading, 14)
                    TextField("e.g. 12000", text: $bidAmount)
                        .keyboardType(.numberPad)
                        .font(.urbanistSemiBold(16))
                        .padding(.trailing, 14)
                        .padding(.vertical, 14)
                        .onChange(of: bidAmount) { newValue in
                            let filtered = newValue.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == " " }
                            if filtered != newValue {
                                bidAmount = filtered
                            }
                        }
                }
                .background(Color.cakeSurface)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(parsedBidAmount == nil ? Color(red: 0.88, green: 0.88, blue: 0.88) : Color.cakeBrown, lineWidth: 1.5)
                )
            }

            // Delivery Confirmation
            VStack(alignment: .leading, spacing: 10) {
                Label("Can you deliver by \(request.deliveryDate)?", systemImage: "calendar.badge.checkmark")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))

                HStack(spacing: 12) {
                    deliveryOptionButton(title: "Yes, I can!", isSelected: canDeliverOnTime) {
                        withAnimation { canDeliverOnTime = true }
                    }
                    deliveryOptionButton(title: "I need different date", isSelected: !canDeliverOnTime) {
                        withAnimation { canDeliverOnTime = false }
                    }
                }

                if !canDeliverOnTime {
                    Button {
                        withAnimation { showDatePicker.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.cakeBrown)
                            Text(formattedAlternativeDate)
                                .font(.urbanistMedium(14))
                                .foregroundColor(.cakePrimaryText)
                            Spacer()
                            Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                                .foregroundColor(.cakeGrey)
                        }
                        .padding(14)
                        .background(Color.cakeSurface)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cakeBrown, lineWidth: 1.5))
                    }

                    if showDatePicker {
                        DatePicker("Alternative Delivery Date", selection: $alternativeDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.cakeBrown)
                            .padding(10)
                            .background(Color.cakeSurface)
                            .cornerRadius(14)
                    }
                }
            }

            // Message to customer
            VStack(alignment: .leading, spacing: 8) {
                Label("Message to Customer", systemImage: "bubble.left")
                    .font(.urbanistSemiBold(13))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $bidMessage)
                        .font(.urbanistRegular(14))
                        .frame(minHeight: 100)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                    if bidMessage.isEmpty {
                        Text("Tell the customer why you're the best baker for this cake, your experience with similar orders, etc...")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey.opacity(0.7))
                            .padding(.top, 20)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }
                .background(Color.cakeSurface)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.88, green: 0.88, blue: 0.88), lineWidth: 1.5)
                )

                Text("\(bidMessage.count)/500")
                    .font(.urbanistRegular(11))
                    .foregroundColor(.cakeGrey)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            submitArea
        }
        .padding(18)
        .background(Color.cakeSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func deliveryOptionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .cakeBrown : .cakeGrey)
                Text(title)
                    .font(.urbanistMedium(13))
                    .foregroundColor(isSelected ? .cakeBrown : Color(red: 0.35, green: 0.35, blue: 0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.cakeBrown.opacity(0.1) : Color(red: 0.95, green: 0.95, blue: 0.95))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.cakeBrown : Color.clear, lineWidth: 1.5))
        }
    }

    // MARK: - Submit Area
    private var submitArea: some View {
        VStack(spacing: 14) {
            Divider()

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Bid Amount")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    Text(bidAmount.isEmpty ? "Enter amount" : "LKR \(bidAmount)")
                        .font(.urbanistBold(18))
                        .foregroundColor(parsedBidAmount == nil ? .cakeGrey : .cakeBrown)
                }

                Spacer()
            }

            Button {
                if canPlaceBid {
                    showConfirmation = true
                } else {
                    vm.submissionError = "Enter a valid bid amount before continuing."
                }
            } label: {
                Text("Place Bid")
                    .font(.urbanistBold(15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canPlaceBid ? Color.cakeBrown : Color.cakeGrey.opacity(0.4))
                    .cornerRadius(16)
            }
            .disabled(!canPlaceBid)
        }
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
                    .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            }

            Spacer()

            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.cakeSurface)
    }

    private func expandedSpecRow(label: String, value: String, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.urbanistRegular(11))
                .foregroundColor(.cakeGrey)

            Text(value)
                .font(.urbanistSemiBold(13))
                .foregroundColor(.cakePrimaryText)
                .fixedSize(horizontal: false, vertical: multiline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(red: 236/255, green: 230/255, blue: 225/255))
        .cornerRadius(12)
    }

    private func joinedOrFallback(_ values: [String]) -> String {
        let cleaned = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return cleaned.isEmpty ? "Not specified" : cleaned.joined(separator: ", ")
    }

    private func fallbackText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not specified" : trimmed
    }

    private var sugarLevelText: String {
        "\(Int((request.sugarLevel * 100).rounded()))%"
    }

    private func categoryBackgroundColor(for category: String) -> Color {
        let categoryLower = category.lowercased()
        switch categoryLower {
        case let cat where cat.contains("wedding"):
            return Color(red: 1.0, green: 0.95, blue: 0.97)
        case let cat where cat.contains("birthday"):
            return Color(red: 0.99, green: 0.95, blue: 0.90)
        case let cat where cat.contains("anniversary"):
            return Color(red: 0.95, green: 0.99, blue: 0.95)
        case let cat where cat.contains("baby"):
            return Color(red: 0.98, green: 0.96, blue: 1.0)
        case let cat where cat.contains("cupcake"):
            return Color(red: 1.0, green: 0.98, blue: 0.94)
        case let cat where cat.contains("buttercream"):
            return Color(red: 0.99, green: 1.0, blue: 0.95)
        case let cat where cat.contains("corporate"):
            return Color(red: 0.95, green: 0.98, blue: 1.0)
        case let cat where cat.contains("engagement"):
            return Color(red: 1.0, green: 0.96, blue: 0.92)
        case let cat where cat.contains("graduation"):
            return Color(red: 0.94, green: 0.97, blue: 1.0)
        case let cat where cat.contains("baptism"):
            return Color(red: 0.96, green: 0.99, blue: 1.0)
        case let cat where cat.contains("retirement"):
            return Color(red: 1.0, green: 0.96, blue: 0.94)
        case let cat where cat.contains("farewell"):
            return Color(red: 0.98, green: 0.97, blue: 1.0)
        case let cat where cat.contains("vegan"):
            return Color(red: 0.96, green: 1.0, blue: 0.96)
        case let cat where cat.contains("sculpted"):
            return Color(red: 0.98, green: 0.95, blue: 0.99)
        default:
            return Color(red: 0.96, green: 0.96, blue: 0.96)
        }
    }

    private func categoryTextColor(for category: String) -> Color {
        let categoryLower = category.lowercased()
        switch categoryLower {
        case let cat where cat.contains("wedding"):
            return Color(red: 0.8, green: 0.3, blue: 0.6)
        case let cat where cat.contains("birthday"):
            return Color(red: 0.85, green: 0.5, blue: 0.25)
        case let cat where cat.contains("anniversary"):
            return Color(red: 0.2, green: 0.6, blue: 0.4)
        case let cat where cat.contains("baby"):
            return Color(red: 0.6, green: 0.3, blue: 0.8)
        case let cat where cat.contains("cupcake"):
            return Color(red: 0.8, green: 0.5, blue: 0.2)
        case let cat where cat.contains("buttercream"):
            return Color(red: 0.7, green: 0.6, blue: 0.1)
        case let cat where cat.contains("corporate"):
            return Color(red: 0.2, green: 0.5, blue: 0.8)
        case let cat where cat.contains("engagement"):
            return Color(red: 0.85, green: 0.35, blue: 0.3)
        case let cat where cat.contains("graduation"):
            return Color(red: 0.3, green: 0.5, blue: 0.7)
        case let cat where cat.contains("baptism"):
            return Color(red: 0.2, green: 0.6, blue: 0.7)
        case let cat where cat.contains("retirement"):
            return Color(red: 0.8, green: 0.4, blue: 0.3)
        case let cat where cat.contains("farewell"):
            return Color(red: 0.5, green: 0.3, blue: 0.7)
        case let cat where cat.contains("vegan"):
            return Color(red: 0.2, green: 0.7, blue: 0.2)
        case let cat where cat.contains("sculpted"):
            return Color(red: 0.7, green: 0.2, blue: 0.7)
        default:
            return Color(red: 0.4, green: 0.4, blue: 0.4)
        }
    }

    // MARK: - Confirmation Overlay
    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle().fill(Color.cakeBrown.opacity(0.12)).frame(width: 70, height: 70)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.cakeBrown)
                }

                Text("Confirm Your Bid")
                    .font(.urbanistBold(20))
                    .foregroundColor(.cakePrimaryText)

                VStack(spacing: 8) {
                    confirmRow(label: "Cake Request", value: request.title)
                    confirmRow(label: "Customer", value: request.customerName)
                    confirmRow(label: "Your Bid", value: "LKR \(bidAmount)")
                    confirmRow(label: "Delivery", value: canDeliverOnTime ? request.deliveryDate : formattedAlternativeDate)
                }

                HStack(spacing: 14) {
                    Button {
                        showConfirmation = false
                    } label: {
                        Text("Go Back")
                            .font(.urbanistSemiBold(15))
                            .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.35))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.92, green: 0.92, blue: 0.92))
                            .cornerRadius(14)
                    }
                    Button {
                        Task {
                            await vm.submitBid(
                                request: request,
                                bidAmount: bidAmount,
                                parsedAmount: parsedBidAmount ?? 0,
                                bidMessage: bidMessage,
                                deliveryNote: deliveryNote,
                                canDeliverOnTime: canDeliverOnTime,
                                alternativeDate: alternativeDate,
                                notificationManager: notificationManager,
                                onSuccess: {
                                    showConfirmation = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
                                }
                            )
                        }
                    } label: {
                        if vm.isSubmittingBid {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Submit Bid")
                        }
                    }
                    .disabled(vm.isSubmittingBid)
                    .opacity(vm.isSubmittingBid ? 0.8 : 1)
                    .font(.urbanistBold(15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cakeBrown)
                    .cornerRadius(14)
                }
            }
            .padding(24)
            .background(Color.cakeSurface)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.3), value: showConfirmation)
    }

    private func confirmRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)
            Spacer()
            Text(value)
                .font(.urbanistSemiBold(13))
                .foregroundColor(.cakePrimaryText)
        }
        .padding(.vertical, 6)
        .overlay(Divider().padding(.top, 28), alignment: .bottom)
    }
    
}

#Preview {
    NavigationStack {
        BakerBidDetailView(request: BakerHomePreviewData.matchingRequests[0])
    }
}

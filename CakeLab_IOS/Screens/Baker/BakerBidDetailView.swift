import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Baker Bid Detail View
@MainActor
struct BakerBidDetailView: View {
    let request: CakeRequest

    @State private var bidAmount = ""
    @State private var deliveryNote = ""
    @State private var canDeliverOnTime = true
    @State private var alternativeDate = Date()
    @State private var showDatePicker = false
    @State private var bidMessage = ""
    @State private var showConfirmation = false
    @State private var bidSubmitted = false
    @State private var isSubmittingBid = false
    @Environment(\.dismiss) private var dismiss

    private var formattedAlternativeDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, yyyy"
        return f.string(from: alternativeDate)
    }

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.96, blue: 0.94).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: Request Details Card
                    requestDetailsCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                    // MARK: Customer Specs
                    specsSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // MARK: Bid Form
                    bidFormSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                }
            }

            // MARK: Sticky Submit Button
            VStack {
                Spacer()
                submitArea
            }
        }
        .navigationTitle("Cake Request Details")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            Group {
                if showConfirmation { confirmationOverlay }
            }
        )
    }

    // MARK: - Request Details Card
    private var requestDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(request.title)
                        .font(.urbanistBold(20))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.cakeBrown)
                        Text("by \(request.customerName)")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)
                        Text("•")
                            .foregroundColor(.cakeGrey)
                        Text(request.postedTime)
                            .font(.urbanistRegular(12))
                            .foregroundColor(.cakeGrey)
                    }
                }
                Spacer()
                // Budget badge
                VStack(spacing: 2) {
                    Text("Budget")
                        .font(.urbanistRegular(10))
                        .foregroundColor(.cakeGrey)
                    Text(request.budgetRange)
                        .font(.urbanistBold(13))
                        .foregroundColor(.cakeBrown)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cakeBrown.opacity(0.1))
                .cornerRadius(12)
            }

            Divider()

            Text(request.description)
                .font(.urbanistRegular(14))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                .lineSpacing(4)

            // Tagged chips
            HStack(spacing: 8) {
                requestChip(icon: "location", text: request.location)
                requestChip(icon: "calendar", text: request.deliveryDate)
                requestChip(icon: "person.2", text: "\(request.bidCount) bids")
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func requestChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.urbanistMedium(11))
        }
        .foregroundColor(.cakeBrown)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.cakeBrown.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Customer Specs
    private var specsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cake Specifications")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                specItem(icon: "person.3.fill", label: "Servings", value: "\(request.servings) people")
                specItem(icon: "birthday.cake.fill", label: "Category", value: request.category.name)
                specItem(icon: "drop.fill", label: "Flavours", value: request.flavours.joined(separator: ", "))
                specItem(icon: "clock", label: "Delivery", value: request.deliveryDate)
            }
        }
        .padding(18)
        .background(Color.white)
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
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(red: 0.97, green: 0.96, blue: 0.94))
        .cornerRadius(12)
    }

    // MARK: - Bid Form
    private var bidFormSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Place Your Bid")
                .font(.urbanistBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

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
                }
                .background(Color.white)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(bidAmount.isEmpty ? Color(red: 0.88, green: 0.88, blue: 0.88) : Color.cakeBrown, lineWidth: 1.5)
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
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Spacer()
                            Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                                .foregroundColor(.cakeGrey)
                        }
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cakeBrown, lineWidth: 1.5))
                    }

                    if showDatePicker {
                        DatePicker("Alternative Delivery Date", selection: $alternativeDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.cakeBrown)
                            .padding(10)
                            .background(Color.white)
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
                .background(Color.white)
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
        }
        .padding(18)
        .background(Color.white)
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
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                // Summary
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your bid")
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                    Text(bidAmount.isEmpty ? "Enter amount" : "LKR \(bidAmount)")
                        .font(.urbanistBold(18))
                        .foregroundColor(bidAmount.isEmpty ? .cakeGrey : .cakeBrown)
                }
                Spacer()
                Button {
                    if !bidAmount.isEmpty {
                        showConfirmation = true
                    }
                } label: {
                    Text("Place Bid")
                        .font(.urbanistBold(15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(bidAmount.isEmpty ? Color.cakeGrey.opacity(0.4) : Color.cakeBrown)
                        .cornerRadius(16)
                }
                .disabled(bidAmount.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .padding(.bottom, 4)
            .background(Color.white)
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
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

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
                            await submitBid()
                        }
                    } label: {
                        if isSubmittingBid {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Submit Bid")
                        }
                    }
                    .disabled(isSubmittingBid)
                    .opacity(isSubmittingBid ? 0.8 : 1)
                    .font(.urbanistBold(15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cakeBrown)
                    .cornerRadius(14)
                }
            }
            .padding(24)
            .background(Color.white)
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
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
        }
        .padding(.vertical, 6)
        .overlay(Divider().padding(.top, 28), alignment: .bottom)
    }
    
    private func submitBid() async {
        guard let bakerID = Auth.auth().currentUser?.uid,
              let amount = Double(bidAmount),
              !request.requestDocumentID.isEmpty else {
            return
        }
        
        isSubmittingBid = true
        
        let db = Firestore.firestore()
        let bidDocumentID = "\(request.requestDocumentID)_\(bakerID)"
        let bidRef = db.collection("bids").document(bidDocumentID)
        let requestRef = db.collection("cakeRequests").document(request.requestDocumentID)
        
        do {
            let bakerProfile = try await db.collection("users").document(bakerID).getDocument()
            let bakerData = bakerProfile.data() ?? [:]
            let bidSnapshot = try await bidRef.getDocument()
            let alreadyExists = bidSnapshot.exists
            let bakerName = (bakerData["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            let bidPayload: [String: Any] = [
                "requestDocumentID": request.requestDocumentID,
                "customerID": request.customerID,
                "bakerID": bakerID,
                "bakerName": bakerName.isEmpty ? (Auth.auth().currentUser?.email ?? "Baker") : bakerName,
                "amount": amount,
                "message": bidMessage,
                "deliveryNote": deliveryNote,
                "canDeliverOnTime": canDeliverOnTime,
                "alternativeDate": canDeliverOnTime ? NSNull() : alternativeDate.timeIntervalSince1970,
                "submittedAt": Date().timeIntervalSince1970
            ]
            
            try await bidRef.setData(bidPayload, merge: true)
            
            if !alreadyExists {
                try await db.runTransaction { transaction, _ in
                    let snapshot = try? transaction.getDocument(requestRef)
                    let currentCount = snapshot?.data()?[("bidCount")] as? Int ?? 0
                    transaction.updateData(["bidCount": currentCount + 1], forDocument: requestRef)
                    return nil
                }
            }
            
            bidSubmitted = true
            showConfirmation = false
            isSubmittingBid = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        } catch {
            isSubmittingBid = false
            print("Error submitting bid: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        BakerBidDetailView(request: mockMatchingRequests[0])
    }
}

import SwiftUI
import FirebaseFirestore

struct ReviewModalView: View {
    @Binding var isPresented: Bool
    let bakerName: String
    let orderID: String
    let artisanId: String
    let customerId: String

    @State private var rating: Int = 5
    @State private var reviewText: String = ""
    @State private var isSubmitting = false
    @State private var showSuccessMessage = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let db = Firestore.firestore()
    private let maxReviewLength = 500

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGray6).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title Section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("How is your order?")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            
                            Text("Share your experience with \(bakerName)")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.cakeGrey)
                        }

                        // Rating Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your overall rating")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                            HStack(spacing: 16) {
                                ForEach(1...5, id: \.self) { star in
                                    Button {
                                        rating = star
                                    } label: {
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(.system(size: 32))
                                            .foregroundColor(star <= rating ? Color(red: 1.0, green: 0.78, blue: 0.1) : Color(red: 0.85, green: 0.85, blue: 0.85))
                                    }
                                }
                                Spacer()
                            }
                        }

                        // Review Text Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Write your review")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .frame(minHeight: 120)

                                if reviewText.isEmpty {
                                    Text("Tell us more about your order...")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                        .padding(12)
                                }

                                TextEditor(text: $reviewText)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                    .padding(12)
                                    .scrollContentBackground(.hidden)
                            }

                            HStack {
                                Spacer()
                                Text("\(reviewText.count)/\(maxReviewLength)")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.cakeGrey)
                            }
                        }

                        // Photo Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add a photo (optional)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                            HStack(spacing: 12) {
                                Button {
                                    // Gallery action
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.stack.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.cakeBrown)
                                        Text("Gallery")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.cakeBrown)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(red: 0.92, green: 0.90, blue: 0.87), lineWidth: 2)
                                    )
                                }

                                Button {
                                    // Camera action
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.cakeBrown)
                                        Text("Camera")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.cakeBrown)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(red: 0.92, green: 0.90, blue: 0.87), lineWidth: 2)
                                    )
                                }
                            }
                        }

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(20)
                }

                if showSuccessMessage {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Thank you!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        Text("Your review has been posted")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.cakeGrey)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.95))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(.cakeBrown)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.cakeBrown)
                    } else {
                        Button("Submit") {
                            submitReview()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cakeBrown)
                        .disabled(reviewText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(reviewText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                    }
                }
            }
        }
    }

    private func submitReview() {
        isSubmitting = true
        errorMessage = nil

        let review: [String: Any] = [
            "orderID": orderID,
            "artisanId": artisanId,
            "customerId": customerId,
            "rating": rating,
            "reviewText": reviewText.trimmingCharacters(in: .whitespaces),
            "createdAt": Timestamp(date: Date()),
            "bakerName": bakerName
        ]

        db.collection("reviews").document().setData(review) { error in
            DispatchQueue.main.async {
                self.isSubmitting = false

                if let error {
                    self.errorMessage = "Failed to submit review: \(error.localizedDescription)"
                } else {
                    self.showSuccessMessage = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    ReviewModalView(
        isPresented: .constant(true),
        bakerName: "Cake Haven by Dinithi",
        orderID: "B001",
        artisanId: "artisan123",
        customerId: "customer123"
    )
}

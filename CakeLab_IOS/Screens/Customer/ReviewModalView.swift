import SwiftUI
import PhotosUI
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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImages: [UIImage] = []
    @State private var reviewImagesBase64: [String] = []
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @Environment(\.dismiss) private var dismiss

    private let db = Firestore.firestore()
    private let maxReviewLength = 500
    private let maxPhotoCount = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBar

                ZStack {
                    Color.white.ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("How is your order?")
                                    .font(.urbanistBold(28))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                                Text("Share your experience with \(bakerName)")
                                    .font(.urbanistRegular(15))
                                    .foregroundColor(.cakeGrey)
                            }

                            // Rating Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your overall rating")
                                    .font(.urbanistSemiBold(16))
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
                                    .font(.urbanistSemiBold(16))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .frame(minHeight: 120)

                                    if reviewText.isEmpty {
                                        Text("Tell us more about your order...")
                                            .font(.urbanistRegular(16))
                                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                            .padding(12)
                                    }

                                    TextEditor(text: $reviewText)
                                        .font(.urbanistRegular(16))
                                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                        .padding(12)
                                        .scrollContentBackground(.hidden)
                                }

                                HStack {
                                    Spacer()
                                    Text("\(reviewText.count)/\(maxReviewLength)")
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.cakeGrey)
                                }
                            }

                            photoSection

                            submitButton

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.urbanistRegular(12))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.08))
                                    .cornerRadius(10)
                            }

                            Spacer()
                                .frame(height: 20)
                        }
                        .padding(20)
                        .padding(.bottom, 30)
                    }

                    if showSuccessMessage {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("Thank you!")
                                .font(.urbanistSemiBold(18))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            Text("Your review has been posted")
                                .font(.urbanistRegular(14))
                                .foregroundColor(.cakeGrey)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.95))
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCamera) {
                CameraPickerView(capturedImage: $capturedImage, isPresented: $showCamera)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { item in
                Task {
                    await appendGalleryImage(item)
                }
            }
            .onChange(of: capturedImage) { image in
                appendImage(image)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cakeBrown)
                    .frame(width: 64, alignment: .leading)
            }
            Spacer()
            Text("Write Review")
                .font(.urbanistBold(18))
                .foregroundColor(Color(red: 0.365, green: 0.216, blue: 0.078))
            Spacer()
            Color.clear.frame(width: 64)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.white)
    }

    private var submitButton: some View {
        Button {
            submitReview()
        } label: {
            Group {
                if isSubmitting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Submitting...")
                    }
                } else {
                    Text("Submit Review")
                }
            }
            .font(.urbanistBold(16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.cakeBrown)
            .clipShape(Capsule())
        }
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.45)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a photo (optional)")
                .font(.urbanistSemiBold(16))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 78, height: 78)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Button {
                                    removeImage(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.35)))
                                }
                                .padding(5)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    photoActionContent(icon: "photo.stack.fill", title: "Gallery")
                }
                .disabled(selectedImages.count >= maxPhotoCount)
                .opacity(selectedImages.count >= maxPhotoCount ? 0.45 : 1)

                Button {
                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                        errorMessage = "Camera is not available on this device."
                        return
                    }
                    errorMessage = nil
                    showCamera = true
                } label: {
                    photoActionContent(icon: "camera.fill", title: "Camera")
                }
                .disabled(selectedImages.count >= maxPhotoCount)
                .opacity(selectedImages.count >= maxPhotoCount ? 0.45 : 1)
            }
        }
    }

    private func photoActionContent(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.cakeBrown)
            Text(title)
                .font(.urbanistMedium(13))
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

    private var canSubmit: Bool {
        !isSubmitting && !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func appendGalleryImage(_ item: PhotosPickerItem?) async {
        guard let item, selectedImages.count < maxPhotoCount else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Could not read the selected photo."
                selectedPhotoItem = nil
                return
            }
            appendImage(image)
        } catch {
            errorMessage = "Could not load the selected photo. \(error.localizedDescription)"
        }
        selectedPhotoItem = nil
    }

    private func appendImage(_ image: UIImage?) {
        guard let image, selectedImages.count < maxPhotoCount else { return }
        guard let base64 = encodeImageToBase64(image) else {
            errorMessage = "Could not prepare the photo for upload."
            return
        }

        selectedImages.append(image)
        reviewImagesBase64.append(base64)
        errorMessage = nil
        capturedImage = nil
    }

    private func removeImage(at index: Int) {
        guard selectedImages.indices.contains(index), reviewImagesBase64.indices.contains(index) else { return }
        selectedImages.remove(at: index)
        reviewImagesBase64.remove(at: index)
    }

    private func encodeImageToBase64(_ image: UIImage) -> String? {
        let resizedImage = resized(image, maxDimension: 900)
        guard let data = resizedImage.jpegData(compressionQuality: 0.72) else { return nil }
        return data.base64EncodedString()
    }

    private func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return image }

        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func submitReview() {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let customerProfile = await loadCustomerProfile()
                let trimmedReview = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
                let customerName = customerProfile.name.isEmpty ? "Customer" : customerProfile.name

                let review: [String: Any] = [
                    "orderID": orderID,
                    "bakerID": artisanId,
                    "artisanId": artisanId,
                    "customerID": customerId,
                    "customerId": customerId,
                    "customerName": customerName,
                    "customerImage": customerProfile.imageBase64,
                    "rating": rating,
                    "comment": trimmedReview,
                    "reviewText": trimmedReview,
                    "reviewImagesBase64": reviewImagesBase64,
                    "createdAt": Timestamp(date: Date()),
                    "bakerName": bakerName
                ]

                try await db.collection("reviews").document().setData(review)
                await updateBakerReviewStats()

                isSubmitting = false
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.isPresented = false
                }
            } catch {
                isSubmitting = false
                errorMessage = "Failed to submit review: \(error.localizedDescription)"
            }
        }
    }

    private func loadCustomerProfile() async -> (name: String, imageBase64: String) {
        guard !customerId.isEmpty else { return ("", "") }

        do {
            let document = try await db.collection("users").document(customerId).getDocument()
            let data = document.data() ?? [:]
            let name = (data["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let remoteImageBase64 = firstString(
                data["profileImageBase64"],
                data["avatarBase64"],
                data["photoBase64"]
            )
            let localImageBase64 = UserDefaults.standard.string(forKey: "profileAvatar_\(customerId)") ?? ""
            let imageBase64 = firstString(remoteImageBase64, localImageBase64)

            if remoteImageBase64.isEmpty && !imageBase64.isEmpty {
                try? await db.collection("users").document(customerId).setData([
                    "profileImageBase64": imageBase64,
                    "avatarBase64": imageBase64,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            }

            return (name, imageBase64)
        } catch {
            let localImageBase64 = UserDefaults.standard.string(forKey: "profileAvatar_\(customerId)") ?? ""
            return ("", localImageBase64)
        }
    }

    private func firstString(_ values: Any?...) -> String {
        values.compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private func updateBakerReviewStats() async {
        guard !artisanId.isEmpty else { return }

        do {
            let snapshot = try await db.collection("reviews")
                .whereField("bakerID", isEqualTo: artisanId)
                .getDocuments()

            let ratings = snapshot.documents.compactMap { document -> Int? in
                document.data()["rating"] as? Int
            }
            guard !ratings.isEmpty else { return }

            let average = Double(ratings.reduce(0, +)) / Double(ratings.count)
            let stats: [String: Any] = [
                "rating": average,
                "reviewCount": ratings.count
            ]

            try await db.collection("artisans").document(artisanId).setData(stats, merge: true)
            try? await db.collection("users").document(artisanId).setData(stats, merge: true)
        } catch {
            print("Error updating baker review stats: \(error.localizedDescription)")
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

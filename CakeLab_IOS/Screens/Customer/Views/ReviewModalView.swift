import SwiftUI
import PhotosUI

// MARK: - Review Modal View
struct ReviewModalView: View {
    @Binding var isPresented: Bool
    let bakerName: String
    let orderID: String
    let artisanId: String
    let customerId: String

    @StateObject private var reviewVM = ReviewModalViewModel()
    @State private var rating: Int = 5
    @State private var reviewText: String = ""
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImages: [UIImage] = []
    @State private var reviewImagesBase64: [String] = []
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @Environment(\.dismiss) private var dismiss

    private let maxReviewLength = 500
    private let maxPhotoCount = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBar

                ZStack {
                    Color.cakeBackground.ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            // Review intro title.
                            VStack(alignment: .leading, spacing: 6) {
                                Text("How is your order?")
                                    .font(.urbanistBold(28))
                                    .foregroundColor(.cakePrimaryText)

                                Text("Share your experience with \(bakerName)")
                                    .font(.urbanistRegular(15))
                                    .foregroundColor(.cakeGrey)
                            }

                            // MARK: Rating Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your overall rating")
                                    .font(.urbanistSemiBold(16))
                                    .foregroundColor(.cakePrimaryText)

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

                            // MARK: Review Text Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Write your review")
                                    .font(.urbanistSemiBold(16))
                                    .foregroundColor(.cakePrimaryText)

                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.cakeSurface)
                                        .frame(minHeight: 120)

                                    if reviewText.isEmpty {
                                        Text("Tell us more about your order...")
                                            .font(.urbanistRegular(16))
                                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                            .padding(12)
                                    }

                                    TextEditor(text: $reviewText)
                                        .font(.urbanistRegular(16))
                                        .foregroundColor(.cakePrimaryText)
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

                            // Submit review button.
                            submitButton

                            if let errorMessage {
                                // Inline validation or upload error.
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

                    if reviewVM.showSuccessMessage {
                        // Success overlay after review submit.
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text("Thank you!")
                                .font(.urbanistSemiBold(18))
                                .foregroundColor(.cakePrimaryText)
                            Text("Your review has been posted")
                                .font(.urbanistRegular(14))
                                .foregroundColor(.cakeGrey)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.cakeSurface.opacity(0.96))
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCamera) {
                // Camera sheet for review photo.
                CameraPickerView(capturedImage: $capturedImage, isPresented: $showCamera)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { item in
                // Add image selected from gallery.
                Task {
                    await appendGalleryImage(item)
                }
            }
            .onChange(of: capturedImage) { image in
                // Add captured camera image.
                appendImage(image)
            }
        }
    }

    // MARK: - Header
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
        .background(Color.cakeSurface)
    }

    // MARK: - Submit Review Process
    private var submitButton: some View {
        Button {
            errorMessage = nil
            reviewVM.submitReview(
                orderID: orderID,
                artisanId: artisanId,
                customerId: customerId,
                bakerName: bakerName,
                rating: rating,
                reviewText: reviewText,
                reviewImagesBase64: reviewImagesBase64,
                onSuccess: { isPresented = false },
                onError: { msg in errorMessage = msg }
            )
        } label: {
            Group {
                if reviewVM.isSubmitting {
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

    // MARK: - Photo Upload Card
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a photo (optional)")
                .font(.urbanistSemiBold(16))
                .foregroundColor(.cakePrimaryText)

            if !selectedImages.isEmpty {
                // Selected review photo preview list.
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
                // Gallery and camera actions.
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
        .background(Color.cakeSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.92, green: 0.90, blue: 0.87), lineWidth: 2)
        )
    }

    private var canSubmit: Bool {
        !reviewVM.isSubmitting && !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Review Image Process
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

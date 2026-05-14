import SwiftUI

// MARK: - CustomerOrder
/// A customer-facing order record combining CakeOrder data with baker profile info.
struct CustomerOrder: Identifiable {
    let id: String
    let cakeName: String
    let status: String
    let statusColor: Color
    let deliveryDate: String
    let currentStep: Int
    let bakerID: String
    let bakerName: String
    let bakerRating: String
    let bakerReviewCount: Int
    let bakerAddress: String
    let bakerCity: String
    let bakerProfileImageBase64: String
    let bakerImageURL: String
    let imageName: String
    let referenceImages: [String]
    let category: String
    let budgetMin: Double
    let budgetMax: Double

    init(id: String, cakeName: String, status: String, statusColor: Color,
         deliveryDate: String, currentStep: Int, bakerID: String = "",
         bakerName: String, bakerRating: String, bakerReviewCount: Int = 0,
         bakerAddress: String, bakerCity: String = "",
         bakerProfileImageBase64: String = "", bakerImageURL: String = "",
         imageName: String = "", referenceImages: [String] = [],
         category: String = "", budgetMin: Double = 0, budgetMax: Double = 0) {
        self.id = id
        self.cakeName = cakeName
        self.status = status
        self.statusColor = statusColor
        self.deliveryDate = deliveryDate
        self.currentStep = currentStep
        self.bakerID = bakerID
        self.bakerName = bakerName
        self.bakerRating = bakerRating
        self.bakerReviewCount = bakerReviewCount
        self.bakerAddress = bakerAddress
        self.bakerCity = bakerCity
        self.bakerProfileImageBase64 = bakerProfileImageBase64
        self.bakerImageURL = bakerImageURL
        self.imageName = imageName
        self.referenceImages = referenceImages
        self.category = category
        self.budgetMin = budgetMin
        self.budgetMax = budgetMax
    }

    init(from order: CakeOrder) {
        self.id = order.id
        self.cakeName = order.cakeName
        self.status = order.statusLabel
        self.statusColor = order.statusColor
        self.deliveryDate = order.formattedDeliveryDate
        self.currentStep = max(1, min(5, order.currentStep))
        self.bakerID = order.artisanId
        self.bakerName = order.artisanName
        self.bakerRating = order.artisanRating
        self.bakerReviewCount = 0
        self.bakerAddress = order.artisanAddress
        self.bakerCity = ""
        self.bakerProfileImageBase64 = ""
        self.bakerImageURL = ""
        self.imageName = ""
        self.referenceImages = order.referenceImages
        self.category = order.category
        self.budgetMin = order.budgetMin
        self.budgetMax = order.budgetMax
    }

    func enriched(with profile: BakerOrderProfile) -> CustomerOrder {
        CustomerOrder(
            id: id, cakeName: cakeName, status: status, statusColor: statusColor,
            deliveryDate: deliveryDate, currentStep: currentStep, bakerID: bakerID,
            bakerName: profile.name.isEmpty ? bakerName : profile.name,
            bakerRating: profile.ratingText.isEmpty ? bakerRating : profile.ratingText,
            bakerReviewCount: profile.reviewCount,
            bakerAddress: profile.address.isEmpty ? bakerAddress : profile.address,
            bakerCity: profile.city,
            bakerProfileImageBase64: profile.profileImageBase64,
            bakerImageURL: profile.imageURL,
            imageName: imageName, referenceImages: referenceImages,
            category: category, budgetMin: budgetMin, budgetMax: budgetMax
        )
    }
}

// MARK: - BakerOrderProfile
/// Enriched baker profile data loaded when displaying a customer's active order.
struct BakerOrderProfile {
    let name: String
    let ratingText: String
    let reviewCount: Int
    let address: String
    let city: String
    let profileImageBase64: String
    let imageURL: String
}

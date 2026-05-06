import XCTest
@testable import CakeLab_IOS

// Tests for the ArtisanProfile model used in CustomerHomeView and ArtisansNearYouView.
final class ArtisanProfileTests: XCTestCase {

    // MARK: - Helpers

    private func makeProfile(
        rating: Double = 4.7,
        reviewCount: Int = 32,
        latitude: Double = 0,
        longitude: Double = 0
    ) -> ArtisanProfile {
        ArtisanProfile(
            id: "artisan-test-001",
            name: "Cake Haven",
            rating: rating,
            reviewCount: reviewCount,
            specialties: ["Wedding Cakes", "Birthday Cakes"],
            city: "Colombo",
            location: "45 Galle Road, Colombo",
            isOnline: true,
            imageURL: nil,
            profileImageBase64: "",
            latitude: latitude,
            longitude: longitude
        )
    }

    // MARK: - ratingText

    func testRatingTextFormatsToOneDecimalPlace() {
        XCTAssertEqual(makeProfile(rating: 4.7).ratingText, "4.7")
    }

    func testRatingTextFormatsWholeNumberWithDecimal() {
        XCTAssertEqual(makeProfile(rating: 5.0).ratingText, "5.0")
    }

    // MARK: - reviewsText

    func testReviewsTextFormatsCountCorrectly() {
        XCTAssertEqual(makeProfile(reviewCount: 32).reviewsText, "(32 reviews)")
    }

    func testReviewsTextForZeroReviews() {
        XCTAssertEqual(makeProfile(reviewCount: 0).reviewsText, "(0 reviews)")
    }

    // MARK: - hasValidCoordinates

    func testHasValidCoordinatesReturnsFalseForBothZero() {
        XCTAssertFalse(makeProfile(latitude: 0, longitude: 0).hasValidCoordinates)
    }

    func testHasValidCoordinatesReturnsTrueWhenLatitudeIsNonZero() {
        XCTAssertTrue(makeProfile(latitude: 6.9271, longitude: 0).hasValidCoordinates)
    }

    func testHasValidCoordinatesReturnsTrueWhenLongitudeIsNonZero() {
        XCTAssertTrue(makeProfile(latitude: 0, longitude: 79.8612).hasValidCoordinates)
    }

    func testHasValidCoordinatesReturnsTrueForValidColomboCoordinates() {
        XCTAssertTrue(makeProfile(latitude: 6.9271, longitude: 79.8612).hasValidCoordinates)
    }

    // MARK: - Identity

    func testProfileIdIsPreserved() {
        XCTAssertEqual(makeProfile().id, "artisan-test-001")
    }
}

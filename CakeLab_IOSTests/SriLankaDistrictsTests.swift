import XCTest
@testable import CakeLab_IOS

final class SriLankaDistrictsTests: XCTestCase {

    func testCanonicalNormalizesDistrictNames() {
        XCTAssertEqual(SriLankaDistricts.canonical(" colombo district "), "Colombo")
        XCTAssertEqual(SriLankaDistricts.canonical("gampaha"), "Gampaha")
    }

    func testDetectFindsDistrictInsideAddressText() {
        let detected = SriLankaDistricts.detect(in: "45 Lake Road, Colombo District")

        XCTAssertEqual(detected, "Colombo")
    }

    func testDisplayLocationAvoidsDuplicatingCity() {
        let location = SriLankaDistricts.displayLocation(
            address: "123 Main Street, Colombo",
            city: "Colombo"
        )

        XCTAssertEqual(location, "123 Main Street, Colombo")
    }

    func testGeocodingQueryAppendsSriLankaWhenMissing() {
        let query = SriLankaDistricts.geocodingQuery(
            address: "123 Main Street",
            city: "Colombo"
        )

        XCTAssertEqual(query, "123 Main Street, Colombo, Sri Lanka")
    }
}

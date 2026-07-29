import XCTest
@testable import MinimalFinance

final class MerchantNormalizerTests: XCTestCase {
    func testStripsTrailingHashNumber() {
        XCTAssertEqual(MerchantNormalizer.normalize("Tim Hortons #4521"), "TIM HORTONS")
    }

    func testStripsKnownSuffix() {
        XCTAssertEqual(MerchantNormalizer.normalize(" spotify_M "), "SPOTIFY")
    }

    func testStripsTrailingDecimalAmount() {
        XCTAssertEqual(MerchantNormalizer.normalize("Netflix.com 8.99"), "NETFLIX.COM")
    }

    func testStripsTrailingInteger() {
        XCTAssertEqual(MerchantNormalizer.normalize("Uber *Trip 12345"), "UBER *TRIP")
    }

    func testCollapsesRepeatedSpaces() {
        XCTAssertEqual(MerchantNormalizer.normalize("Uber   Trip"), "UBER TRIP")
    }

    func testTokensFiltersShortFragments() {
        XCTAssertEqual(MerchantNormalizer.tokens("TIM HORTONS #1"), ["TIM", "HORTONS"])
    }
}

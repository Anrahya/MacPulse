import XCTest
import Foundation

@testable import MacPulse

final class FormatTests: XCTestCase {

    func testPercent() {
        XCTAssertEqual(Format.percent(0.5), "50")
        XCTAssertEqual(Format.percent(0.123, decimals: 1), "12.3")
        XCTAssertEqual(Format.percent(1.0), "100")
        XCTAssertEqual(Format.percent(0), "0")
    }

    func testPercentHandlesNonFinite() {
        XCTAssertEqual(Format.percent(.nan), "—")
        XCTAssertEqual(Format.percent(.infinity), "—")
    }

    func testRateUsesSensibleUnits() {
        // The regression this guards: forcing MB/GB made small rates read "0 MB/s".
        XCTAssertEqual(Format.rate(0), "0 B/s")
        XCTAssertEqual(Format.rate(-5), "0 B/s")
        XCTAssertTrue(Format.rate(4_000).hasSuffix("/s"))
        XCTAssertFalse(Format.rate(4_000).hasPrefix("0 "))
    }

    func testRateNonFinite() {
        XCTAssertEqual(Format.rate(.nan), "0 B/s")
    }

    func testTemperatureConversion() {
        XCTAssertEqual(Format.temperature(0, fahrenheit: false), "0°")
        XCTAssertEqual(Format.temperature(100, fahrenheit: false), "100°")
        // 100 °C == 212 °F
        XCTAssertEqual(Format.temperature(100, fahrenheit: true), "212°")
        // 37 °C == 98.6 °F, rounded to 99°
        XCTAssertEqual(Format.temperature(37, fahrenheit: true), "99°")
    }

    func testMinutes() {
        XCTAssertEqual(Format.minutes(45), "45m")
        XCTAssertEqual(Format.minutes(90), "1h 30m")
        XCTAssertEqual(Format.minutes(60), "1h 0m")
    }

    func testWatts() {
        XCTAssertEqual(Format.watts(12.34), "12.3 W")
        XCTAssertEqual(Format.watts(0), "0.0 W")
    }

    func testBytesFormatting() {
        XCTAssertFalse(Format.bytes(0).isEmpty)
        XCTAssertFalse(Format.bytes(1_073_741_824).isEmpty)
    }
}

final class LoadLevelTests: XCTestCase {

    func testThresholds() {
        XCTAssertEqual(LoadLevel(0.0), .calm)
        XCTAssertEqual(LoadLevel(0.54), .calm)
        XCTAssertEqual(LoadLevel(0.55), .elevated)
        XCTAssertEqual(LoadLevel(0.74), .elevated)
        XCTAssertEqual(LoadLevel(0.75), .high)
        XCTAssertEqual(LoadLevel(0.89), .high)
        XCTAssertEqual(LoadLevel(0.9), .critical)
        XCTAssertEqual(LoadLevel(1.0), .critical)
    }

    func testLabelsAreDistinct() {
        let labels = [LoadLevel.calm, .elevated, .high, .critical].map(\.label)
        XCTAssertEqual(Set(labels).count, labels.count)
    }
}

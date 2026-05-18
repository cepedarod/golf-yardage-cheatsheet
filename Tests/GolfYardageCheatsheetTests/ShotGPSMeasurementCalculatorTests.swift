import XCTest
@testable import GolfYardageCheatsheet

final class ShotGPSMeasurementCalculatorTests: XCTestCase {
    func testMeasurementConvertsCoordinateDistanceToYards() {
        let calculator = ShotGPSMeasurementCalculator()
        let start = ShotLocationAnchor(latitude: 41.0, longitude: -87.0, horizontalAccuracyMeters: 1)
        let end = ShotLocationAnchor(latitude: 41.0, longitude: -86.998913, horizontalAccuracyMeters: 1)

        let measurement = calculator.measurement(from: start, to: end)

        XCTAssertEqual(Double(measurement.measuredDistanceYards), 100, accuracy: 1)
    }

    func testMeasurementUsesTypicalCombinedUncertaintyForConfidence() {
        let calculator = ShotGPSMeasurementCalculator()
        let start = ShotLocationAnchor(latitude: 41.0, longitude: -87.0, horizontalAccuracyMeters: 2)
        let end = ShotLocationAnchor(latitude: 41.0, longitude: -86.999, horizontalAccuracyMeters: 2)

        let measurement = calculator.measurement(from: start, to: end)

        XCTAssertEqual(measurement.estimatedUncertaintyYards, 3.09, accuracy: 0.01)
        XCTAssertEqual(measurement.confidence, .yellow)
    }
}

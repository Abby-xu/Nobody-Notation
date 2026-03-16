import CoreGraphics
import XCTest
@testable import Nobody_Notation

final class ScoreModelsTests: XCTestCase {
    private let tolerance: CGFloat = 0.0001

    func testMakeEvenCreatesExpectedCountsAndSum() {
        var row = ScoreRow()

        row.makeEven(count: 4)

        XCTAssertEqual(row.cells.count, 4)
        XCTAssertEqual(row.fractions.count, 4)
        XCTAssertEqual(row.fractions[0], 0.25, accuracy: tolerance)
        XCTAssertEqual(row.fractions.reduce(0, +), 1.0, accuracy: tolerance)
    }

    func testMakeEvenWithZeroClearsRow() {
        var row = ScoreRow(cells: [.empty], fractions: [1])

        row.makeEven(count: 0)

        XCTAssertTrue(row.cells.isEmpty)
        XCTAssertTrue(row.fractions.isEmpty)
    }

    func testInsertCellAfterSplitsTargetFractionInHalf() {
        var row = ScoreRow(cells: [.empty, .empty], fractions: [0.7, 0.3])

        row.insertCell(after: 0)

        XCTAssertEqual(row.cells.count, 3)
        XCTAssertEqual(row.fractions.count, 3)
        XCTAssertEqual(row.fractions[0], 0.35, accuracy: tolerance)
        XCTAssertEqual(row.fractions[1], 0.35, accuracy: tolerance)
        XCTAssertEqual(row.fractions[2], 0.3, accuracy: tolerance)
        XCTAssertEqual(row.fractions.reduce(0, +), 1.0, accuracy: tolerance)
    }

    func testInsertCellIgnoresInvalidIndex() {
        var row = ScoreRow(cells: [.empty, .empty], fractions: [0.5, 0.5])

        row.insertCell(after: 5)

        XCTAssertEqual(row.cells.count, 2)
        XCTAssertEqual(row.fractions, [0.5, 0.5])
    }

    func testRemoveCellMergeToLeftAddsFractionToLeftNeighbor() {
        var row = ScoreRow(cells: [.empty, .empty, .empty], fractions: [0.2, 0.3, 0.5])

        row.removeCell(at: 1, mergeToLeft: true)

        XCTAssertEqual(row.cells.count, 2)
        XCTAssertEqual(row.fractions.count, 2)
        XCTAssertEqual(row.fractions[0], 0.5, accuracy: tolerance)
        XCTAssertEqual(row.fractions[1], 0.5, accuracy: tolerance)
        XCTAssertEqual(row.fractions.reduce(0, +), 1.0, accuracy: tolerance)
    }

    func testRemoveCellMergeToRightAddsFractionToRightNeighbor() {
        var row = ScoreRow(cells: [.empty, .empty, .empty], fractions: [0.2, 0.3, 0.5])

        row.removeCell(at: 1, mergeToLeft: false)

        XCTAssertEqual(row.cells.count, 2)
        XCTAssertEqual(row.fractions.count, 2)
        XCTAssertEqual(row.fractions[0], 0.2, accuracy: tolerance)
        XCTAssertEqual(row.fractions[1], 0.8, accuracy: tolerance)
        XCTAssertEqual(row.fractions.reduce(0, +), 1.0, accuracy: tolerance)
    }

    func testNormalizeRepairsMismatchedCountsAndMaintainsSum() {
        var row = ScoreRow(cells: [.empty, .empty, .empty], fractions: [1.0])

        row.normalize()

        XCTAssertEqual(row.fractions.count, 3)
        XCTAssertEqual(row.fractions[0], 1.0 / 3.0, accuracy: tolerance)
        XCTAssertEqual(row.fractions.reduce(0, +), 1.0, accuracy: tolerance)
    }

    func testNormalizeEnforcesMinimumPositiveFraction() {
        var row = ScoreRow(cells: [.empty, .empty, .empty], fractions: [0.001, 0.001, 0.998])

        row.normalize()

        XCTAssertEqual(row.fractions.count, 3)
        XCTAssertTrue(row.fractions.allSatisfy { $0 > 0 })
        XCTAssertTrue(row.fractions.allSatisfy { $0 >= ScoreRow.minFraction - tolerance })
        XCTAssertEqual(row.fractions.reduce(0, +), 1.0, accuracy: tolerance)
    }

    func testRemoveCellFromSingleCellRowDoesNothing() {
        var row = ScoreRow(cells: [.empty], fractions: [1.0])

        row.removeCell(at: 0, mergeToLeft: true)

        XCTAssertEqual(row.cells.count, 1)
        XCTAssertEqual(row.fractions.count, 1)
        XCTAssertEqual(row.fractions[0], 1.0, accuracy: tolerance)
    }
}

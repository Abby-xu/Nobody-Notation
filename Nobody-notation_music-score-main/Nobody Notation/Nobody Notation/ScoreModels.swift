import CoreGraphics
import Foundation
import PencilKit

struct ScoreHeader: Codable, Equatable {
    var title: String
    var composer: String
    var key: String
    var tempo: Int

    init(
        title: String = "",
        composer: String = "",
        key: String = "",
        tempo: Int = 0
    ) {
        self.title = title
        self.composer = composer
        self.key = key
        self.tempo = tempo
    }
}

struct ScoreDocument: Codable, Equatable {
    var header: ScoreHeader
    var rows: [ScoreRow]

    init(header: ScoreHeader = ScoreHeader(), rows: [ScoreRow]) {
        self.header = header
        self.rows = rows
    }

    static func defaultTemplate(
        title: String = "",
        composer: String = "",
        key: String = "",
        tempo: Int = 0,
        rowCount: Int = 7,
        columnCount: Int = 6
    ) -> ScoreDocument {
        var rows: [ScoreRow] = []
        rows.reserveCapacity(rowCount)

        for _ in 0..<rowCount {
            var row = ScoreRow()
            row.makeEven(count: columnCount)
            rows.append(row)
        }

        return ScoreDocument(
            header: ScoreHeader(
                title: title,
                composer: composer,
                key: key,
                tempo: tempo
            ),
            rows: rows
        )
    }

    private enum CodingKeys: String, CodingKey {
        case header
        case rows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        header = try container.decodeIfPresent(ScoreHeader.self, forKey: .header) ?? ScoreHeader()
        rows = try container.decode([ScoreRow].self, forKey: .rows)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(header, forKey: .header)
        try container.encode(rows, forKey: .rows)
    }
}

struct ScoreRow: Codable, Equatable {
    static let minFraction: CGFloat = 0.06

    var cells: [ScoreCell]
    var fractions: [CGFloat]

    init(cells: [ScoreCell] = [], fractions: [CGFloat] = []) {
        self.cells = cells
        self.fractions = fractions
        normalize()
    }

    mutating func makeEven(count: Int) {
        guard count > 0 else {
            cells = []
            fractions = []
            return
        }

        cells = Array(repeating: .empty, count: count)
        fractions = Array(repeating: 1.0 / CGFloat(count), count: count)
        normalize()
    }

    mutating func insertCell(after index: Int) {
        guard cells.indices.contains(index), fractions.indices.contains(index) else {
            return
        }

        let original = fractions[index]
        let half = original / 2.0

        cells.insert(.empty, at: index + 1)
        fractions[index] = half
        fractions.insert(half, at: index + 1)
        normalize()
    }

    mutating func removeCell(at index: Int, mergeToLeft: Bool) {
        guard cells.indices.contains(index), fractions.indices.contains(index), cells.count > 1 else {
            return
        }

        let removedFraction = fractions.remove(at: index)
        cells.remove(at: index)

        let mergeIndex: Int
        if mergeToLeft {
            mergeIndex = max(index - 1, 0)
        } else {
            mergeIndex = min(index, fractions.count - 1)
        }

        fractions[mergeIndex] += removedFraction
        normalize()
    }

    mutating func normalize() {
        guard !cells.isEmpty else {
            fractions = []
            return
        }

        if fractions.count != cells.count {
            fractions = Array(repeating: 1.0 / CGFloat(cells.count), count: cells.count)
        }

        let count = cells.count
        let effectiveMin = min(Self.minFraction, 0.99 / CGFloat(count))

        var adjusted = fractions.map { max($0, effectiveMin) }
        let baselineTotal = CGFloat(count) * effectiveMin
        let remaining = max(0, 1.0 - baselineTotal)

        var extras = adjusted.map { max(0, $0 - effectiveMin) }
        let extraSum = extras.reduce(0, +)

        if extraSum > 0 {
            let scale = remaining / extraSum
            extras = extras.map { $0 * scale }
        } else {
            let evenExtra = remaining / CGFloat(count)
            extras = Array(repeating: evenExtra, count: count)
        }

        adjusted = extras.map { $0 + effectiveMin }

        let total = adjusted.reduce(0, +)
        if total > 0 {
            fractions = adjusted.map { $0 / total }
        } else {
            fractions = Array(repeating: 1.0 / CGFloat(count), count: count)
        }
    }
}

struct ScoreCell: Codable, Equatable {
    static let emptyDrawingData = PKDrawing().dataRepresentation()

    var numberChord: String
    var letterChord: String
    var beats: String
    var numberDrawingData: Data
    var letterDrawingData: Data
    var beatsDrawingData: Data

    init(
        numberChord: String = "",
        letterChord: String = "",
        beats: String = "",
        numberDrawingData: Data = ScoreCell.emptyDrawingData,
        letterDrawingData: Data = ScoreCell.emptyDrawingData,
        beatsDrawingData: Data = ScoreCell.emptyDrawingData
    ) {
        self.numberChord = numberChord
        self.letterChord = letterChord
        self.beats = beats
        self.numberDrawingData = numberDrawingData
        self.letterDrawingData = letterDrawingData
        self.beatsDrawingData = beatsDrawingData
    }

    static let empty = ScoreCell()
}

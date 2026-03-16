import CoreGraphics
import SwiftUI

struct ScoreCellLocation: Hashable {
    let row: Int
    let column: Int
}

struct ScoreRowView: View {
    @Binding var row: ScoreRow
    let rowIndex: Int
    let inputMode: ScoreCellInputMode
    @Binding var selectedCell: ScoreCellLocation?

    var body: some View {
        GeometryReader { proxy in
            let rowWidth = max(proxy.size.width, 1)

            ZStack {
                HStack(spacing: 0) {
                    ForEach(row.cells.indices, id: \.self) { index in
                        ScoreCellView(
                            cell: $row.cells[index],
                            inputMode: inputMode,
                            isSelected: selectedCell == ScoreCellLocation(row: rowIndex, column: index),
                            onSelect: {
                                selectedCell = ScoreCellLocation(row: rowIndex, column: index)
                            }
                        )
                        .frame(width: rowWidth * fraction(at: index), height: proxy.size.height)
                    }
                }

                Canvas { context, size in
                    guard row.fractions.count > 1 else { return }

                    let separators = separatorPositions(totalWidth: size.width)
                    for x in separators {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(
                            path,
                            with: .color(.secondary),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 6])
                        )
                    }
                }
                .allowsHitTesting(false)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(uiColor: .separator), lineWidth: 1)
            )
        }
        .frame(height: 138)
    }

    private func fraction(at index: Int) -> CGFloat {
        guard row.fractions.indices.contains(index) else { return 0 }
        return row.fractions[index]
    }

    private func separatorPositions(totalWidth: CGFloat) -> [CGFloat] {
        guard row.fractions.count > 1 else { return [] }

        var positions: [CGFloat] = []
        var cumulative: CGFloat = 0

        for index in 0..<(row.fractions.count - 1) {
            cumulative += row.fractions[index]
            positions.append(totalWidth * cumulative)
        }

        return positions
    }
}

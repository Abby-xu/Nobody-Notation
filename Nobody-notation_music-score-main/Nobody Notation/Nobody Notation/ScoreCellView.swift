import SwiftUI
import PencilKit // MODIFIED: 集成 ScoreIMEKit
import ScoreIMEKit // MODIFIED: 集成 ScoreIMEKit

enum ScoreCellInputMode: String, CaseIterable, Hashable {
    case text
    case handwrite

    var title: String {
        switch self {
        case .text:
            return "Text"
        case .handwrite:
            return "Handwrite"
        }
    }
}

struct ScoreCellView: View {
    @Binding var cell: ScoreCell
    let inputMode: ScoreCellInputMode
    let isSelected: Bool
    let onSelect: () -> Void

    @EnvironmentObject var recognizer: SymbolRecognizer // MODIFIED: 集成 ScoreIMEKit

    @FocusState private var focusedField: Field?

    // MODIFIED: 集成 ScoreIMEKit - 每行独立的画布和输入历史
    @State private var canvasViewNumber = PKCanvasView()
    @State private var canvasViewLetter = PKCanvasView()
    @State private var canvasViewBeats = PKCanvasView()
    @State private var inputHistory: [Field: [String]] = [.number: [], .letter: [], .beats: []]

    private enum Field: Hashable {
        case number
        case letter
        case beats
    }

    private var isHighlighted: Bool {
        focusedField != nil || isSelected
    }

    var body: some View {
        VStack(spacing: 10) {
            switch inputMode {
            case .text:
                textInputs
            case .handwrite:
                handwriteInputs // MODIFIED: 集成 ScoreIMEKit
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHighlighted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHighlighted ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
            if inputMode == .text {
                focusedField = .number
            }
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue != nil {
                onSelect()
            }
        }
    }

    private var textInputs: some View {
        Group {
            TextField("Number", text: $cell.numberChord)
                .focused($focusedField, equals: .number)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
                .contentShape(Rectangle())

            TextField("Letter", text: $cell.letterChord)
                .focused($focusedField, equals: .letter)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
                .contentShape(Rectangle())

            TextField("Beats", text: $cell.beats)
                .focused($focusedField, equals: .beats)
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
        }
    }

    // MODIFIED: 集成 ScoreIMEKit - 全新手写输入视图
    private var handwriteInputs: some View {
        Group {
            handwriteRecognitionLine(
                text: $cell.numberChord,
                canvasView: $canvasViewNumber,
                field: .number,
                placeholder: "Number"
            )
            handwriteRecognitionLine(
                text: $cell.letterChord,
                canvasView: $canvasViewLetter,
                field: .letter,
                placeholder: "Letter"
            )
            handwriteRecognitionLine(
                text: $cell.beats,
                canvasView: $canvasViewBeats,
                field: .beats,
                placeholder: "Beats"
            )
        }
    }

    // MODIFIED: 原地手写 - ZStack 覆盖式布局，画布叠在文字上
    private func handwriteRecognitionLine(
        text: Binding<String>,
        canvasView: Binding<PKCanvasView>,
        field: Field,
        placeholder: String
    ) -> some View {
        ZStack {
            // 底层：已识别文本，每个符号平分格子宽度
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(text.wrappedValue.enumerated()), id: \.offset) { _, char in
                        Text(String(char))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

            if isSelected {
                // 顶层：透明画布覆盖，蓝色笔迹
                HandwritingCanvas(
                    canvasView: canvasView,
                    onStrokeEnd: {
                        performRecognition(canvasView: canvasView.wrappedValue, text: text, field: field)
                    },
                    transparent: true,
                    inkColor: .systemBlue
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // 右上角退格按钮
                if !text.wrappedValue.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                performBackspace(text: text, field: field)
                            } label: {
                                Image(systemName: "delete.left.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Color.secondary.opacity(0.6)))
                            }
                            .buttonStyle(.borderless)
                        }
                        Spacer()
                    }
                    .padding(2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 33)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }

    // MODIFIED: 集成 ScoreIMEKit - 识别逻辑
    private func performRecognition(canvasView: PKCanvasView, text: Binding<String>, field: Field) {
        let image = canvasView.exportAsImage()
        let results = recognizer.recognize(image)

        guard let top = results.first else {
            canvasView.clearCanvas()
            return
        }

        let displayString = SymbolDisplayMap.displayString(for: top.symbol)
        text.wrappedValue += displayString

        // 记录到历史栈用于整符号退格
        inputHistory[field, default: []].append(displayString)

        canvasView.clearCanvas()
    }

    // MODIFIED: 集成 ScoreIMEKit - 整符号退格
    private func performBackspace(text: Binding<String>, field: Field) {
        guard var history = inputHistory[field], !history.isEmpty else {
            // 无历史时逐字符退格
            if !text.wrappedValue.isEmpty {
                text.wrappedValue.removeLast()
            }
            return
        }

        let lastSymbol = history.removeLast()
        inputHistory[field] = history

        if text.wrappedValue.hasSuffix(lastSymbol) {
            text.wrappedValue = String(text.wrappedValue.dropLast(lastSymbol.count))
        } else if !text.wrappedValue.isEmpty {
            text.wrappedValue.removeLast()
        }
    }
}

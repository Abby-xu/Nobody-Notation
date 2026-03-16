import SwiftUI
import PencilKit // MODIFIED: 集成 ScoreIMEKit
import ScoreIMEKit // MODIFIED: 集成 ScoreIMEKit

struct EditorView: View {
    @Binding var document: ScoreDocument
    @EnvironmentObject var recognizer: SymbolRecognizer // MODIFIED: 集成 ScoreIMEKit

    @State private var inputMode: ScoreCellInputMode = .text
    @State private var selectedCell: ScoreCellLocation?
    @State private var exportMessage = ""
    @State private var showExportAlert = false
    @State private var showCalibration = false // MODIFIED: 集成 ScoreIMEKit
    @State private var showTestPanel = false // MODIFIED: 识别测试面板

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScoreHeaderView(header: $document.header)

                ForEach(document.rows.indices, id: \.self) { index in
                    ScoreRowView(
                        row: $document.rows[index],
                        rowIndex: index,
                        inputMode: inputMode,
                        selectedCell: $selectedCell
                    )
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem {
                Picker("Input Mode", selection: $inputMode) {
                    ForEach(ScoreCellInputMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            // MODIFIED: 集成 ScoreIMEKit - 识别测试按钮
            ToolbarItem {
                Button {
                    showTestPanel = true
                } label: {
                    Image(systemName: "hand.draw")
                }
            }

            // MODIFIED: 集成 ScoreIMEKit - 校准按钮
            ToolbarItem {
                Button {
                    showCalibration = true
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(recognizer.isCalibrated ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Calibrate")
                    }
                }
            }

            ToolbarItem {
                Menu("Debug") {
                    Button("Export cell handwriting snapshot") {
                        exportSelectedCellHandwritingSnapshot()
                    }
                }
            }
        }
        // MODIFIED: 集成 ScoreIMEKit - 校准流程 sheet
        .sheet(isPresented: $showCalibration) {
            NavigationStack {
                CalibrationFlow(recognizer: recognizer) {
                    showCalibration = false
                }
                .navigationTitle("Calibration")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showCalibration = false
                        }
                    }
                }
            }
        }
        // MODIFIED: 集成 ScoreIMEKit - 识别测试面板
        .sheet(isPresented: $showTestPanel) {
            NavigationStack {
                RecognitionTestView(recognizer: recognizer)
                    .navigationTitle("Recognition Test")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showTestPanel = false
                            }
                        }
                    }
            }
        }
        .alert("Export", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
    }

    private func exportSelectedCellHandwritingSnapshot() {
        guard let location = selectedCell,
              document.rows.indices.contains(location.row),
              document.rows[location.row].cells.indices.contains(location.column) else {
            exportMessage = "Please select a cell first."
            showExportAlert = true
            return
        }

#if os(iOS) || os(visionOS)
        let cell = document.rows[location.row].cells[location.column]
        let lineTargetSize = CGSize(width: 1400, height: 260)
        let snapshots: [(name: String, drawingData: Data)] = [
            ("number", cell.numberDrawingData),
            ("letter", cell.letterDrawingData),
            ("beats", cell.beatsDrawingData)
        ]

        do {
            let exportDirectory = FilePaths.documentsDirectory.appendingPathComponent("HandwritingExports", isDirectory: true)
            try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            var savedFiles: [String] = []

            for snapshot in snapshots {
                guard let pngData = HandwritingSnapshotExporter.pngData(from: snapshot.drawingData, targetSize: lineTargetSize) else {
                    continue
                }

                let fileName = "r\(location.row + 1)_c\(location.column + 1)_\(snapshot.name)_\(timestamp).png"
                let fileURL = exportDirectory.appendingPathComponent(fileName)
                try pngData.write(to: fileURL, options: .atomic)
                savedFiles.append(fileName)
            }

            if savedFiles.isEmpty {
                exportMessage = "No handwriting snapshot was produced."
            } else {
                exportMessage = "Saved \(savedFiles.count) image(s) to Documents/HandwritingExports."
            }
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
#else
        exportMessage = "Snapshot export is currently supported on iOS/visionOS."
#endif
        showExportAlert = true
    }
}

private struct ScoreHeaderView: View {
    @Binding var header: ScoreHeader

    var body: some View {
        VStack(spacing: 8) {
            TextField("Title", text: $header.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Key:")
                            .font(.headline)
                        KeyText(key: header.key)
                    }

                    HStack(spacing: 4) {
                        Text("Tempo:")
                            .font(.headline)
                        TextField("0", value: $header.tempo, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 88)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    TextField("Composer", text: $header.composer)
                        .font(.headline)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 220)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct KeyText: View {
    let key: String

    var body: some View {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let characters = Array(trimmedKey)

        Group {
            if let primary = characters.first {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(String(primary))
                        .font(.title3.weight(.semibold))

                    if characters.count > 1 {
                        Text(String(characters[1]))
                            .font(.caption.weight(.semibold))
                            .baselineOffset(8)
                    }
                }
            } else {
                Text("--")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    EditorView(document: .constant(ScoreDocument(rows: [])))
}

//
//  ContentView.swift
//  Nobody Notation
//
//  Created by Abby Xu on 2/28/26.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @StateObject private var documentStore = DocumentStore()
    @State private var path: [URL] = []
    @State private var renamingItem: ScoreFileItem?
    @State private var renameInput = ""
    @State private var newDocumentForm = NewDocumentForm()
    @State private var isShowingNewDocumentSheet = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(documentStore.items) { item in
                    NavigationLink(value: item.url) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .font(.headline)

                            Text(item.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            delete(item)
                        }

                        Button("Rename") {
                            renamingItem = item
                            renameInput = item.displayName
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Files")
            .navigationDestination(for: URL.self) { url in
                EditorHostView(url: url)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Document") {
                        newDocumentForm = NewDocumentForm()
                        isShowingNewDocumentSheet = true
                    }
                }
            }
        }
        .task {
            documentStore.refresh()
        }
        .onAppear {
            documentStore.refresh()
        }
        .alert("Rename", isPresented: isRenameAlertPresented) {
            TextField("File name", text: $renameInput)
            Button("Cancel", role: .cancel) {
                renamingItem = nil
            }
            Button("Save") {
                commitRename()
            }
        } message: {
            Text("Enter a new name (without extension).")
        }
        .sheet(isPresented: $isShowingNewDocumentSheet) {
            NavigationStack {
                Form {
                    Section("Score Info") {
                        TextField("Title", text: $newDocumentForm.title)
                        TextField("Composer", text: $newDocumentForm.composer)
                        TextField("Key", text: $newDocumentForm.key)
                        TextField("Tempo", text: $newDocumentForm.tempoText)
                            .keyboardType(.numberPad)
                    }

                    Section("Layout") {
                        TextField("Columns Per Row", text: $newDocumentForm.columnCountText)
                            .keyboardType(.numberPad)
                        TextField("Row Count", text: $newDocumentForm.rowCountText)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("New Document")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingNewDocumentSheet = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            createNewDocument()
                        }
                        .disabled(!newDocumentForm.isValid)
                    }
                }
            }
        }
    }

    private var isRenameAlertPresented: Binding<Bool> {
        Binding(
            get: { renamingItem != nil },
            set: { isPresented in
                if !isPresented {
                    renamingItem = nil
                }
            }
        )
    }

    private func createNewDocument() {
        guard let config = newDocumentForm.makeConfiguration() else {
            return
        }

        let url = FilePaths.makeNewFileURL(suggestedBaseName: config.title)
        let document = ScoreDocument.defaultTemplate(
            title: config.title,
            composer: config.composer,
            key: config.key,
            tempo: config.tempo,
            rowCount: config.rowCount,
            columnCount: config.columnCount
        )

        do {
            let data = try JSONEncoder().encode(document)
            try data.write(to: url, options: .atomic)
            documentStore.refresh()
            isShowingNewDocumentSheet = false
            path.append(url)
        } catch {
            print("Failed to create document: \(error)")
        }
    }

    private func delete(_ item: ScoreFileItem) {
        do {
            try FileManager.default.removeItem(at: item.url)
            documentStore.refresh()
        } catch {
            print("Failed to delete document: \(error)")
        }
    }

    private func commitRename() {
        guard let item = renamingItem else { return }

        let trimmedName = renameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            renamingItem = nil
            return
        }

        let destinationURL = item.url
            .deletingLastPathComponent()
            .appendingPathComponent(trimmedName)
            .appendingPathExtension(FilePaths.scoreFileExtension)

        do {
            if destinationURL != item.url {
                try FileManager.default.moveItem(at: item.url, to: destinationURL)
            }
            documentStore.refresh()
        } catch {
            print("Failed to rename document: \(error)")
        }

        renamingItem = nil
    }
}

private struct NewDocumentForm {
    var title = ""
    var composer = ""
    var key = ""
    var tempoText = ""
    var columnCountText = "6"
    var rowCountText = "7"

    var isValid: Bool {
        makeConfiguration() != nil
    }

    func makeConfiguration() -> NewDocumentConfiguration? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComposer = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty,
              let tempo = Int(tempoText),
              let columnCount = Int(columnCountText),
              let rowCount = Int(rowCountText),
              tempo >= 0,
              columnCount > 0,
              rowCount > 0 else {
            return nil
        }

        return NewDocumentConfiguration(
            title: trimmedTitle,
            composer: trimmedComposer,
            key: trimmedKey,
            tempo: tempo,
            columnCount: columnCount,
            rowCount: rowCount
        )
    }
}

private struct NewDocumentConfiguration {
    let title: String
    let composer: String
    let key: String
    let tempo: Int
    let columnCount: Int
    let rowCount: Int
}

#Preview {
    ContentView()
}

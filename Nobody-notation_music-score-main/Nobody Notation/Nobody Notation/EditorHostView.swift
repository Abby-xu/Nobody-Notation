import SwiftUI
import ScoreIMEKit // MODIFIED: 集成 ScoreIMEKit

struct EditorHostView: View {
    let url: URL

    @StateObject private var session: DocumentSession
    @StateObject private var recognizer = SymbolRecognizer() // MODIFIED: 集成 ScoreIMEKit

    init(url: URL) {
        self.url = url
        _session = StateObject(wrappedValue: DocumentSession(url: url))
    }

    var body: some View {
        Group {
            if session.isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EditorView(document: $session.document)
                    .environmentObject(recognizer) // MODIFIED: 集成 ScoreIMEKit
            }
        }
        .navigationTitle(url.deletingPathExtension().lastPathComponent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    session.save()
                }
                .disabled(session.isLoading)
            }
        }
        .task {
            session.load()
        }
    }
}

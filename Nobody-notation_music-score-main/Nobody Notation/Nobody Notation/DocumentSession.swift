import Combine
import Foundation

@MainActor
final class DocumentSession: ObservableObject {
    let url: URL

    @Published var document: ScoreDocument
    @Published var isLoading = false
    @Published var lastError: String?

    init(url: URL, document: ScoreDocument? = nil) {
        self.url = url
        self.document = document ?? .defaultTemplate()
    }

    func load() {
        isLoading = true
        lastError = nil

        let targetURL = url

        Task.detached(priority: .userInitiated) {
            do {
                let data = try Data(contentsOf: targetURL)
                await MainActor.run {
                    do {
                        let decodedDocument = try JSONDecoder().decode(ScoreDocument.self, from: data)
                        self.document = decodedDocument.rows.isEmpty ? .defaultTemplate() : decodedDocument
                        self.isLoading = false
                    } catch {
                        self.lastError = "Load failed: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastError = "Load failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func save() {
        lastError = nil

        let targetURL = url

        do {
            let data = try JSONEncoder().encode(document)

            Task.detached(priority: .utility) {
                do {
                    try data.write(to: targetURL, options: .atomic)
                } catch {
                    await MainActor.run {
                        self.lastError = "Save failed: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
        }
    }
}

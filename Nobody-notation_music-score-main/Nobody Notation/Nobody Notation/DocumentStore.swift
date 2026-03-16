import Combine
import Foundation
import SwiftUI

struct ScoreFileItem: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let displayName: String
    let modifiedAt: Date
    let fileSize: Int64?
}

@MainActor
final class DocumentStore: ObservableObject {
    @Published var items: [ScoreFileItem] = []

    func refresh() {
        let documentsDirectory = FilePaths.documentsDirectory
        let targetExtension = FilePaths.scoreFileExtension.lowercased()

        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let resourceKeys: Set<URLResourceKey> = [
                .isRegularFileKey,
                .contentModificationDateKey,
                .fileSizeKey
            ]

            let fileURLs = (try? fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )) ?? []

            var loadedItems: [ScoreFileItem] = []
            loadedItems.reserveCapacity(fileURLs.count)

            for url in fileURLs {
                guard url.pathExtension.lowercased() == targetExtension else {
                    continue
                }

                let values = try? url.resourceValues(forKeys: resourceKeys)
                guard values?.isRegularFile != false else {
                    continue
                }

                let modifiedAt = values?.contentModificationDate ?? .distantPast
                let fileSize = values?.fileSize.map(Int64.init)
                let displayName = url.deletingPathExtension().lastPathComponent

                loadedItems.append(
                    ScoreFileItem(
                        url: url,
                        displayName: displayName,
                        modifiedAt: modifiedAt,
                        fileSize: fileSize
                    )
                )
            }

            loadedItems.sort { $0.modifiedAt > $1.modifiedAt }

            await MainActor.run {
                self.items = loadedItems
            }
        }
    }
}

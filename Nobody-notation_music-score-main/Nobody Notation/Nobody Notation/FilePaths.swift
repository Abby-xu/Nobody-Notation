import Foundation

enum FilePaths {
    static let documentsDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    static let scoreFileExtension = "scorejson"

    static func makeNewFileURL(
        suggestedBaseName: String,
        fileManager: FileManager = .default
    ) -> URL {
        let sanitizedBaseName = sanitizedFileName(from: suggestedBaseName)
        let preferredBaseName = sanitizedBaseName.isEmpty ? "Untitled" : sanitizedBaseName

        var index = 1
        while true {
            let baseName = index == 1 ? preferredBaseName : "\(preferredBaseName) \(index)"
            let fileName = "\(baseName).\(scoreFileExtension)"
            let candidateURL = documentsDirectory.appendingPathComponent(fileName)

            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            index += 1
        }
    }

    static func makeNewUntitledFileURL(fileManager: FileManager = .default) -> URL {
        makeNewFileURL(suggestedBaseName: "Untitled", fileManager: fileManager)
    }

    private static func sanitizedFileName(from value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleanedScalars = value.unicodeScalars.map { scalar in
            invalidCharacters.contains(scalar) ? " " : Character(scalar)
        }

        return String(cleanedScalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

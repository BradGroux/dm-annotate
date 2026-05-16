import Foundation

public enum ScreenshotNamer {
    public static func fileName(date: Date = Date(), nameComponent: String? = nil, suffix: Int? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let componentText = nameComponent.map { "-\($0)" } ?? ""
        let suffixText = suffix.map { "-\($0)" } ?? ""
        return "dm-annotate-\(formatter.string(from: date))\(componentText)\(suffixText).png"
    }

    public static func uniqueFileURL(
        in folder: URL,
        date: Date = Date(),
        nameComponent: String? = nil,
        fileExists: (URL) -> Bool
    ) -> URL {
        let baseURL = folder.appendingPathComponent(fileName(date: date, nameComponent: nameComponent))
        guard fileExists(baseURL) else { return baseURL }

        var suffix = 2
        while true {
            let candidate = folder.appendingPathComponent(fileName(date: date, nameComponent: nameComponent, suffix: suffix))
            if !fileExists(candidate) {
                return candidate
            }
            suffix += 1
        }
    }
}

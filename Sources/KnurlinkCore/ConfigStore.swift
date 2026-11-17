import Foundation

public struct ConfigStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static var standard: ConfigStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ConfigStore(fileURL: support.appendingPathComponent("Knurlink/config.json"))
    }

    public func load() throws -> Config {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return Config() }
        return try JSONDecoder().decode(Config.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ config: Config) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: fileURL, options: .atomic)
    }

    public func quarantineInvalidFile() throws -> URL {
        let destination = fileURL.deletingLastPathComponent().appendingPathComponent("config.invalid.json")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: fileURL, to: destination)
        return destination
    }
}

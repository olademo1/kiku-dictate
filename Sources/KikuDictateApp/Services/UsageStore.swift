import Foundation

final class UsageStore {
    let location: URL

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent(AppConstants.appSupportFolder, isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        location = folder.appendingPathComponent("usage.json")

        let legacyLocation = appSupport
            .appendingPathComponent(AppConstants.legacyAppSupportFolder, isDirectory: true)
            .appendingPathComponent("usage.json")
        if !fileManager.fileExists(atPath: location.path),
           fileManager.fileExists(atPath: legacyLocation.path) {
            try? fileManager.copyItem(at: legacyLocation, to: location)
        }

        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [UsageRecord] {
        guard let data = try? Data(contentsOf: location),
              let records = try? decoder.decode([UsageRecord].self, from: data)
        else {
            return []
        }

        return records.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ record: UsageRecord) -> [UsageRecord] {
        var records = load()
        records.insert(record, at: 0)
        save(records)
        return records
    }

    private func save(_ records: [UsageRecord]) {
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: location, options: [.atomic])
    }
}

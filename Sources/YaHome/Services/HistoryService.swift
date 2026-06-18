import Foundation

final class HistoryService {
    static let shared = HistoryService()
    private let maxEntries = 2016 // 7 days at 5-min intervals
    private let maxAge: TimeInterval = 7 * 24 * 3600

    private var history: [String: [SensorHistoryEntry]] = [:]
    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("YaHome", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("sensor_history.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: [SensorHistoryEntry]].self, from: data)
        else { return }
        history = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: fileURL)
    }

    func record(deviceId: String, temperature: Double?, humidity: Double?) {
        let now = Date().timeIntervalSince1970 * 1000
        var entry = SensorHistoryEntry(ts: now)
        entry.temperature = temperature
        entry.humidity = humidity

        var entries = history[deviceId] ?? []
        entries.append(entry)

        let cutoff = now - maxAge * 1000
        entries = entries.filter { $0.ts > cutoff }
        if entries.count > maxEntries { entries = Array(entries.suffix(maxEntries)) }

        history[deviceId] = entries
        save()
    }

    func entries(for deviceId: String) -> [SensorHistoryEntry] {
        (history[deviceId] ?? []).sorted { $0.ts < $1.ts }
    }
}

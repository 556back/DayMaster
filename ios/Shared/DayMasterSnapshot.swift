import Foundation

struct DayMasterEvent: Decodable, Identifiable {
    let id: String
    let title: String
    let date: String
    let category: String
    let emoji: String
    let colorHex: String
    let note: String
    let photoBase64: String?
    let repeatYearly: Bool
    let inclusive: Bool
    let pinned: Bool
    let reminderDays: Int?
    let createdAt: String
}

struct DayMasterWidgetConfiguration: Decodable, Identifiable {
    let id: String
    let style: String
    let eventIds: [String]
    let theme: String
    let backgroundOpacity: Double
    let textTone: String
    let photoScale: Double
    let photoX: Double
    let photoY: Double
    let photoDim: Double

    private enum CodingKeys: String, CodingKey {
        case id, style, eventIds, theme, backgroundOpacity, textTone, photoScale, photoX, photoY, photoDim
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        style = try values.decode(String.self, forKey: .style)
        eventIds = try values.decode([String].self, forKey: .eventIds)
        theme = try values.decode(String.self, forKey: .theme)
        func number(_ key: CodingKeys, fallback: Double, range: ClosedRange<Double>) -> Double {
            guard let value = try? values.decode(Double.self, forKey: key), value.isFinite else { return fallback }
            return min(range.upperBound, max(range.lowerBound, value))
        }
        backgroundOpacity = number(.backgroundOpacity, fallback: 1, range: 0...1)
        let tone = (try? values.decode(String.self, forKey: .textTone)) ?? "auto"
        textTone = ["auto", "light", "dark"].contains(tone) ? tone : "auto"
        photoScale = number(.photoScale, fallback: 1, range: 1...3)
        photoX = number(.photoX, fallback: 0, range: -1...1)
        photoY = number(.photoY, fallback: 0, range: -1...1)
        photoDim = number(.photoDim, fallback: 0.6, range: 0...0.85)
    }
}

struct DayMasterSnapshot: Decodable {
    let version: Int
    let events: [DayMasterEvent]
    let widgets: [DayMasterWidgetConfiguration]

    func validate() throws {
        guard version == 1,
              Set(events.map(\.id)).count == events.count,
              Set(widgets.map(\.id)).count == widgets.count else {
            throw DayMasterStoreError.invalidSnapshot
        }
        for event in events {
            guard !event.id.isEmpty, !event.title.isEmpty,
                  DayMasterDate.date(from: event.date) != nil,
                  event.reminderDays == nil || [0, 1, 3, 7].contains(event.reminderDays!) else {
                throw DayMasterStoreError.invalidSnapshot
            }
            if let base64 = event.photoBase64 {
                guard base64.utf8.count <= 1_398_104,
                      let data = Data(base64Encoded: base64), data.count <= 1_048_576 else {
                    throw DayMasterStoreError.invalidSnapshot
                }
            }
        }
        for widget in widgets {
            guard !widget.id.isEmpty,
                  Set(widget.eventIds).count == widget.eventIds.count,
                  ["number", "photo", "dual", "list", "ring", "calendar", "ticket", "bloom"].contains(widget.style),
                  ["blue", "rose", "green", "ink"].contains(widget.theme) else {
                throw DayMasterStoreError.invalidSnapshot
            }
        }
    }

    func events(for configuration: DayMasterWidgetConfiguration) -> [DayMasterEvent] {
        configuration.eventIds.compactMap { id in events.first { $0.id == id } }
    }
}

enum DayMasterStoreError: LocalizedError {
    case appGroupUnavailable, snapshotTooLarge, invalidSnapshot

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable: return "无法访问共享容器，请检查 App Group 签名配置。"
        case .snapshotTooLarge: return "组件数据超过 20 MiB。"
        case .invalidSnapshot: return "日期或组件数据格式不正确。"
        }
    }
}

enum DayMasterStore {
    static let appGroup = "group.com.daymaster.daymaster"
    static let maximumBytes = 20 * 1_048_576

    static func fileURL() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        ) else { throw DayMasterStoreError.appGroupUnavailable }
        return container.appendingPathComponent("snapshot.json")
    }

    static func decode(_ data: Data) throws -> DayMasterSnapshot {
        guard data.count <= maximumBytes else { throw DayMasterStoreError.snapshotTooLarge }
        let snapshot = try JSONDecoder().decode(DayMasterSnapshot.self, from: data)
        try snapshot.validate()
        return snapshot
    }

    static func read() -> DayMasterSnapshot? {
        guard let url = try? fileURL(),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maximumBytes,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(data)
    }

    @discardableResult static func save(json: String) throws -> DayMasterSnapshot {
        let data = Data(json.utf8)
        let snapshot = try decode(data)
        try data.write(to: fileURL(), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return snapshot
    }
}

// Civil arithmetic uses UTC midnight; today comes from the device's local calendar.
enum DayMasterDate {
    static var civilCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func date(from value: String) -> Date? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard value.count == 10, parts.count == 3,
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = civilCalendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let actual = civilCalendar.dateComponents([.year, .month, .day], from: date)
        return actual.year == year && actual.month == month && actual.day == day ? date : nil
    }

    static func today(at now: Date = Date()) -> Date {
        let local = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: now)
        return civilCalendar.date(from: local)!
    }

    static func difference(from start: Date, to end: Date) -> Int {
        civilCalendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func anniversary(of original: Date, in year: Int) -> Date {
        let components = civilCalendar.dateComponents([.month, .day], from: original)
        let month = components.month!
        var day = components.day!
        if month == 2 && day == 29 && !(year.isMultiple(of: 400) || (year.isMultiple(of: 4) && !year.isMultiple(of: 100))) {
            day = 28
        }
        return civilCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func nextAnniversary(of original: Date, from today: Date) -> Date {
        if original > today { return original }
        let year = civilCalendar.component(.year, from: today)
        let candidate = anniversary(of: original, in: year)
        return candidate >= today ? candidate : anniversary(of: original, in: year + 1)
    }

    static func target(for event: DayMasterEvent, at now: Date) -> Date? {
        guard let original = date(from: event.date) else { return nil }
        return event.repeatYearly ? nextAnniversary(of: original, from: today(at: now)) : original
    }

    static func yearProgress(at now: Date) -> (year: Int, day: Int, totalDays: Int, fraction: Double) {
        let today = today(at: now)
        let year = civilCalendar.component(.year, from: today)
        let start = civilCalendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end = civilCalendar.date(byAdding: .year, value: 1, to: start)!
        let day = difference(from: start, to: today) + 1
        let totalDays = difference(from: start, to: end)
        return (year, day, totalDays, Double(day) / Double(totalDays))
    }

    static func metric(for event: DayMasterEvent, at now: Date) -> (days: Int, label: String) {
        guard let target = target(for: event, at: now) else { return (0, "打开 App 设置") }
        let today = today(at: now)
        let delta = difference(from: today, to: target)
        if delta == 0 { return (0, "就是今天") }
        return delta > 0 ? (delta, "还有") : (-delta + (event.inclusive ? 1 : 0), event.inclusive ? "第" : "已经")
    }

    static func elapsed(for event: DayMasterEvent, at now: Date) -> Int {
        guard let original = date(from: event.date) else { return 0 }
        return max(0, difference(from: original, to: today(at: now)) + (event.inclusive ? 1 : 0))
    }

    static func eventURL(_ id: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "daymaster"
        components.host = id == nil ? "widgets" : "event"
        if let id { components.queryItems = [URLQueryItem(name: "id", value: id)] }
        return components.url
    }
}

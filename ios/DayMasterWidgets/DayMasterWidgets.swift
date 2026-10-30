import AppIntents
import ImageIO
import SwiftUI
import UIKit
import WidgetKit

struct SavedWidgetEntity: AppEntity {
    let id: String
    let title: String
    let subtitle: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "日子组件"
    static var defaultQuery = SavedWidgetQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }

    static func all() -> [SavedWidgetEntity] {
        guard let snapshot = DayMasterStore.read() else { return [] }
        return snapshot.widgets.map { configuration in
            let events = snapshot.events(for: configuration)
            let styleNames = ["number": "大数字", "photo": "照片纪念卡", "dual": "双日期", "list": "日子列表",
                              "ring": "年轮", "calendar": "月历", "ticket": "日子车票", "bloom": "花开日子"]
            return SavedWidgetEntity(
                id: configuration.id,
                title: events.isEmpty ? "尚未选择日子" : events.prefix(2).map(\.title).joined(separator: " · "),
                subtitle: "\(styleNames[configuration.style] ?? "日子") · \(configuration.id.suffix(4))"
            )
        }
    }
}

struct SavedWidgetQuery: EntityQuery {
    func entities(for identifiers: [SavedWidgetEntity.ID]) async throws -> [SavedWidgetEntity] {
        let all = SavedWidgetEntity.all()
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    func suggestedEntities() async throws -> [SavedWidgetEntity] { SavedWidgetEntity.all() }
    func defaultResult() async -> SavedWidgetEntity? { SavedWidgetEntity.all().first }
}

struct DayMasterConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择日子组件"
    static var description = IntentDescription("选择在日子 App 中保存的组件。每份系统组件可以独立选择。")

    @Parameter(title: "已保存的组件")
    var savedConfiguration: SavedWidgetEntity?
}

struct DayMasterEntry: TimelineEntry {
    let date: Date
    let configuration: DayMasterWidgetConfiguration?
    let events: [DayMasterEvent]
}

struct DayMasterProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayMasterEntry {
        DayMasterEntry(date: Date(), configuration: nil, events: [])
    }

    func snapshot(for configuration: DayMasterConfigurationIntent, in context: Context) async -> DayMasterEntry {
        entry(for: configuration, at: Date())
    }

    func timeline(for configuration: DayMasterConfigurationIntent, in context: Context) async -> Timeline<DayMasterEntry> {
        let now = Date()
        let first = entry(for: configuration, at: now)
        var entries = [first]
        let calendar = Calendar(identifier: .gregorian)
        let midnight = calendar.startOfDay(for: now)
        for day in 1...30 {
            guard let date = calendar.date(byAdding: .day, value: day, to: midnight) else { continue }
            entries.append(DayMasterEntry(date: date, configuration: first.configuration, events: first.events))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(for intent: DayMasterConfigurationIntent, at date: Date) -> DayMasterEntry {
        guard let snapshot = DayMasterStore.read() else {
            return DayMasterEntry(date: date, configuration: nil, events: [])
        }
        let configuration: DayMasterWidgetConfiguration?
        if let id = intent.savedConfiguration?.id {
            configuration = snapshot.widgets.first { $0.id == id }
        } else { configuration = snapshot.widgets.first }
        return DayMasterEntry(date: date, configuration: configuration, events: configuration.map { snapshot.events(for: $0) } ?? [])
    }
}

struct WidgetPalette {
    let accent: Color
    let background: Color
    let photoBackground: Color
    let foreground: Color
    let secondary: Color

    init(theme: String, dark: Bool, textTone: String, onPhoto: Bool, systemForeground: Bool) {
        let rgb: (Double, Double, Double)
        switch theme {
        case "rose": rgb = (188, 72, 111) // #BC486F
        case "green": rgb = (23, 123, 102) // #177B66
        case "ink": rgb = (37, 52, 73) // #253449
        default: rgb = (40, 100, 220) // #2864DC
        }
        let red = rgb.0 / 255
        let green = rgb.1 / 255
        let blue = rgb.2 / 255
        let base = Color(red: red, green: green, blue: blue)
        let darkBackground = textTone == "light" || (textTone != "dark" && dark)
        let forcedText: Color? = textTone == "light" ? .white
            : (textTone == "dark" ? Color(red: 24 / 255, green: 36 / 255, blue: 58 / 255) : nil)
        let themeAccent = dark ? Color(red: 0.5 + red * 0.5, green: 0.5 + green * 0.5, blue: 0.5 + blue * 0.5) : base
        accent = systemForeground ? .primary : (forcedText ?? themeAccent)
        // Six percent color on white retains >=4.5:1 for every selected theme's small text.
        background = darkBackground ? Color(red: (16 / 255) * 0.8 + red * 0.2, green: (24 / 255) * 0.8 + green * 0.2, blue: (39 / 255) * 0.8 + blue * 0.2)
            : Color(red: 0.94 + red * 0.06, green: 0.94 + green * 0.06, blue: 0.94 + blue * 0.06)
        photoBackground = textTone == "auto" ? base : background
        foreground = systemForeground ? .primary : (forcedText ?? (onPhoto ? .white : (dark ? themeAccent : base)))
        let themeSecondary = dark ? Color(red: 188 / 255, green: 202 / 255, blue: 219 / 255)
            : Color(red: 83 / 255, green: 101 / 255, blue: 124 / 255)
        secondary = systemForeground ? .primary : (forcedText ?? (onPhoto ? .white : themeSecondary))
    }
}
struct DayMasterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    let entry: DayMasterEntry

    private var palette: WidgetPalette {
        WidgetPalette(
            theme: entry.configuration?.theme ?? "blue", dark: colorScheme == .dark,
            textTone: entry.configuration?.textTone ?? "auto", onPhoto: onPhotoBackground,
            systemForeground: isAccessory || !showsBackground
        )
    }
    private var isAccessory: Bool {
        [.accessoryCircular, .accessoryRectangular, .accessoryInline].contains(family)
    }
    private var onPhotoBackground: Bool {
        entry.configuration?.style == "photo" && !isAccessory && showsBackground
    }
    private var backgroundOpacity: Double { entry.configuration?.backgroundOpacity ?? 1 }
    // WidgetKit owns wallpaper/material treatment and may remove the container in StandBy.
    private var artworkOpacity: Double { showsBackground && !isAccessory ? backgroundOpacity : 0 }
    private var photo: UIImage? {
        guard entry.configuration?.style == "photo", !isAccessory, showsBackground,
              let base64 = entry.events.first?.photoBase64,
              let data = Data(base64Encoded: base64),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 1200
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    var body: some View {
        let backgroundPhoto = photo
        return content
            .foregroundStyle(palette.foreground)
            .containerBackground(for: .widget) {
                Group {
                    if let backgroundPhoto {
                        ZStack {
                            palette.photoBackground
                            GeometryReader { geometry in
                                let size = geometry.size
                                let scale = max(size.width / backgroundPhoto.size.width, size.height / backgroundPhoto.size.height)
                                    * CGFloat(entry.configuration?.photoScale ?? 1)
                                let width = backgroundPhoto.size.width * scale
                                let height = backgroundPhoto.size.height * scale
                                let x = (size.width - width) * CGFloat((entry.configuration?.photoX ?? 0) + 1) / 2
                                let y = (size.height - height) * CGFloat((entry.configuration?.photoY ?? 0) + 1) / 2
                                Image(uiImage: backgroundPhoto)
                                    .resizable()
                                    .frame(width: width, height: height)
                                    .position(x: x + width / 2, y: y + height / 2)
                            }.clipped()
                            let dim = entry.configuration?.photoDim ?? 0.6
                            let shade = entry.configuration?.textTone == "dark" ? Color.white : Color.black
                            LinearGradient(colors: [shade.opacity(dim), shade.opacity(min(0.9, dim + 0.15))], startPoint: .top, endPoint: .bottom)
                        }
                    } else { onPhotoBackground ? palette.photoBackground : palette.background }
                }
                .opacity(backgroundOpacity)
            }
            .widgetURL(DayMasterDate.eventURL(entry.events.first?.id))
    }

    @ViewBuilder private var content: some View {
        if let event = entry.events.first {
            switch family {
            case .accessoryInline: inline(event)
            case .accessoryCircular: circular(event)
            case .accessoryRectangular: rectangular(event)
            default:
                switch entry.configuration?.style {
                case "list" where family != .systemSmall: list
                case "dual": dual(event)
                case "ring": ring(event)
                case "calendar": monthCalendar(event)
                case "ticket": ticket(event)
                case "bloom": bloom(event)
                default: number(event)
                }
            }
        } else { empty }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            if family != .accessoryInline { Image(systemName: "calendar.badge.plus").font(.title2) }
            Text("打开日子").font(.headline)
            if !isAccessory { Text("在 App 中保存组件，再长按此处选择。").font(.caption).foregroundStyle(palette.secondary) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityLabel("打开日子 App，保存并选择组件")
    }

    private func heading(_ event: DayMasterEvent) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text(event.emoji).accessibilityHidden(true)
            Text(event.title).font(.system(size: family == .systemLarge ? 19 : 15, weight: .semibold)).lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private func number(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        return VStack(alignment: .leading, spacing: 6) {
            heading(event)
            Spacer(minLength: 4)
            Text(metric.label).font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(metric.days)")
                    .font(.system(size: family == .systemLarge ? 92 : 64, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.35).lineLimit(1).monospacedDigit()
                Text("天").font(.system(size: 15, weight: .medium))
            }
            Spacer(minLength: 3)
            Text(event.date.replacingOccurrences(of: "-", with: "."))
                .font(.system(size: 12, weight: .medium)).monospacedDigit()
                .foregroundStyle(palette.secondary)
            if family == .systemLarge {
                Text(event.note.isEmpty ? event.category : event.note)
                    .font(.system(size: 14)).lineLimit(3).padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title)，\(metric.label)，\(metric.days)天，\(event.date)")
    }

    private func dual(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        let elapsed = DayMasterDate.elapsed(for: event, at: entry.date)
        return VStack(alignment: .leading, spacing: 9) {
            heading(event)
            Spacer(minLength: 1)
            if family == .systemSmall {
                compactCount(title: "累计", days: elapsed)
                Divider().opacity(artworkOpacity)
                compactCount(title: event.repeatYearly ? "距下次纪念日" : metric.label, days: metric.days)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    countBlock(title: "累计", days: elapsed)
                    Divider().opacity(artworkOpacity)
                    countBlock(title: event.repeatYearly ? "距下次纪念日" : metric.label, days: metric.days)
                }
            }
            Spacer(minLength: 1)
            Text(event.date.replacingOccurrences(of: "-", with: "."))
                .font(.caption2).foregroundStyle(palette.secondary)
            if family == .systemLarge && !event.note.isEmpty {
                Text(event.note).font(.subheadline).lineLimit(3).padding(.top, 10)
            }
        }
    }

    private func countBlock(title: String, days: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(palette.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(days)").font(.system(size: family == .systemLarge ? 54 : 42, weight: .semibold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.35).monospacedDigit()
                Text("天").font(.caption2)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactCount(title: String, days: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 10)).foregroundStyle(palette.secondary)
            Spacer(minLength: 2)
            Text("\(days)").font(.system(size: 24, weight: .medium, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
            Text("天").font(.system(size: 10))
        }
    }

    private func targetDate(_ event: DayMasterEvent) -> String {
        guard let date = DayMasterDate.target(for: event, at: entry.date) else { return event.date }
        let parts = DayMasterDate.civilCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d.%02d.%02d", parts.year!, parts.month!, parts.day!)
    }

    private func targetFooter(_ event: DayMasterEvent) -> some View {
        Text("\(event.repeatYearly ? "下一次" : "日期") · \(targetDate(event))")
            .font(.system(size: family == .systemLarge ? 13 : 10, weight: .medium))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            .foregroundStyle(palette.secondary)
    }

    private func creativeCount(_ event: DayMasterEvent, size: CGFloat) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        return VStack(spacing: 2) {
            Text(metric.label).font(.system(size: max(10, size * 0.22), weight: .medium))
                .foregroundStyle(palette.secondary)
            Text("\(metric.days)").font(.system(size: size, weight: .semibold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.3).monospacedDigit()
            Text("天").font(.system(size: max(10, size * 0.22), weight: .medium))
        }
    }

    private func ringDial(_ event: DayMasterEvent) -> some View {
        let progress = DayMasterDate.yearProgress(at: entry.date)
        return GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().stroke(palette.accent.opacity(0.14 * artworkOpacity), lineWidth: max(5, size * 0.045))
                Circle().trim(from: 0, to: CGFloat(progress.fraction))
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: max(5, size * 0.045), lineCap: .round))
                    .rotationEffect(.degrees(-90)).opacity(artworkOpacity)
                creativeCount(event, size: size * 0.32).frame(width: size * 0.7)
            }
            .padding(max(3, size * 0.025))
            .frame(width: size, height: size)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var yearProgressLabel: some View {
        let progress = DayMasterDate.yearProgress(at: entry.date)
        return HStack(spacing: 4) {
            Text("\(String(progress.year)) 年进度")
            Spacer(minLength: 0)
            Text("\(Int(progress.fraction * 100))%")
                .fontWeight(.semibold).foregroundStyle(palette.accent)
        }
        .font(.system(size: family == .systemLarge ? 13 : 10, weight: .medium))
        .monospacedDigit().foregroundStyle(palette.secondary)
    }

    private func ring(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        let progress = DayMasterDate.yearProgress(at: entry.date)
        return Group {
            if family == .systemMedium {
                HStack(spacing: 18) {
                    ringDial(event).aspectRatio(1, contentMode: .fit)
                    VStack(alignment: .leading, spacing: 10) {
                        heading(event)
                        Spacer(minLength: 0)
                        yearProgressLabel
                        Text("第 \(progress.day) 天 / \(progress.totalDays) 天")
                            .font(.system(size: 11)).foregroundStyle(palette.secondary)
                        targetFooter(event)
                    }.frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 5) {
                    heading(event)
                    ringDial(event)
                    yearProgressLabel
                    if family == .systemLarge { targetFooter(event) }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title)，\(metric.label)\(metric.days)天，\(targetDate(event))，\(String(progress.year))年进度\(Int(progress.fraction * 100))%")
    }

    private var monthTitle: some View {
        let parts = DayMasterDate.civilCalendar.dateComponents([.year, .month], from: DayMasterDate.today(at: entry.date))
        return HStack {
            Text("\(parts.month!) 月").font(.system(size: family == .systemLarge ? 24 : 15, weight: .semibold))
            Spacer(minLength: 0)
            Text(String(parts.year!)).font(.system(size: family == .systemLarge ? 14 : 11, weight: .medium))
                .foregroundStyle(palette.secondary)
        }.monospacedDigit()
    }

    private func monthGrid(_ event: DayMasterEvent) -> some View {
        let calendar = DayMasterDate.civilCalendar
        let today = DayMasterDate.today(at: entry.date)
        let parts = calendar.dateComponents([.year, .month, .day], from: today)
        let first = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1))!
        let dayCount = calendar.range(of: .day, in: .month, for: first)!.count
        let offset = (calendar.component(.weekday, from: first) + 5) % 7
        let rowCount = (offset + dayCount + 6) / 7
        let target = DayMasterDate.target(for: event, at: entry.date)
        let targetParts = target.map { calendar.dateComponents([.year, .month, .day], from: $0) }
        let targetDay = targetParts?.year == parts.year && targetParts?.month == parts.month ? targetParts?.day : nil
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return GeometryReader { geometry in
            let weekdayHeight: CGFloat = family == .systemLarge ? 16 : 11
            let cellHeight = max(0, (geometry.size.height - weekdayHeight - 3) / CGFloat(rowCount))
            let markerSize = max(0, min(geometry.size.width / 7, cellHeight) - 1)
            VStack(spacing: 3) {
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day).frame(maxWidth: .infinity)
                    }
                }
                .font(.system(size: family == .systemLarge ? 12 : 9, weight: .medium))
                .foregroundStyle(palette.secondary).frame(height: weekdayHeight)
                VStack(spacing: 0) {
                    ForEach(0..<rowCount, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { column in
                                let day = row * 7 + column - offset + 1
                                let valid = (1...dayCount).contains(day)
                                let isToday = valid && day == parts.day
                                let isTarget = valid && day == targetDay
                                Text(valid ? String(day) : "")
                                    .font(.system(size: family == .systemLarge ? 16 : (family == .systemSmall ? 10 : 12), weight: isToday || isTarget ? .semibold : .regular))
                                    .foregroundStyle(isToday && artworkOpacity >= 0.5 ? palette.background : palette.foreground)
                                    .lineLimit(1).minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity).frame(height: cellHeight)
                                    .background {
                                        if isToday {
                                            Circle().fill(palette.accent).frame(width: markerSize, height: markerSize)
                                                .opacity(artworkOpacity)
                                        }
                                    }
                                    .overlay {
                                        if isTarget {
                                            Circle().stroke(palette.accent, lineWidth: 1.5)
                                                .frame(width: isToday ? markerSize + 2 : markerSize, height: isToday ? markerSize + 2 : markerSize)
                                                .opacity(artworkOpacity)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }.accessibilityHidden(true)
    }

    private func monthCalendar(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        let today = DayMasterDate.civilCalendar.dateComponents([.year, .month, .day], from: DayMasterDate.today(at: entry.date))
        return Group {
            if family == .systemMedium {
                HStack(spacing: 18) {
                    VStack(spacing: 7) { monthTitle; monthGrid(event) }.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        heading(event)
                        Spacer(minLength: 0)
                        countBlock(title: metric.label, days: metric.days)
                        targetFooter(event)
                    }.frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 4) {
                    monthTitle
                    monthGrid(event)
                    if family == .systemLarge {
                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) { heading(event); targetFooter(event) }
                            countBlock(title: metric.label, days: metric.days)
                        }
                    } else {
                        Text(event.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                        Text("\(metric.label)\(metric.days)天 · \(targetDate(event))")
                            .font(.system(size: 10, weight: .medium)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(today.year!))年\(today.month!)月月历，今天\(today.day!)日。\(event.title)，\(metric.label)\(metric.days)天，\(targetDate(event))")
    }

    private func perforation(vertical: Bool = false) -> some View {
        let notchOffset: CGFloat = (family == .systemSmall ? 8 : 14) + 6
        return Perforation(vertical: vertical)
            .stroke(palette.accent.opacity(0.4 * artworkOpacity), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
            .overlay(alignment: vertical ? .top : .leading) {
                Circle().fill(palette.background).frame(width: 12, height: 12).opacity(artworkOpacity)
                    .offset(x: vertical ? 0 : -notchOffset, y: vertical ? -notchOffset : 0)
            }
            .overlay(alignment: vertical ? .bottom : .trailing) {
                Circle().fill(palette.background).frame(width: 12, height: 12).opacity(artworkOpacity)
                    .offset(x: vertical ? 0 : notchOffset, y: vertical ? notchOffset : 0)
            }
            .accessibilityHidden(true)
    }

    private func ticket(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        return Group {
            if family == .systemMedium {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("日子车票").font(.system(size: 10, weight: .semibold)).tracking(2)
                        heading(event)
                        Spacer(minLength: 0)
                        countBlock(title: metric.label, days: metric.days)
                    }.frame(maxWidth: .infinity)
                    perforation(vertical: true)
                    VStack(spacing: 8) {
                        Text(event.emoji).font(.system(size: 24)).accessibilityHidden(true)
                        Text(event.repeatYearly ? "下一次" : "日期").font(.system(size: 10, weight: .medium))
                        Text(targetDate(event)).font(.system(size: 12, weight: .semibold))
                            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    }.frame(width: 88)
                }
            } else {
                VStack(alignment: .leading, spacing: family == .systemLarge ? 14 : 5) {
                    Text("日子车票").font(.system(size: 10, weight: .semibold)).tracking(2)
                    Text(event.title).font(.system(size: family == .systemLarge ? 22 : 14, weight: .semibold))
                        .lineLimit(family == .systemLarge ? 2 : 1)
                    Spacer(minLength: 0)
                    if family == .systemSmall {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(metric.label).font(.system(size: 10)).foregroundStyle(palette.secondary)
                            Text("\(metric.days)").font(.system(size: 38, weight: .semibold, design: .rounded))
                                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.3)
                            Text("天").font(.system(size: 10))
                        }
                    } else { countBlock(title: metric.label, days: metric.days) }
                    Spacer(minLength: 0)
                    perforation()
                    targetFooter(event)
                    if family == .systemLarge && !event.note.isEmpty {
                        Text(event.note).font(.system(size: 13)).lineLimit(2).foregroundStyle(palette.secondary)
                    }
                }
            }
        }
        .padding(family == .systemSmall ? 8 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16).fill(palette.accent.opacity(0.07))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(palette.accent.opacity(0.17), lineWidth: 1) }
                .opacity(artworkOpacity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("日子车票，\(event.title)，\(metric.label)\(metric.days)天，\(targetDate(event))")
    }

    private func flower(_ event: DayMasterEvent) -> some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                ForEach(0..<8, id: \.self) { petal in
                    Ellipse().fill(palette.accent.opacity(0.12 * artworkOpacity))
                        .frame(width: size * 0.3, height: size * 0.52)
                        .offset(y: -size * 0.22)
                        .rotationEffect(.degrees(Double(petal) * 45))
                        .accessibilityHidden(true)
                }
                Circle().fill(palette.background).frame(width: size * 0.58).opacity(artworkOpacity)
                    .accessibilityHidden(true)
                creativeCount(event, size: size * 0.27).frame(width: size * 0.53)
            }
            .frame(width: size, height: size)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func bloom(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        return Group {
            if family == .systemMedium {
                HStack(spacing: 18) {
                    flower(event).aspectRatio(1, contentMode: .fit)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("花开日子").font(.system(size: 11, weight: .medium)).foregroundStyle(palette.secondary)
                        heading(event)
                        Spacer(minLength: 0)
                        targetFooter(event)
                    }.frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 5) {
                    heading(event)
                    flower(event)
                    targetFooter(event)
                    if family == .systemLarge && !event.note.isEmpty {
                        Text(event.note).font(.system(size: 13)).lineLimit(2).foregroundStyle(palette.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("花开日子，\(event.title)，\(metric.label)\(metric.days)天，\(targetDate(event))")
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 16 : 9) {
            HStack {
                Text("重要的日子").font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "calendar").foregroundStyle(palette.accent).accessibilityHidden(true)
            }
            ForEach(Array(entry.events.prefix(family == .systemLarge ? 5 : 3))) { event in
                if let url = DayMasterDate.eventURL(event.id) {
                    Link(destination: url) { row(event) }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        return HStack(spacing: 8) {
            Text(event.emoji).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                if family == .systemLarge { Text(event.date).font(.caption2).foregroundStyle(palette.secondary) }
            }
            Spacer(minLength: 6)
            Text(metric.label).font(.system(size: 10)).foregroundStyle(palette.secondary)
            Text("\(metric.days)").font(.system(size: 23, weight: .medium, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5).foregroundStyle(palette.accent)
            Text("天").font(.system(size: 10))
        }.accessibilityElement(children: .combine)
    }

    private func inline(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        return Text("\(event.emoji) \(event.title) · \(metric.label)\(metric.days)天")
    }

    private func circular(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        return VStack(spacing: 1) {
            Text(metric.label).font(.system(size: 9))
            Text("\(metric.days)").font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
            Text("天").font(.system(size: 9))
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("\(event.title)，\(metric.label)\(metric.days)天")
    }

    private func rectangular(_ event: DayMasterEvent) -> some View {
        let metric = DayMasterDate.metric(for: event, at: entry.date)
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(event.emoji) \(event.title)").font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Text("\(metric.label) \(metric.days) 天").font(.system(size: 17, weight: .medium, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
        }
    }
}

private struct Perforation: Shape {
    var vertical = false

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: vertical ? CGPoint(x: 0, y: rect.height) : CGPoint(x: rect.width, y: 0))
        }
    }
}

@main
struct DayMasterWidgets: Widget {
    let kind = "DayMasterWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DayMasterConfigurationIntent.self, provider: DayMasterProvider()) { entry in
            DayMasterWidgetView(entry: entry)
        }
        .configurationDisplayName("日子 · 倒数与纪念")
        .description("先在 App 中挑选并保存喜欢的组件样式，再选择它。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}


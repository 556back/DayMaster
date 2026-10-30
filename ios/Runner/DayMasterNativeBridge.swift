import Flutter
import Foundation
import UserNotifications
import WidgetKit

final class DayMasterNativeBridge {
    static var shared: DayMasterNativeBridge?
    private static var pendingEventID: String?
    private let channel: FlutterMethodChannel
    private var launchWasRead = false
    private let worker = DispatchQueue(label: "com.daymaster.snapshot")
    private let reminders = DayMasterReminders()

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "daymaster/native", binaryMessenger: messenger)
        Self.shared = self
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    @discardableResult static func receive(url: URL) -> Bool {
        guard url.scheme == "daymaster" else { return false }
        guard url.host == "event",
              let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value,
              !id.isEmpty else { return url.host == "widgets" }
        receive(eventID: id)
        return true
    }

    static func receive(eventID: String) {
        pendingEventID = eventID
        guard let bridge = shared, bridge.launchWasRead else { return }
        bridge.channel.invokeMethod("openEvent", arguments: ["id": eventID]) { response in
            // A hot restart may temporarily remove Dart's handler; keep that link for getLaunchEventId.
            if let response = response as? NSObject, response.isEqual(FlutterMethodNotImplemented) {
                Self.pendingEventID = eventID
            }
        }
        pendingEventID = nil
    }

    func refreshForLocalTime() {
        WidgetCenter.shared.reloadAllTimelines()
        worker.async {
            guard let snapshot = DayMasterStore.read() else { return }
            self.reminders.reschedule(snapshot: snapshot) { _ in }
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getLaunchEventId":
            launchWasRead = true
            let id = Self.pendingEventID
            Self.pendingEventID = nil
            result(id)
        case "requestPinWidget":
            // iOS users add an independently configured widget through the system gallery.
            result(false)
        case "saveSnapshot":
            guard let arguments = call.arguments as? [String: Any], let json = arguments["json"] as? String else {
                result(FlutterError(code: "invalid_arguments", message: "缺少组件数据。", details: nil))
                return
            }
            worker.async {
                do {
                    let snapshot = try DayMasterStore.save(json: json)
                    DispatchQueue.main.async { WidgetCenter.shared.reloadAllTimelines() }
                    self.reminders.reschedule(snapshot: snapshot) { error in
                        DispatchQueue.main.async {
                            if let error {
                                result(FlutterError(code: "reminder_schedule_failed", message: error.localizedDescription, details: nil))
                            } else { result(true) }
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "snapshot_save_failed", message: error.localizedDescription, details: nil))
                    }
                }
            }
        case "requestNotifications":
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { authorized, error in
                if let error {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "notification_permission_failed", message: error.localizedDescription, details: nil))
                    }
                    return
                }
                guard authorized, let snapshot = DayMasterStore.read() else {
                    DispatchQueue.main.async { result(authorized) }
                    return
                }
                self.reminders.reschedule(snapshot: snapshot) { scheduleError in
                    DispatchQueue.main.async {
                        if let scheduleError {
                            result(FlutterError(code: "reminder_schedule_failed", message: scheduleError.localizedDescription, details: nil))
                        } else { result(true) }
                    }
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

final class DayMasterReminders {
    private let center = UNUserNotificationCenter.current()
    private let scheduling = DispatchQueue(label: "com.daymaster.reminders")
    private var schedulingInProgress = false
    private var waiting: [(DayMasterSnapshot, (Error?) -> Void)] = []

    func reschedule(snapshot: DayMasterSnapshot, completion: @escaping (Error?) -> Void) {
        scheduling.async {
            self.waiting.append((snapshot, completion))
            self.scheduleNext()
        }
    }

    private func scheduleNext() {
        guard !schedulingInProgress, !waiting.isEmpty else { return }
        schedulingInProgress = true
        let (snapshot, completion) = waiting.removeFirst()
        let finish: (Error?) -> Void = { error in
            completion(error)
            self.scheduling.async {
                self.schedulingInProgress = false
                self.scheduleNext()
            }
        }
        center.getNotificationSettings { settings in
            guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
                finish(nil)
                return
            }
            self.center.getPendingNotificationRequests { existing in
                let ownIDs = existing.filter { $0.identifier.hasPrefix("daymaster.event.") }.map(\.identifier)
                self.center.removePendingNotificationRequests(withIdentifiers: ownIDs)
                let requests = Self.requests(for: snapshot, at: Date())
                let group = DispatchGroup()
                let lock = NSLock()
                var firstError: Error?
                for request in requests {
                    group.enter()
                    self.center.add(request) { error in
                        if let error {
                            lock.lock()
                            if firstError == nil { firstError = error }
                            lock.unlock()
                        }
                        group.leave()
                    }
                }
                group.notify(queue: self.scheduling) { finish(firstError) }
            }
        }
    }

    static func requests(for snapshot: DayMasterSnapshot, at now: Date) -> [UNNotificationRequest] {
        let calendar = Calendar(identifier: .gregorian)
        let currentYear = calendar.component(.year, from: now)
        var datedRequests: [(Date, UNNotificationRequest)] = []
        for event in snapshot.events {
            guard let lead = event.reminderDays, let original = DayMasterDate.date(from: event.date) else { continue }
            let originalYear = DayMasterDate.civilCalendar.component(.year, from: original)
            let startYear = max(currentYear, originalYear)
            let dates: [Date]
            if event.repeatYearly {
                // Explicit civil occurrences preserve February 29 fallback and reminder offsets in leap years.
                dates = (startYear..<min(startYear + 64, 10_000)).map {
                    DayMasterDate.anniversary(of: original, in: $0)
                }
            } else { dates = [original] }
            for occurrence in dates {
                let civil = DayMasterDate.civilCalendar.dateComponents([.year, .month, .day], from: occurrence)
                guard let localOccurrence = calendar.date(from: civil),
                      let remindDay = calendar.date(byAdding: .day, value: -lead, to: localOccurrence),
                      let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: remindDay),
                      fireDate > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body = lead == 0 ? "「\(event.title)」就是今天" : "距离「\(event.title)」还有 \(lead) 天"
                content.sound = .default
                content.userInfo = ["eventId": event.id]
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let identifier = "daymaster.event.\(event.id).\(civil.year!)"
                datedRequests.append((fireDate, UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)))
            }
        }
        return datedRequests.sorted { $0.0 < $1.0 }.prefix(64).map { $0.1 }
    }
}
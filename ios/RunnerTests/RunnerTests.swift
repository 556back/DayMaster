import XCTest
import UserNotifications
@testable import Runner

final class RunnerTests: XCTestCase {
    func testWidgetAppearanceDefaultsAndBounds() throws {
        let legacy = #"{"version":1,"events":[],"widgets":[{"id":"legacy","style":"photo","eventIds":[],"theme":"blue"}]}"#
        let defaults = try XCTUnwrap(DayMasterStore.decode(Data(legacy.utf8)).widgets.first)
        XCTAssertEqual(defaults.backgroundOpacity, 1)
        XCTAssertEqual(defaults.textTone, "auto")
        XCTAssertEqual(defaults.photoScale, 1)
        XCTAssertEqual(defaults.photoX, 0)
        XCTAssertEqual(defaults.photoY, 0)
        XCTAssertEqual(defaults.photoDim, 0.6)

        let adjusted = #"{"version":1,"events":[],"widgets":[{"id":"adjusted","style":"photo","eventIds":[],"theme":"rose","backgroundOpacity":0.35,"textTone":"dark","photoScale":2.5,"photoX":-0.8,"photoY":0.6,"photoDim":0.2}]}"#
        let saved = try XCTUnwrap(DayMasterStore.decode(Data(adjusted.utf8)).widgets.first)
        XCTAssertEqual(saved.backgroundOpacity, 0.35)
        XCTAssertEqual(saved.textTone, "dark")
        XCTAssertEqual(saved.photoScale, 2.5)
        XCTAssertEqual(saved.photoX, -0.8)
        XCTAssertEqual(saved.photoY, 0.6)
        XCTAssertEqual(saved.photoDim, 0.2)

        let invalidOptional = #"{"version":1,"events":[],"widgets":[{"id":"bounds","style":"photo","eventIds":[],"theme":"green","backgroundOpacity":-1,"textTone":"unknown","photoScale":8,"photoX":-4,"photoY":3,"photoDim":null}]}"#
        let bounded = try XCTUnwrap(DayMasterStore.decode(Data(invalidOptional.utf8)).widgets.first)
        XCTAssertEqual(bounded.backgroundOpacity, 0)
        XCTAssertEqual(bounded.textTone, "auto")
        XCTAssertEqual(bounded.photoScale, 3)
        XCTAssertEqual(bounded.photoX, -1)
        XCTAssertEqual(bounded.photoY, 1)
        XCTAssertEqual(bounded.photoDim, 0.6)
    }

    func testWidgetYearProgressAndRecurringTarget() throws {
        let calendar = Calendar(identifier: .gregorian)
        let cases = [
            (2026, 1, 1, 1, 365, 0),
            (2026, 12, 31, 365, 365, 100),
            (2024, 1, 1, 1, 366, 0),
            (2024, 3, 1, 61, 366, 16),
            (2024, 12, 31, 366, 366, 100)
        ]
        for (year, month, day, ordinal, total, percentage) in cases {
            let now = try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
            let progress = DayMasterDate.yearProgress(at: now)
            XCTAssertEqual(progress.year, year)
            XCTAssertEqual(progress.day, ordinal)
            XCTAssertEqual(progress.totalDays, total)
            XCTAssertEqual(Int(progress.fraction * 100), percentage)
        }

        let leapEvent = DayMasterEvent(
            id: "leap", title: "闰日", date: "2024-02-29", category: "生日", emoji: "🎂",
            colorHex: "#2864DC", note: "", photoBase64: nil, repeatYearly: true,
            inclusive: false, pinned: false, reminderDays: nil, createdAt: "2024-02-29T00:00:00Z"
        )
        let beforeAnniversary = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 2, day: 27, hour: 12)))
        let afterAnniversary = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 3, day: 1, hour: 12)))
        XCTAssertEqual(DayMasterDate.target(for: leapEvent, at: beforeAnniversary), DayMasterDate.date(from: "2025-02-28"))
        XCTAssertEqual(DayMasterDate.target(for: leapEvent, at: afterAnniversary), DayMasterDate.date(from: "2026-02-28"))
    }

    func testCivilDaysAndLeapAnniversary() throws {
        let leap = try XCTUnwrap(DayMasterDate.date(from: "2024-02-29"))
        let fallback = try XCTUnwrap(DayMasterDate.date(from: "2025-02-28"))
        XCTAssertEqual(DayMasterDate.anniversary(of: leap, in: 2025), fallback)
        XCTAssertEqual(DayMasterDate.nextAnniversary(of: leap, from: fallback), fallback)
        XCTAssertEqual(DayMasterDate.nextAnniversary(of: leap, from: try XCTUnwrap(DayMasterDate.date(from: "2025-03-01"))), DayMasterDate.date(from: "2026-02-28"))
        XCTAssertEqual(DayMasterDate.difference(from: leap, to: fallback), 365)
        XCTAssertNil(DayMasterDate.date(from: "2025-02-29"))
        XCTAssertNil(DayMasterDate.date(from: "2026-13-01"))
        XCTAssertNil(DayMasterDate.date(from: "2026-2-01"))
    }

    func testInclusivePastLabelMatchesApp() throws {
        let json = ##"{"version":1,"events":[{"id":"start","title":"开始","date":"2026-10-01","category":"生活","emoji":"🌿","colorHex":"#2864DC","note":"","photoBase64":null,"repeatYearly":false,"inclusive":true,"pinned":false,"reminderDays":null,"createdAt":"2026-10-01T00:00:00Z"}],"widgets":[]}"##
        let snapshot = try DayMasterStore.decode(Data(json.utf8))
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12)))
        let event = try XCTUnwrap(snapshot.events.first)
        let metric = DayMasterDate.metric(for: event, at: now)
        XCTAssertEqual(metric.days, 3)
        XCTAssertEqual(metric.label, "第")
    }
    func testInclusiveAndReminderBoundaries() throws {
        let json = ##"{"version":1,"events":[{"id":"leap","title":"生日","date":"2024-02-29","category":"生日","emoji":"🎂","colorHex":"#2864DC","note":"","photoBase64":null,"repeatYearly":true,"inclusive":true,"pinned":false,"reminderDays":1,"createdAt":"2026-01-01T00:00:00Z"}],"widgets":[]}"##
        let snapshot = try DayMasterStore.decode(Data(json.utf8))
        let event = try XCTUnwrap(snapshot.events.first)
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 2, day: 27, hour: 8)))
        XCTAssertEqual(DayMasterDate.metric(for: event, at: now).days, 1)
        XCTAssertEqual(DayMasterDate.metric(for: event, at: now).label, "还有")
        let requests = DayMasterReminders.requests(for: snapshot, at: now)
        XCTAssertEqual(requests.count, 64)
        let first = try XCTUnwrap(requests.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(first.dateComponents.year, 2025)
        XCTAssertEqual(first.dateComponents.month, 2)
        XCTAssertEqual(first.dateComponents.day, 27)
        XCTAssertEqual(first.dateComponents.hour, 9)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 2, day: 28, hour: 12)))
        XCTAssertEqual(DayMasterDate.metric(for: event, at: today).days, 0)
        XCTAssertEqual(DayMasterDate.elapsed(for: event, at: today), 366)
        XCTAssertEqual(DayMasterReminders.requests(for: snapshot, at: today).count, 63)
    }
}

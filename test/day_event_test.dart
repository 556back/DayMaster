import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:daymaster/models/day_event.dart';

void main() {
  test('civil days, leap year and cross year', () {
    expect(dayDifference(DateTime(2024, 2, 28), DateTime(2024, 3, 1)), 2);
    expect(dayDifference(DateTime(2023, 2, 28), DateTime(2023, 3, 1)), 1);
    expect(dayDifference(DateTime(2026, 12, 31), DateTime(2027, 1, 1)), 1);
  });
  test('today, future, past and inclusive', () {
    final e = DayEvent(id: 'one', title: '日子', date: DateTime(2026, 10, 3));
    expect(e.status(DateTime(2026, 10, 3, 23)).days, 0);
    expect(e.status(DateTime(2026, 10, 3)).label, '就是今天');
    expect(e.status(DateTime(2026, 10, 2)).days, 1);
    expect(e.status(DateTime(2026, 10, 4)).days, 1);
    expect(e.status(DateTime(2026, 10, 4)).isPast, true);
    expect(e.copyWith(inclusive: true).elapsedDays(DateTime(2026, 10, 3)), 1);
    expect(e.copyWith(inclusive: true).status(DateTime(2026, 10, 4)).days, 2);
  });
  test('annual repeat preserves original and handles February29', () {
    final e = DayEvent(
      id: 'leap',
      title: '生日',
      date: DateTime(2024, 2, 29),
      repeatYearly: true,
    );
    expect(e.nextOccurrence(DateTime(2025, 2, 1)), DateTime(2025, 2, 28));
    expect(e.nextOccurrence(DateTime(2025, 2, 28)), DateTime(2025, 2, 28));
    expect(e.nextOccurrence(DateTime(2025, 3, 1)), DateTime(2026, 2, 28));
    expect(e.nextOccurrence(DateTime(2028, 2, 1)), DateTime(2028, 2, 29));
    expect(e.date, DateTime(2024, 2, 29));
  });
  test('backup photos use standard Base64 on all platforms', () {
    final json = DayEvent(
      id: 'photo',
      title: '照片',
      date: DateTime(2026, 10, 3),
    ).toJson();
    final bytes = [251, 255, 254];
    final restored = DayEvent.fromJson({
      ...json,
      'photoBase64': base64UrlEncode(bytes),
    });
    expect(restored.photoBase64, base64Encode(bytes));
    expect(base64Decode(restored.photoBase64!), bytes);
  });
  test('reject invalid dates and untrusted records', () {
    expect(() => parseCivilDate('2025-02-29'), throwsFormatException);
    expect(() => parseCivilDate('2024-13-01'), throwsFormatException);
    final json = DayEvent(
      id: 'one',
      title: '日子',
      date: DateTime(2026, 10, 3),
    ).toJson();
    expect(DayEvent.fromJson(json).date, DateTime(2026, 10, 3));
    expect(
      () => DayEvent.fromJson({...json, 'pinned': 'true'}),
      throwsFormatException,
    );
    expect(
      () => DayEvent.fromJson({...json, 'photoBase64': 'invalid'}),
      throwsFormatException,
    );
  });
}

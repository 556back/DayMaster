import 'dart:convert';
import 'dart:math';

DateTime civilDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int dayDifference(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime parseCivilDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) throw const FormatException('日期格式应为 YYYY-MM-DD');
  final y = int.parse(match[1]!);
  final m = int.parse(match[2]!);
  final d = int.parse(match[3]!);
  final date = DateTime(y, m, d);
  if (y < 1900 ||
      y > 2200 ||
      date.year != y ||
      date.month != m ||
      date.day != d) {
    throw const FormatException('日期不存在或超出支持范围（1900–2200）');
  }
  return date;
}

String newId() {
  final random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${List.generate(12, (_) => random.nextInt(16).toRadixString(16)).join()}';
}

class DayStatus {
  const DayStatus({
    required this.days,
    required this.label,
    required this.isPast,
    required this.nextDate,
  });
  final int days;
  final String label;
  final bool isPast;
  final DateTime nextDate;
}

class DayEvent {
  DayEvent({
    required this.id,
    required this.title,
    required DateTime date,
    this.category = '生活',
    this.emoji = '🌿',
    this.colorHex = '#2864DC',
    this.note = '',
    this.photoBase64,
    this.repeatYearly = false,
    this.inclusive = false,
    this.pinned = false,
    this.reminderDays,
    DateTime? createdAt,
  }) : date = civilDate(date),
       createdAt = createdAt ?? DateTime.now();

  final String id, title, category, emoji, colorHex, note;
  final DateTime date, createdAt;
  final String? photoBase64;
  final bool repeatYearly, inclusive, pinned;
  final int? reminderDays;

  DateTime nextOccurrence(DateTime today) {
    today = civilDate(today);
    if (!repeatYearly || today.isBefore(date)) return date;
    DateTime occurrence(int year) {
      final lastDay = DateTime(year, date.month + 1, 0).day;
      return DateTime(year, date.month, min(date.day, lastDay));
    }

    final candidate = occurrence(today.year);
    return candidate.isBefore(today) ? occurrence(today.year + 1) : candidate;
  }

  int elapsedDays(DateTime today) =>
      max(0, dayDifference(date, today) + (inclusive ? 1 : 0));

  DayStatus status(DateTime today) {
    final target = nextOccurrence(today);
    final difference = dayDifference(today, target);
    final past = difference < 0;
    return DayStatus(
      days: past ? -difference + (inclusive ? 1 : 0) : difference,
      label: difference == 0
          ? '就是今天'
          : (past ? (inclusive ? '第' : '已经') : '还有'),
      isPast: past,
      nextDate: target,
    );
  }

  DayEvent copyWith({
    String? title,
    DateTime? date,
    String? category,
    String? emoji,
    String? colorHex,
    String? note,
    String? photoBase64,
    bool clearPhoto = false,
    bool? repeatYearly,
    bool? inclusive,
    bool? pinned,
    int? reminderDays,
    bool clearReminder = false,
  }) => DayEvent(
    id: id,
    title: title ?? this.title,
    date: date ?? this.date,
    category: category ?? this.category,
    emoji: emoji ?? this.emoji,
    colorHex: colorHex ?? this.colorHex,
    note: note ?? this.note,
    photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
    repeatYearly: repeatYearly ?? this.repeatYearly,
    inclusive: inclusive ?? this.inclusive,
    pinned: pinned ?? this.pinned,
    reminderDays: clearReminder ? null : (reminderDays ?? this.reminderDays),
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': dateString(date),
    'category': category,
    'emoji': emoji,
    'colorHex': colorHex,
    'note': note,
    'photoBase64': photoBase64,
    'repeatYearly': repeatYearly,
    'inclusive': inclusive,
    'pinned': pinned,
    'reminderDays': reminderDays,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DayEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final photo = json['photoBase64'];
    if (id is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id) ||
        title is! String ||
        title.trim().isEmpty ||
        title.length > 100) {
      throw const FormatException('记录的名称或 ID 无效');
    }
    for (final key in [
      'category',
      'emoji',
      'colorHex',
      'note',
      'date',
      'createdAt',
    ]) {
      if (json[key] is! String) throw FormatException('记录缺少有效字段：$key');
    }
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(json['colorHex'] as String) ||
        (json['category'] as String).length > 30 ||
        (json['emoji'] as String).length > 20 ||
        (json['note'] as String).length > 5000) {
      throw const FormatException('记录内容格式无效');
    }
    for (final key in ['repeatYearly', 'inclusive', 'pinned']) {
      if (json[key] is! bool) throw FormatException('记录的 $key 选项无效');
    }
    final reminder = json['reminderDays'];
    if (reminder != null &&
        (reminder is! int || ![0, 1, 3, 7].contains(reminder))) {
      throw const FormatException('提醒设置无效');
    }
    String? normalizedPhoto;
    if (photo != null) {
      if (photo is! String || photo.length > 1400000) {
        throw const FormatException('照片超过 1MB 或格式无效');
      }
      final bytes = base64Decode(photo);
      if (bytes.length > 1024 * 1024) {
        throw const FormatException('照片超过 1MB 或格式无效');
      }
      normalizedPhoto = base64Encode(bytes);
    }
    final created = DateTime.tryParse(json['createdAt'] as String);
    if (created == null) throw const FormatException('创建时间无效');
    return DayEvent(
      id: id,
      title: title.trim(),
      date: parseCivilDate(json['date'] as String),
      category: json['category'] as String,
      emoji: json['emoji'] as String,
      colorHex: json['colorHex'] as String,
      note: json['note'] as String,
      photoBase64: normalizedPhoto,
      repeatYearly: json['repeatYearly'] as bool,
      inclusive: json['inclusive'] as bool,
      pinned: json['pinned'] as bool,
      reminderDays: reminder as int?,
      createdAt: created,
    );
  }
}

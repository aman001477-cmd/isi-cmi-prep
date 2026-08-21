/// A date-time reminder: fires once with a notification (and an in-app
/// popup while the app is open), even when the app is closed. [silent]
/// reminders notify WITHOUT any sound ("notification only").
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.at,
    this.silent = false,
    this.locked = false,
    this.lockedBy,
  });

  final String id;
  final String title;
  final DateTime at;
  final bool silent;
  final bool locked;
  final String? lockedBy;

  Reminder copyWith({DateTime? at, bool? locked, String? lockedBy}) => Reminder(
      id: id,
      title: title,
      at: at ?? this.at,
      silent: silent,
      locked: locked ?? this.locked,
      lockedBy: lockedBy ?? this.lockedBy);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'at': at.toIso8601String(),
        'silent': silent,
        'locked': locked,
        if (lockedBy != null) 'lockedBy': lockedBy,
      };

  static Reminder? fromJson(Map<String, Object?> json) {
    try {
      return Reminder(
        id: json['id'] as String,
        title: json['title'] as String,
        at: DateTime.parse(json['at'] as String),
        silent: json['silent'] as bool? ?? false,
        locked: json['locked'] as bool? ?? false,
        lockedBy: json['lockedBy'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

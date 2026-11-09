import 'dart:convert';

import '../../core/app_log.dart';
import 'mood_table.dart';

/// One of the 8 parts of the day (D-433, D-443). Index = position in
/// [DaylistConfig.slots]; names come from the UI by index (0 mattina presto,
/// 1 tarda mattinata, 2 primo pomeriggio, 3 tardo pomeriggio, 4 sera,
/// 5 tarda sera, 6 notte, 7 tarda notte).
class DaylistSlot {
  const DaylistSlot({
    required this.startHour,
    required this.enabled,
    required this.sharePercent,
    this.prefer = const {},
    this.avoid = const {},
    this.moods = const {},
  });

  /// First hour (0-23) of the slot; it ends where the next one starts.
  final int startHour;
  final bool enabled;

  /// Share of online suggestions, 0-100.
  final int sharePercent;

  /// Genres to prefer and to avoid, as the user wrote them.
  final Set<String> prefer, avoid;
  final Set<Mood> moods;

  DaylistSlot copyWith({
    int? startHour,
    bool? enabled,
    int? sharePercent,
    Set<String>? prefer,
    Set<String>? avoid,
    Set<Mood>? moods,
  }) => DaylistSlot(
    startHour: startHour ?? this.startHour,
    enabled: enabled ?? this.enabled,
    sharePercent: sharePercent ?? this.sharePercent,
    prefer: prefer ?? this.prefer,
    avoid: avoid ?? this.avoid,
    moods: moods ?? this.moods,
  );

  Map<String, Object?> toJson() => {
    'start': startHour,
    'on': enabled,
    'share': sharePercent,
    'prefer': prefer.toList(),
    'avoid': avoid.toList(),
    'moods': [for (final m in moods) m.name],
  };
}

/// The 8 slots, each ending where the next begins (cyclic). Immutable; only
/// the start hour can move, in 1 h steps, every slot lasting at least 1 h.
class DaylistConfig {
  DaylistConfig(List<DaylistSlot> slots) : slots = List.unmodifiable(slots) {
    assert(slots.length == slotCount);
  }

  static const slotCount = 8;

  /// Slots as shipped (D-443; genres and moods from the mockup).
  factory DaylistConfig.defaults() => DaylistConfig(const [
    DaylistSlot(startHour: 5, enabled: true, sharePercent: 25,
        prefer: {'folk', 'cantautorato', 'jazz'}, avoid: {'metal', 'punk'},
        moods: {Mood.calm, Mood.relaxing}),
    DaylistSlot(startHour: 9, enabled: true, sharePercent: 30,
        prefer: {'indie', 'pop', 'funk'}, moods: {Mood.cheerful, Mood.energetic}),
    DaylistSlot(startHour: 13, enabled: true, sharePercent: 30,
        prefer: {'rock', 'blues', 'soul'}, moods: {Mood.energetic, Mood.focus}),
    DaylistSlot(startHour: 16, enabled: true, sharePercent: 30,
        prefer: {'cantautorato', 'pop', 'folk'}, avoid: {'metal'},
        moods: {Mood.cheerful, Mood.calm}),
    DaylistSlot(startHour: 19, enabled: true, sharePercent: 30,
        prefer: {'funk', 'soul', 'indie'}, moods: {Mood.cheerful, Mood.relaxing}),
    DaylistSlot(startHour: 22, enabled: true, sharePercent: 30,
        prefer: {'lo-fi', 'jazz', 'soul'}, avoid: {'metal', 'punk'},
        moods: {Mood.relaxing, Mood.calm, Mood.focus}),
    DaylistSlot(startHour: 0, enabled: false, sharePercent: 20,
        prefer: {'ambient', 'elettronica'}, moods: {Mood.relaxing, Mood.calm}),
    DaylistSlot(startHour: 3, enabled: false, sharePercent: 20,
        prefer: {'classica', 'ambient'}, moods: {Mood.calm, Mood.relaxing}),
  ]);

  final List<DaylistSlot> slots;

  int _next(int i) => (i + 1) % slotCount;
  int _prev(int i) => (i + slotCount - 1) % slotCount;

  /// Hours the slot [i] lasts (1-23).
  int lengthOf(int i) => _span(slots[i].startHour, slots[_next(i)].startHour);

  /// Index of the slot that [hour] (0-23) belongs to.
  int slotOfHour(int hour) {
    for (var i = 0; i < slotCount; i++) {
      if (_span(slots[i].startHour, hour) < lengthOf(i)) return i;
    }
    return 0; // unreachable while the starts are valid (checked on load)
  }

  /// The slot at [t]; minutes do not matter.
  int slotAt(DateTime t) => slotOfHour(t.hour);

  /// When the slot after the one at [t] starts (always after [t]).
  DateTime nextChange(DateTime t) {
    final h = slots[_next(slotAt(t))].startHour;
    final today = DateTime(t.year, t.month, t.day, h);
    return today.isAfter(t) ? today : DateTime(t.year, t.month, t.day + 1, h);
  }

  /// Whether slot [i] may start at [hour]: strictly between the starts of the
  /// slots around it, so each one keeps at least 1 h.
  bool canStart(int i, int hour) {
    if (hour < 0 || hour > 23) return false;
    final from = slots[_prev(i)].startHour;
    return _span(from, hour) >= 1 && _span(from, hour) <= _span(from, slots[_next(i)].startHour) - 1;
  }

  /// A copy with slot [i] starting at [hour]; null when that is not allowed.
  DaylistConfig? withStart(int i, int hour) => canStart(i, hour) ? withSlot(i, slots[i].copyWith(startHour: hour)) : null;

  DaylistConfig withSlot(int i, DaylistSlot s) => DaylistConfig([...slots]..[i] = s);

  static int _span(int from, int to) => (to - from + 24) % 24;

  bool get _startsValid {
    var total = 0;
    for (var i = 0; i < slotCount; i++) {
      final l = lengthOf(i);
      if (l < 1 || slots[i].startHour < 0 || slots[i].startHour > 23) return false;
      total += l;
    }
    return total == 24;
  }

  String toJsonString() => jsonEncode([for (final s in slots) s.toJson()]);

  /// A wrong or missing field of a slot takes that field's default; start hours
  /// that do not make a valid day take the default starts. Data that is not a
  /// list of 8 means all defaults.
  factory DaylistConfig.fromJsonString(String? raw) {
    final base = DaylistConfig.defaults().slots;
    if (raw == null) return DaylistConfig.defaults();
    try {
      final list = jsonDecode(raw);
      if (list is! List || list.length != slotCount) throw const FormatException('need 8 slots');
      final c = DaylistConfig([for (var i = 0; i < slotCount; i++) _slotFrom(list[i], base[i])]);
      if (c._startsValid) return c;
      AppLog.w('daylist start hours invalid, back to the default hours');
      return DaylistConfig([for (var i = 0; i < slotCount; i++) c.slots[i].copyWith(startHour: base[i].startHour)]);
    } on FormatException catch (e) {
      AppLog.w('daylist slots unreadable, back to the defaults', e);
      return DaylistConfig.defaults();
    }
  }

  static DaylistSlot _slotFrom(Object? j, DaylistSlot d) {
    if (j is! Map) {
      AppLog.w('daylist slot is not a map, using its default');
      return d;
    }
    Set<String>? strs(Object? v) => v is List ? {for (final s in v) '$s'} : null;
    final start = j['start'], on = j['on'], share = j['share'];
    final moods = strs(j['moods']);
    return DaylistSlot(
      startHour: start is int && start >= 0 && start <= 23 ? start : d.startHour,
      enabled: on is bool ? on : d.enabled,
      sharePercent: share is int ? share.clamp(0, 100) : d.sharePercent,
      prefer: strs(j['prefer']) ?? d.prefer,
      avoid: strs(j['avoid']) ?? d.avoid,
      moods: moods == null
          ? d.moods
          : {
              for (final n in moods)
                for (final m in Mood.values)
                  if (m.name == n) m,
            },
    );
  }
}

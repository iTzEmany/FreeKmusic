import 'dart:convert';

import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/services/daylist/daylist_slots.dart';
import 'package:codecore/services/daylist/mood_table.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final c = DaylistConfig.defaults();
  DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 9, h, m);

  test('defaults: starts, quotas, night slots off', () {
    expect([for (final s in c.slots) s.startHour], [5, 9, 13, 16, 19, 22, 0, 3]);
    expect([for (final s in c.slots) s.sharePercent], [25, 30, 30, 30, 30, 30, 20, 20]);
    expect([for (final s in c.slots) s.enabled], [true, true, true, true, true, true, false, false]);
    expect(c.slots[5].prefer, {'lo-fi', 'jazz', 'soul'});
    expect(c.slots[5].moods, {Mood.relaxing, Mood.calm, Mood.focus});
  });

  test('slot boundaries', () {
    expect(c.slotAt(at(4, 59)), 7);
    expect(c.slotAt(at(5)), 0);
    expect(c.slotAt(at(8, 59)), 0);
    expect(c.slotAt(at(9)), 1);
    expect(c.slotAt(at(23, 59)), 5);
    expect(c.slotAt(at(0)), 6);
    expect(c.slotAt(at(3)), 7);
  });

  test('next change is the next start, across midnight too', () {
    expect(c.nextChange(at(8, 59)), at(9));
    expect(c.nextChange(at(9)), at(13));
    expect(c.nextChange(at(23, 30)), DateTime(2026, 11, 10, 0));
    expect(c.nextChange(at(4)), at(5));
  });

  test('a start moves by whole hours inside its neighbours, each slot keeps 1 h', () {
    expect(c.canStart(1, 6), isTrue); // after 5, before 13
    expect(c.canStart(1, 5), isFalse); // would leave slot 0 empty
    expect(c.canStart(1, 12), isTrue);
    expect(c.canStart(1, 13), isFalse);
    expect(c.canStart(1, 14), isFalse); // jumps over the next start
    expect(c.canStart(6, 22), isFalse); // notte cannot reach the start of tarda sera
    expect(c.canStart(6, 23), isTrue); // tarda sera then lasts 1 h
    expect(c.canStart(5, 23), isTrue); // tarda sera 22 -> 23, notte still starts at 0
    expect(c.canStart(5, 0), isFalse);
    final moved = c.withStart(1, 6)!;
    expect(moved.slotAt(at(5, 59)), 0);
    expect(moved.slotAt(at(6)), 1);
    expect(moved.lengthOf(0), 1);
    expect(c.withStart(1, 5), isNull);
  });

  test('saved in the store, back to defaults when unreadable', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await SettingsStore.open();
    expect(store.readDaylistConfig().slots[1].startHour, 9);
    await store.writeDaylistConfig(c.withStart(1, 6)!.withSlot(2, c.slots[2].copyWith(enabled: false, sharePercent: 45)));
    store = await SettingsStore.open();
    final back = store.readDaylistConfig();
    expect(back.slots[1].startHour, 6);
    expect(back.slots[2].enabled, isFalse);
    expect(back.slots[2].sharePercent, 45);
    expect(back.slots[5].avoid, {'metal', 'punk'});
    SharedPreferences.setMockInitialValues({daylistSlotsKey: '[{"start":5}]'});
    store = await SettingsStore.open();
    expect(store.readDaylistConfig().slots[0].startHour, 5);
    expect(store.readDaylistConfig().slots.length, 8);
    await store.resetDaylist();
    expect(store.readDaylistConfig().slots[1].startHour, 9);
  });
  test('a slot moved across midnight: tarda sera 22 to 2', () {
    final m = c.withStart(6, 2)!; // notte now starts at 02:00
    expect(m.slotAt(at(23)), 5);
    expect(m.slotAt(at(1, 30)), 5);
    expect(m.slotAt(at(2)), 6);
    expect(m.lengthOf(5), 4);
    expect(m.nextChange(at(23, 30)), DateTime(2026, 11, 10, 2));
    expect(m.nextChange(at(1)), at(2));
  });

  group('start hours that do not make a day take the default hours, other fields stay', () {
    String json(List<Object?> starts) => jsonEncode([
      for (var i = 0; i < 8; i++) {'start': starts[i], 'on': true, 'share': 40 + i, 'prefer': ['x'], 'avoid': [], 'moods': ['calm']},
    ]);
    void check(List<Object?> starts) {
      final back = DaylistConfig.fromJsonString(json(starts));
      expect([for (final s in back.slots) s.startHour], [5, 9, 13, 16, 19, 22, 0, 3], reason: '$starts');
      expect(back.slots[2].sharePercent, 42);
    }

    test('duplicates', () => check([5, 5, 13, 16, 19, 22, 0, 3]));
    test('not monotonic', () => check([5, 13, 9, 16, 19, 22, 0, 3]));
    test('out of range falls back to the field default', () => check([5, 9, 13, 16, 19, 22, 0, 30]));
    test('wrong type falls back to the field default', () => check([5, 9, 13, 16, 19, 22, 0, 'x']));
  });

  test('a wrong field takes its own default, not the whole configuration', () {
    final back = DaylistConfig.fromJsonString(
      jsonEncode([
        {'start': 6, 'on': 'yes', 'share': 'many', 'prefer': 3, 'avoid': ['a'], 'moods': ['zzz']},
        ...[for (var i = 1; i < 8; i++) 'junk'],
      ]),
    );
    final d = DaylistConfig.defaults();
    expect(back.slots[0].startHour, 6);
    expect(back.slots[0].enabled, d.slots[0].enabled);
    expect(back.slots[0].sharePercent, 25);
    expect(back.slots[0].prefer, d.slots[0].prefer);
    expect(back.slots[0].avoid, {'a'});
    expect(back.slots[0].moods, isEmpty);
    expect(back.slots[3].startHour, 16); // a junk slot is the default one
  });
}

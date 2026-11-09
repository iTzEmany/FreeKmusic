import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/services/daylist/mood_table.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('shipped table: 20 genres, compared without case or accents', () {
    final t = MoodTable.defaults();
    expect(t.genres.length, 20);
    expect(t.moodsOf('Jazz'), {Mood.relaxing, Mood.focus, Mood.melancholic});
    expect(t.moodsOf('LO-FI'), {Mood.relaxing, Mood.focus});
    expect(t.moodsOf('Elettronica'), t.moodsOf('elettrónica'));
  });

  test('an unknown genre has no mood', () {
    expect(MoodTable.defaults().moodsOf('Zouk'), isEmpty);
  });

  test('user changes are saved and read back, only the differences', () async {
    final t = MoodTable.defaults().withMoods('Zouk', {Mood.cheerful}).withMoods('metal', {});
    expect(t.moodsOf('zouk'), {Mood.cheerful});
    expect(t.moodsOf('metal'), isEmpty);
    SharedPreferences.setMockInitialValues({});
    var store = await SettingsStore.open();
    await store.writeMoodTable(t);
    store = await SettingsStore.open();
    final back = store.readMoodTable();
    expect(back.moodsOf('zouk'), {Mood.cheerful});
    expect(back.moodsOf('metal'), isEmpty);
    expect(back.moodsOf('rock'), MoodTable.defaults().moodsOf('rock'));
    expect(MoodTable.defaults().toJsonString(), '{}');
  });

  test('unreadable data means the shipped table', () {
    expect(MoodTable.fromJsonString('{{').moodsOf('rock'), isNotEmpty);
  });
}

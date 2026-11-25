import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/services/platform/window_title.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/title');
  final titles = <Object?>[];
  setUp(() {
    titles.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) async {
      if (c.method == 'setTitle') titles.add(c.arguments);
      return null;
    });
  });

  test('song then pause: the title follows, repeats are not sent', () async {
    final w = WindowTitle(channel: channel);
    await w.update(songLabel('Artist', 'Song'));
    await w.update(songLabel('Artist', 'Song'));
    await w.update(null);
    expect(titles, ['Artist — Song \u00B7 FreeKmusic', 'FreeKmusic']);
  });

  test('a song without artist shows the title alone', () {
    expect(songLabel(null, 'Song'), 'Song');
    expect(songLabel(' ', 'Song'), 'Song');
  });
}

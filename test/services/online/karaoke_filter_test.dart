import 'package:codecore/services/online/karaoke_filter.dart';
import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

SmartResult _r(String title, [String channel = 'Someone']) => SmartResult(
  primary: YtResult(id: title, title: title, channel: channel, duration: null),
  sources: {MediaKind.ytVideo},
  alternatives: const [],
  confidence: 0.5,
  hasVideo: false,
);

void main() {
  test('keeps karaoke titles, drops the rest and reactions, covers and lives', () {
    final out = karaokeResults([
      _r('Hello (Karaoke Version)'),
      _r('Hello official video'),
      _r('Hello KARAOKE reaction'),
      _r('Hello - karaoke cover'),
      _r('Hello (Live) karaoke'),
      _r('Hello - live karaoke'),
      _r('Live Forever (Karaoke Version)'),
      _r('Hello karaoke with lyrics'),
    ]);
    expect(out.map((r) => r.primary.title), [
      'Hello (Karaoke Version)',
      'Live Forever (Karaoke Version)',
      'Hello karaoke with lyrics',
    ]);
  });

  test('known channels come first, the others keep their order', () {
    final out = karaokeResults([
      _r('A karaoke', 'Nobody'),
      _r('B karaoke', 'Sing King'),
      _r('C karaoke', 'Other'),
      _r('D karaoke', 'KaraFun Karaoke'),
    ]);
    expect(out.map((r) => r.primary.title), [
      'B karaoke',
      'D karaoke',
      'A karaoke',
      'C karaoke',
    ]);
  });

  test('a song title that starts with live or cover is kept', () {
    final titles = [
      'Oasis - Live Forever (Karaoke Version)',
      'Sing King - Live and Let Die (Karaoke Version)',
      'Sing King - Cover Me (Karaoke)',
    ];
    expect(karaokeResults([for (final t in titles) _r(t)]).length, 3);
  });

  test('cover and live tags are dropped in any separator or bracket', () {
    final out = karaokeResults([
      _r('Hello | Live karaoke'),
      _r('Hello – Live (Karaoke)'),
      _r('Hello — cover karaoke'),
      _r('Hello [Live] karaoke'),
      _r('Hello [Cover] karaoke'),
      _r('Hello karaoke reactions'),
    ]);
    expect(out, isEmpty);
  });
}

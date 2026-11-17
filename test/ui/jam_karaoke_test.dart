import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/karaoke_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/ui/screens/jam/jam_karaoke.dart';
import 'package:codecore/ui/widgets/karaoke_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_voice_filter.dart';

class _FakeJam extends JamController {
  final sent = <JamCommand>[];
  @override
  JamUiState build() => const JamUiState();
  @override
  Future<JamError?> send(JamCommand cmd) async {
    sent.add(cmd);
    return null;
  }
}

JamKaraoke _jam({
  double? level,
  bool guests = false,
  bool host = false,
  bool remote = true,
  bool plays = true,
}) => JamKaraoke(
  level: level,
  guestsAllowed: guests,
  isHost: host,
  remote: remote,
  playsHere: plays,
  hostName: 'Marco',
);

void main() {
  late _FakeJam fake;

  Future<Harness> open(WidgetTester t, Widget child, JamKaraoke jam) async {
    t.view.physicalSize = const Size(500, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    fake = _FakeJam();
    final h = await Harness.create(t, tracks: 0);
    final List<Override> o = [
      jamProvider.overrideWith(() => fake),
      jamKaraokeProvider.overrideWithValue(jam),
      voiceFilterProvider.overrideWithValue(FakeVoiceFilter()),
    ];
    await h.pump(t, Scaffold(body: Center(child: child)), extraOverrides: o);
    return h;
  }

  IconButton mic(WidgetTester t) => t.widget<IconButton>(find.byType(IconButton));

  testWidgets('a guest without the host permission has the mic disabled, with the reason', (t) async {
    final h = await open(t, const KaraokeButton(), _jam());
    expect(mic(t).onPressed, isNull);
    expect(mic(t).tooltip, 'Il karaoke lo comanda l’host della Jam');
    expect(find.bySemanticsLabel('Il karaoke lo comanda l’host della Jam'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('a guest with the permission commands the Jam, never the local karaoke', (t) async {
    final h = await open(t, const KaraokeButton(), _jam(guests: true));
    expect(mic(t).onPressed, isNotNull);
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    await t.tap(find.byType(Switch));
    await t.pump();
    expect(fake.sent.single.type, JamCommandType.karaoke);
    expect(fake.sent.single.karaoke, 0.2); // the sheet's own level
    expect(ProviderScope.containerOf(t.element(find.byType(Scaffold).first)).read(settingsProvider).karaokeOn, isFalse);
    await h.dispose(t);
  });

  testWidgets('the host turns the karaoke off, and a drag sends few levels, the last one included', (t) async {
    final h = await open(t, const KaraokeButton(), _jam(host: true, level: 0.5));
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    await t.drag(find.byType(Slider), const Offset(60, 0));
    await t.pumpAndSettle();
    final levels = fake.sent.map((c) => c.karaoke).toList();
    expect(levels, isNotEmpty);
    expect(levels.length, lessThan(8));
    expect(levels.last, greaterThan(0.5));
    fake.sent.clear();
    await t.tap(find.byType(Switch));
    await t.pump();
    expect(fake.sent.single.type, JamCommandType.karaoke);
    expect(fake.sent.single.karaoke, isNull);
    await h.dispose(t);
  });

  testWidgets('the host setting «Gli ospiti possono usare il karaoke» sends the command', (t) async {
    final h = await open(t, const JamKaraokeHostTile(), _jam(host: true, remote: false));
    expect(find.text('Gli ospiti possono usare il karaoke'), findsOneWidget);
    expect(find.text('Nella Jam in casa suona un solo dispositivo: il karaoke vale per tutti.'), findsOneWidget);
    expect(t.widget<Switch>(find.byType(Switch)).value, isFalse);
    await t.tap(find.byType(Switch));
    await t.pump();
    expect(fake.sent.single.type, JamCommandType.karaokeGuests);
    expect(fake.sent.single.allowed, isTrue);
    await h.dispose(t);
  });

  testWidgets('a guest sees no host setting, and a remote host no local-Jam note', (t) async {
    var h = await open(t, const JamKaraokeHostTile(), _jam());
    expect(find.byType(Switch), findsNothing);
    await h.dispose(t);
    h = await open(t, const JamKaraokeHostTile(), _jam(host: true));
    expect(find.byType(Switch), findsOneWidget);
    expect(find.textContaining('un solo dispositivo'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('the guest box says who turned it on and «Ignora per me» is a local setting', (t) async {
    final h = await open(t, const JamKaraokeBox(), _jam(level: 0.1));
    expect(find.text('Karaoke acceso da Marco, voce 10 %'), findsOneWidget);
    expect(find.text('Ignora per me'), findsOneWidget);
    await t.tap(find.byType(Switch));
    await t.pump();
    expect(ProviderScope.containerOf(t.element(find.byType(Scaffold).first)).read(settingsProvider).karaokeJamIgnore, isTrue);
    expect(fake.sent, isEmpty); // the Jam does not change
    await h.dispose(t);
  });

  testWidgets('no guest box when the karaoke is off, in a local Jam, for the host or without playing here', (t) async {
    for (final j in [
      _jam(),
      _jam(level: 0.1, remote: false),
      _jam(level: 0.1, host: true),
      _jam(level: 0.1, plays: false),
    ]) {
      final h = await open(t, const JamKaraokeBox(), j);
      expect(find.byType(Switch), findsNothing);
      await h.dispose(t);
    }
  });
}

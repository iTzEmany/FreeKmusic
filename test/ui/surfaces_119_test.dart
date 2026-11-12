import 'package:codecore/ui/screens/now_playing/credits_card.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_cards.dart'
    show NpCard, StreamCardsWait, creditsRefreshHeight;
import 'package:codecore/ui/theme/custom_theme.dart';
import 'package:codecore/ui/widgets/blurred_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<Harness> _open(
  WidgetTester t,
  Future<Widget> Function(Harness) child, {
  bool? blurred,
  bool? credits,
}) async {
  t.view.physicalSize = const Size(400, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final h = await Harness.create(t, tracks: 1);
  await t.runAsync(
    () => h.store.writeSettings(
      h.store.readSettings().copyWith(
        blurredChrome: blurred ?? false,
        creditsDetails: credits ?? false,
      ),
    ),
  );
  final w = await t.runAsync(() => child(h));
  await h.pump(t, Scaffold(body: SingleChildScrollView(child: w!)));
  return h;
}

void main() {
  for (final on in [true, false]) {
    testWidgets('BlurredChrome with blurredChrome $on', (t) async {
      final h = await _open(
        t,
        (_) async =>
            const BlurredChrome(radius: 8, child: SizedBox(height: 20)),
        blurred: on,
      );
      expect(find.byType(BackdropFilter), on ? findsOneWidget : findsNothing);
      await h.dispose(t);
    });
  }

  group('surface alpha in CustomTheme', () {
    const base = CustomTheme(id: 't', name: 'T');
    test('surfaces keep their alpha, read back from json', () {
      final t = base.withColor(CcToken.surface2, const Color(0x80112233));
      expect(t.overrides[CcToken.surface2]!.a, closeTo(0x80 / 255, 0.01));
      final back = CustomTheme.fromJson(t.toJson())!;
      expect(back.overrides[CcToken.surface2], t.overrides[CcToken.surface2]);
    });

    test('below 20 % opacity stops at 20 %', () {
      final t = base.withColor(CcToken.surface1, const Color(0x05112233));
      expect(t.overrides[CcToken.surface1]!.a, closeTo(0x33 / 255, 0.01));
      final j = base.toJson();
      (j['colors']! as Map)['surface3'] = 0x00112233;
      expect(
        CustomTheme.fromJson(j)!.overrides[CcToken.surface3]!.a,
        closeTo(0x33 / 255, 0.01),
      );
    });

    test('text colours stay opaque', () {
      final t = base.withColor(CcToken.text, const Color(0x40112233));
      expect(t.overrides[CcToken.text]!.a, 1.0);
    });
  });

  testWidgets(
    'the credits skeleton grows by the refresh button when the setting is on',
    (t) async {
      Future<double> skeletonHeight(bool on) async {
        final h = await _open(
          t,
          (_) async => const StreamCardsWait(trackId: -1),
          credits: on,
        );
        final card = find.ancestor(
          of: find.text('Crediti e dettagli'),
          matching: find.byType(NpCard),
        );
        final height = t.getSize(card).height;
        await h.dispose(t);
        return height;
      }

      final off = await skeletonHeight(false);
      final on = await skeletonHeight(true);
      expect(on - off, creditsRefreshHeight);

      // The real card's button takes exactly that much.
      final h = await _open(
        t,
        (h) async =>
            CreditsCard(track: await h.db.select(h.db.tracks).getSingle()),
        credits: true,
      );
      expect(
        t.getSize(find.byType(OutlinedButton)).height,
        creditsRefreshHeight,
      );
      await h.dispose(t);
    },
  );
}

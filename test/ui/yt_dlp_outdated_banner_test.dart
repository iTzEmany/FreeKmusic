import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/ui/widgets/yt_dlp_outdated_banner.dart';
import 'package:codecore/providers/yt_dlp_update_providers.dart';
import 'package:codecore/services/online/yt_dlp_updater.dart';
import 'package:codecore/ui/screens/settings/download_settings_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  Future<void> show(WidgetTester tester, String version) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const Scaffold(body: YtDlpOutdatedBanner()),
      extraOverrides: [
        ytDlpStatusProvider.overrideWith((_) async => YtDlpStatus(version)),
      ],
    );
    addTearDown(() => h.dispose(tester));
  }

  testWidgets('an old yt-dlp shows the warning with its version',
      (tester) async {
    await show(tester, '2024.04.09');
    expect(find.textContaining('yt-dlp 2024.04.09 è troppo vecchio'),
        findsOneWidget);
  });

  // Which versions count as old (unreadable ones do not) is in
  // test/services/online/yt_dlp_version_test.dart.
  testWidgets('a recent yt-dlp shows nothing', (tester) async {
    await show(tester, '2026.08.19');
    expect(find.textContaining('troppo vecchio'), findsNothing);
  });

  testWidgets('after a failed update the banner offers «Riprova» and explains why',
      (tester) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const Scaffold(body: YtDlpOutdatedBanner()),
      extraOverrides: [
        ytDlpStatusProvider
            .overrideWith((_) async => const YtDlpStatus('2024.04.09')),
        ytDlpUpdateProvider.overrideWith(_FailedUpdate.new),
      ],
    );
    expect(find.text('Riprova'), findsOneWidget);
    expect(find.textContaining('rete non raggiungibile'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('settings row shows the yt-dlp version', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const Scaffold(body: DownloadSettingsTiles()),
      extraOverrides: [
        ytDlpStatusProvider
            .overrideWith((_) async => const YtDlpStatus('2026.08.19')),
      ],
    );
    expect(find.text('yt-dlp 2026.08.19'), findsOneWidget);
    await h.dispose(tester);
  });
}

class _FailedUpdate extends YtDlpUpdateNotifier {
  @override
  YtDlpUpdateState build() => const YtDlpUpdateState(YtDlpUpdatePhase.failed,
      error: YtDlpUpdateError.network);
}

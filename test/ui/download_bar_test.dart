import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/download_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _r = YtResult(id: 'v1', title: 'T', channel: 'c', duration: null);

class _Downloads extends DownloadsNotifier {
  @override
  List<DownloadItem> build() => [];
  void put(DownloadStatus s, [double p = 0]) => state = [DownloadItem(id: 1, result: _r, status: s, progress: p)];
}

void main() {
  testWidgets('progress, then «Scaricato» for a few seconds, then the idle widget', (tester) async {
    final d = _Downloads();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [downloadsProvider.overrideWith(() => d)],
        child: MaterialApp(
          theme: ThemeData(extensions: const [CcColors.notte]),
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DownloadBar(entryKey: _r.indexKey, idle: const Text('idle')),
          ),
        ),
      ),
    );
    expect(find.text('idle'), findsOneWidget);
    d.put(DownloadStatus.downloading, 0.4);
    await tester.pump();
    expect(find.text('idle'), findsNothing);
    expect(find.bySemanticsLabel('Scarico… 40%'), findsOneWidget);
    d.put(DownloadStatus.done, 1);
    await tester.pump();
    expect(find.text('Scaricato'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Scaricato'), findsNothing);
    expect(find.text('idle'), findsOneWidget);
  });
}

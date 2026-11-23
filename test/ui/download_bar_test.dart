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
const _b = YtResult(id: 'b', title: 'B', channel: 'c', duration: null);

class _Downloads extends DownloadsNotifier {
  @override
  List<DownloadItem> build() => [];
  void put(DownloadStatus s, [double p = 0, YtResult r = _r]) => state = [DownloadItem(id: 1, result: r, status: s, progress: p)];
  void set(List<DownloadItem> items) => state = items;
}

Widget _app(_Downloads d, {String? key, bool compact = false}) => ProviderScope(
  overrides: [downloadsProvider.overrideWith(() => d)],
  child: MaterialApp(
    theme: ThemeData(extensions: const [CcColors.notte]),
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DownloadBar(entryKey: key ?? _r.indexKey, compact: compact, idle: const Text('idle')),
    ),
  ),
);

double? _value(WidgetTester tester) {
  final w = tester.widget<ProgressIndicator>(find.byWidgetPredicate((w) => w is ProgressIndicator));
  return (w as dynamic).value as double?;
}

void main() {
  testWidgets('progress, then «Scaricato» for a few seconds, then the idle widget', (tester) async {
    final d = _Downloads();
    await tester.pumpWidget(_app(d));
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

  testWidgets('the «Scaricato» of a song does not show on another song swapped into the same slot', (tester) async {
    final d = _Downloads();
    await tester.pumpWidget(_app(d));
    d.put(DownloadStatus.downloading, 0.5);
    await tester.pump();
    d.put(DownloadStatus.done, 1);
    await tester.pump();
    expect(find.text('Scaricato'), findsOneWidget);
    await tester.pumpWidget(_app(d, key: _b.indexKey));
    await tester.pump();
    expect(find.text('Scaricato'), findsNothing);
    expect(find.text('idle'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a compact bar shows the progress but never the «Scaricato» block', (tester) async {
    final d = _Downloads();
    await tester.pumpWidget(_app(d, compact: true));
    d.put(DownloadStatus.downloading, 0.5);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    d.put(DownloadStatus.done, 1);
    await tester.pump();
    expect(find.text('Scaricato'), findsNothing);
    expect(find.text('idle'), findsOneWidget);
  });

  testWidgets('waiting for a retry, or queued with a leftover progress, is indeterminate', (tester) async {
    final d = _Downloads();
    await tester.pumpWidget(_app(d));
    d.put(DownloadStatus.waitingRetry, 0.7);
    await tester.pump();
    expect(_value(tester), isNull);
    d.put(DownloadStatus.queued, 0.3);
    await tester.pump();
    expect(_value(tester), isNull);
    expect(find.bySemanticsLabel('Download in corso'), findsOneWidget);
  });

  testWidgets('with two items for the same key the last one counts', (tester) async {
    final d = _Downloads();
    await tester.pumpWidget(_app(d));
    d.set(const [
      DownloadItem(id: 1, result: _r, status: DownloadStatus.failed),
      DownloadItem(id: 2, result: _r, status: DownloadStatus.downloading, progress: 0.2),
    ]);
    await tester.pump();
    expect(find.bySemanticsLabel('Scarico… 20%'), findsOneWidget);
  });

  testWidgets('the percentage is rounded: 0.405 reads 41%', (tester) async {
    final d = _Downloads();
    await tester.pumpWidget(_app(d));
    d.put(DownloadStatus.downloading, 0.405);
    await tester.pump();
    expect(find.bySemanticsLabel('Scarico… 41%'), findsOneWidget);
  });
}

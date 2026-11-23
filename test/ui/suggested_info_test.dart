import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/library_add_providers.dart' show savedStreamKeysProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/suggestion_actions.dart';
import 'package:codecore/providers/youtube_providers.dart'
    show downloadIndexProvider, downloadsProvider, DownloadsNotifier;
import 'package:codecore/services/online/download_queue.dart' show DownloadItem, DownloadStatus;
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/now_playing/suggested_info.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Track implements Track {
  _Track(this.id);
  @override
  final int id;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Actions implements SuggestionActions {
  final downloaded = <int>[];
  @override
  Future<bool?> downloadEntry(int id) async {
    downloaded.add(id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Downloads extends DownloadsNotifier {
  @override
  List<DownloadItem> build() => [];
  void put(DownloadStatus s, [double p = 0]) => state = [DownloadItem(id: 1, result: _yt, status: s, progress: p)];
}

const _yt = YtResult(id: 'v1', title: 'Oroscopo', channel: 'ch', duration: null, artists: ['Calcutta']);

void main() {
  late _Actions actions;
  late StreamController<Set<String>> saved;
  late _Downloads downloads;
  late Directory dir;
  late DownloadIndex index;
  setUp(() {
    actions = _Actions();
    saved = StreamController<Set<String>>();
    dir = Directory.systemTemp.createTempSync('suggested');
    index = DownloadIndex(File('${dir.path}/downloads.json'));
    downloads = _Downloads();
  });
  tearDown(() {
    saved.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    required bool suggested,
    VoidCallback? onDislike,
  }) async {
    final entries = OnlineEntries();
    final id = entries.register(
      _yt,
      seedTitle: 'Nella stanza 2',
      suggested: suggested,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineEntriesProvider.overrideWithValue(entries),
          downloadsProvider.overrideWith(() => downloads),
          suggestionActionsProvider.overrideWithValue(actions),
          savedStreamKeysProvider.overrideWith((ref) => saved.stream),
          downloadIndexProvider.overrideWith((ref) async => index),
        ],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SuggestedInfo(track: _Track(id), onDislike: onDislike),
          ),
        ),
      ),
    );
  }

  testWidgets('a suggested song has three tiles and an active Non mi piace', (
    tester,
  ) async {
    var taps = 0;
    await open(tester, suggested: true, onDislike: () => taps++);
    expect(find.text('Suggerito: simile a «Nella stanza 2»'), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(3));
    await tester.tap(find.text('Non mi piace'));
    expect(taps, 1);
  });

  testWidgets('an online song that is not suggested has two tiles', (
    tester,
  ) async {
    await open(tester, suggested: false);
    expect(find.byType(TextButton), findsNWidgets(2));
    expect(find.text('Non mi piace'), findsNothing);
  });

  testWidgets('each tile is a surface2 block with card corners', (
    tester,
  ) async {
    await open(tester, suggested: true, onDislike: () {});
    final cc = tester.element(find.byType(SuggestedInfo)).cc;
    final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
    expect(buttons, hasLength(3));
    for (final b in buttons) {
      expect(b.style!.backgroundColor!.resolve({}), cc.surface2);
      final shape = b.style!.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(CcDims.rCard));
    }
  });

  testWidgets('the first tile is «Aggiungi alla libreria» and calls the action', (
    tester,
  ) async {
    await open(tester, suggested: false);
    expect(find.text('Scarica'), findsNothing);
    expect(find.text('Aggiungi a playlist…'), findsOneWidget);
    await tester.tap(find.text('Aggiungi alla libreria'));
    await tester.pump();
    expect(actions.downloaded, hasLength(1));
  });

  testWidgets('the «Scaricato» line shows even though the song joins the library just before the download is done (D-697)', (tester) async {
    await open(tester, suggested: false);
    downloads.put(DownloadStatus.downloading, 0.5);
    await tester.pump();
    // The download is promoted: the index is invalidated before the queue says «done».
    final file = File('${dir.path}/v1.m4a')..writeAsStringSync('x');
    await tester.runAsync(() => index.add('v1', file.path));
    ProviderScope.containerOf(tester.element(find.byType(SuggestedInfo))).invalidate(downloadIndexProvider);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Aggiungi a playlist…'), findsNothing, reason: 'in the library: the tiles are gone');
    downloads.put(DownloadStatus.done, 1);
    await tester.pump();
    expect(find.text('Scaricato'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Scaricato'), findsNothing);
  });
}

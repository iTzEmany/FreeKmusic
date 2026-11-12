import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/activity_log_providers.dart';
import 'package:codecore/providers/activity_providers.dart';
import 'package:codecore/providers/recognition_providers.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:codecore/services/import/playlist_import_service.dart';
import 'package:codecore/l10n/app_localizations_it.dart';
import 'package:codecore/ui/screens/activity/activity_log_entry.dart' show logDayLabel;
import 'package:codecore/ui/screens/activity/activity_log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

class _Log extends ActivityLogNotifier {
  _Log(this.entries);
  final List<LogEntry> entries;
  static int cleared = 0;

  @override
  ActivityLogState build() => ActivityLogState(entries, entries.length);
  void push(LogEntry e) => state = ActivityLogState([e, ...state.entries], state.total + 1);

  @override
  Future<void> prune() async {}
  @override
  Future<void> clear() async {
    cleared++;
    state = const ActivityLogState([], 0);
  }
}

/// Only the first [first] lines are loaded; loadMore adds the rest.
class _Paged extends _Log {
  _Paged(super.entries, this.first);
  final int first;
  int loads = 0;

  @override
  ActivityLogState build() => ActivityLogState(entries.take(first).toList(), entries.length, logCounts(entries));
  @override
  Future<void> loadMore() async {
    loads++;
    state = ActivityLogState(entries, entries.length, logCounts(entries));
  }
}

final _proposal = (
  track: Track(
    coverSource: 0, id: 1, path: '/m/1.mp3', title: 'Uno', artist: 'A', albumKey: 'k', durationMs: 1000,
    format: 'mp3', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false, enrichStatus: 0,
    userEdited: false, missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
  ),
  rec: const Recognition(
    at: 1, src: RecogSource.tags, sure: true, identity: TrackIdentity(title: 'Uno', artist: 'A'), prop: 'open'),
);

LogEntry _dl(DateTime at, String name, {int? id}) => LogEntry(
  id: id,
  at: at,
  item: ActivityItem(kind: ActivityKind.download, key: 'k$name', name: name, running: false),
);

void main() {
  final now = DateTime.now();
  final noon = DateTime(now.year, now.month, now.day, 12);
  final old = noon.subtract(const Duration(days: 5));
  final entries = [
    _dl(noon, 'Volare', id: 1),
    LogEntry(id: 2, at: noon.subtract(const Duration(minutes: 5)), importName: 'Spotify', event: ImportEventKind.toolMissing),
    _dl(noon.subtract(const Duration(minutes: 10)), 'Blue Monday', id: 3),
    LogEntry(
      id: 4,
      at: noon.subtract(const Duration(days: 1)),
      item: const ActivityItem(kind: ActivityKind.scan, key: 's', name: null, done: 340, total: 340, running: false),
    ),
    LogEntry(
      id: 5,
      at: old,
      correction: ActivityLogRow(id: 1, at: 0, kind: 'correction', name: 'n', done: 0, total: 0, failed: 0),
      detail: const {
        'old': {'title': 'Vecchio', 'artist': 'Chan'},
        'new': {'title': 'Nuovo', 'artist': 'Band'},
      },
    ),
  ];

  Future<void> tapFilter(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester, {double scale = 1, bool backdrop = false, List<LogEntry>? only, Size size = const Size(400, 900), bool proposals = false, int? firstPage}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _Log.cleared = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityLogProvider.overrideWith(() => firstPage == null ? _Log(only ?? entries) : _Paged(only ?? entries, firstPage)),
          proposalsProvider.overrideWith((ref) => Stream.value(proposals ? [_proposal] : const [])),
        ],
        child: MaterialApp(
          theme: ThemeData(scaffoldBackgroundColor: backdrop ? Colors.transparent : null),
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: w!,
          ),
          home: const ActivityLogScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('lines are grouped under Oggi, Ieri and the date', (tester) async {
    await pump(tester);
    expect(find.text('Oggi'), findsOneWidget);
    expect(find.text('Ieri'), findsOneWidget);
    expect(find.text(DateFormat.MMMEd('it').format(DateTime(old.year, old.month, old.day))), findsOneWidget);
  });

  for (final backdrop in [false, true]) {
    testWidgets('the pinned day header ${backdrop ? 'has no solid box' : 'paints a solid box'} with backdrop=$backdrop', (tester) async {
      await pump(tester, backdrop: backdrop);
      final box = find.descendant(of: find.byType(PinnedHeaderSliver).first, matching: find.byType(ColoredBox));
      expect(box, backdrop ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('filters show their counts and keep only their category', (tester) async {
    await pump(tester);
    expect(find.text('Tutto 5'), findsOneWidget);
    expect(find.text('Download 2'), findsOneWidget);
    expect(find.text('Errori 1'), findsOneWidget);
    await tapFilter(tester, 'Correzioni 1');
    expect(find.text('Titolo e artista corretti'), findsOneWidget);
    expect(find.text('Libreria aggiornata'), findsNothing);
    expect(find.text('Oggi'), findsNothing);
  });

  testWidgets('a failure says «Non riuscito» and «Come risolvere» gives the steps', (tester) async {
    await pump(tester);
    await tapFilter(tester, 'Errori 1');
    expect(find.text('Non riuscito'), findsOneWidget);
    expect(find.text('Manca il componente per scaricare da YouTube.'), findsOneWidget);
    await tester.tap(find.text('Come risolvere'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('1. '), findsOneWidget);
    expect(find.textContaining('Riprendi'), findsOneWidget);
  });

  testWidgets('«Pulisci registro» asks first; Annulla keeps the lines', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pulisci registro'));
    await tester.pumpAndSettle();
    expect(find.text('Pulire il registro?'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(_Log.cleared, 0);
    expect(find.text('Oggi'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pulisci registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pulisci'));
    await tester.pumpAndSettle();
    expect(_Log.cleared, 1);
  });

  testWidgets('the downloads of a day are one row that opens on the songs', (tester) async {
    await pump(tester);
    expect(find.text('2 brani scaricati'), findsOneWidget);
    expect(find.text('Volare'), findsNothing);
    await tester.tap(find.text('Mostra i brani'));
    await tester.pump();
    expect(find.text('Volare'), findsOneWidget);
    expect(find.text('Blue Monday'), findsOneWidget);
  });

  testWidgets('a correction shows old and new on two lines, with Ripristina', (tester) async {
    await pump(tester);
    expect(find.text('Vecchio – Chan'), findsOneWidget);
    expect(find.text('Nuovo – Band'), findsOneWidget);
    expect(find.text('Ripristina'), findsOneWidget);
  });

  testWidgets('no overflow at text scale 2.0 on a phone', (tester) async {
    await pump(tester, scale: 2);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  LogEntry fileFail(String why) => LogEntry(
    at: noon,
    correction: ActivityLogRow(
      id: 2, at: 0, kind: 'correction', name: 'Volare', done: 0, total: 0, failed: 1, detail: '{"trackId":1,"file":"$why"}'),
    detail: {'trackId': 1, 'file': why},
  );

  testWidgets('a failed tag write names the song and the step for its reason; no Ripristina', (tester) async {
    await pump(tester, only: [fileFail('readOnly')]);
    expect(find.text('Correzione salvata, file non aggiornato'), findsOneWidget);
    expect(find.text('Volare'), findsOneWidget);
    expect(find.text('Non riuscito'), findsOneWidget);
    expect(find.text('Ripristina'), findsNothing);
    await tester.tap(find.text('Come risolvere'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Togli la sola lettura'), findsOneWidget);
    expect(find.text('file in sola lettura'), findsOneWidget, reason: 'the technical line is the reason, not the enum name');
  });

  testWidgets('a format that cannot be written has no steps to offer', (tester) async {
    await pump(tester, only: [fileFail('unsupported')]);
    expect(find.text('Come risolvere'), findsNothing);
  });

  testWidgets('the label of a correction says from and to', (tester) async {
    final sem = tester.ensureSemantics();
    await pump(tester);
    expect(find.bySemanticsLabel(RegExp('Da Vecchio – Chan a Nuovo – Band')), findsOneWidget);
    sem.dispose();
  });

  testWidgets('desktop: the list and the line picked side by side; the first one is shown at the start', (tester) async {
    await pump(tester, size: const Size(1200, 800));
    expect(find.text('2 brani scaricati'), findsNWidgets(2), reason: 'first row, in the list and in the panel');
    await tester.tap(find.text('Libreria aggiornata'));
    await tester.pump();
    expect(find.text('Libreria aggiornata'), findsNWidgets(2), reason: 'in the list and in the panel');
    expect(find.text('2 brani scaricati'), findsOneWidget);
    await tapFilter(tester, 'Correzioni 1');
    expect(find.text('Titolo e artista corretti'), findsNWidgets(2), reason: 'the pick is gone: the first line is shown');
  });

  testWidgets('desktop: the panel of a group of downloads lists every song of the group', (tester) async {
    await pump(tester, size: const Size(1200, 800));
    expect(find.text('Volare'), findsOneWidget);
    expect(find.text('Blue Monday'), findsOneWidget);
  });

  testWidgets('a group of downloads stays open when another download arrives', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Mostra i brani'));
    await tester.pump();
    final log = ProviderScope.containerOf(tester.element(find.byType(ActivityLogScreen))).read(activityLogProvider.notifier) as _Log;
    log.push(_dl(noon.add(const Duration(minutes: 1)), 'Nuova'));
    await tester.pump();
    expect(find.text('3 brani scaricati'), findsOneWidget);
    expect(find.text('Volare'), findsOneWidget);
    expect(find.text('Nascondi i brani'), findsOneWidget);
  });

  testWidgets('«Da confermare» shows with Tutto and Correzioni only', (tester) async {
    await pump(tester, proposals: true);
    expect(find.byKey(const ValueKey('to-confirm')), findsOneWidget);
    await tapFilter(tester, 'Download 2');
    expect(find.byKey(const ValueKey('to-confirm')), findsNothing);
    await tapFilter(tester, 'Correzioni 1');
    expect(find.byKey(const ValueKey('to-confirm')), findsOneWidget);
  });

  testWidgets('a filter with nothing on the first page reads on until it finds lines', (tester) async {
    // 50 downloads fill the first page; the only correction is further down.
    final many = [for (var i = 0; i < 50; i++) _dl(noon.subtract(Duration(minutes: i)), 'D$i'), entries.last];
    await pump(tester, only: many, firstPage: 50);
    await tapFilter(tester, 'Correzioni 1');
    await tester.pump();
    await tester.pump();
    final log = ProviderScope.containerOf(tester.element(find.byType(ActivityLogScreen))).read(activityLogProvider.notifier) as _Paged;
    expect(log.loads, greaterThan(0));
    expect(find.text('Titolo e artista corretti'), findsOneWidget);
  });

  testWidgets('a filter that has no line at all does not read the pages', (tester) async {
    final many = [for (var i = 0; i < 50; i++) _dl(noon.subtract(Duration(minutes: i)), 'D$i'), entries.last];
    await pump(tester, only: many, firstPage: 50);
    final log = ProviderScope.containerOf(tester.element(find.byType(ActivityLogScreen))).read(activityLogProvider.notifier) as _Paged;
    final before = log.loads; // the end of the list asks for more while the filter is Tutto
    await tapFilter(tester, 'Errori 0');
    await tester.pump();
    await tester.pump();
    expect(log.loads, before);
  });

  test('«Ieri» also on the first of January', () {
    final l = AppLocalizationsIt();
    final now = DateTime(2026, 1, 1, 10);
    expect(logDayLabel(l, 'it', DateTime(2025, 12, 31), now), 'Ieri');
    expect(logDayLabel(l, 'it', DateTime(2026, 1, 1), now), 'Oggi');
  });
}

import 'dart:io';

import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/data/db/app_database.dart' show Track, TracksCompanion;
import 'package:drift/drift.dart' show Value;
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/youtube_providers.dart' show downloadIndexProvider;
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/curiosity_finder.dart';
import 'package:codecore/services/online/curiosity_service.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:codecore/services/online/lyrics_chain.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:codecore/services/online/credits.dart';
import 'package:codecore/services/share/track_meta.dart';
import 'package:codecore/ui/screens/jam/jam_cards.dart' show JamInfoCard;
import 'package:codecore/ui/screens/jam/jam_parts.dart' show jamTriviaText;
import 'package:codecore/ui/screens/jam/jam_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _FakeJam extends JamController {
  _FakeJam(this.initial);
  final JamUiState initial;
  final sent = <JamCommand>[];

  @override
  JamUiState build() => initial;

  @override
  Future<JamError?> send(JamCommand cmd) async {
    sent.add(cmd);
    return null;
  }
}

class _FakeChain implements LyricsChain {
  _FakeChain({this.fail = false, this.limited = false});
  final bool fail, limited;
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<LyricsChainResult> find(Track t, {bool wantSynced = true, cancel}) async {
    calls++;
    if (fail) throw StateError('down');
    return LyricsChainResult(lyrics: const LyricsResult(plain: 'parole remote'), limited: limited);
  }
}

class _FakeCurio implements CuriosityService {
  _FakeCurio({this.fail = false});
  final bool fail;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<CuriosityLookup> find(Track t, String lang, {cancel, Map<String, String>? original}) async {
    if (fail) throw StateError('down');
    return CuriosityLookup(
      pair: CuriosityPair(song: Curiosity('storia remota', Uri.parse('https://a.b/x'), 'it')),
      artist: 'Band',
      outcome: const CuriosityOutcome(),
    );
  }
}

/// The real controller (fetchMeta/fetchCover included) in a remote guest state.
class _RemoteJam extends JamController {
  _RemoteJam(this.initial);
  final JamUiState initial;

  @override
  JamUiState build() {
    super.build();
    return initial;
  }
}

JamUiState active({required bool host}) => JamUiState(
  phase: JamPhase.active,
  role: host ? JamRole.host : JamRole.guest,
  peerName: 'Telefono',
  jam: const JamState(
    version: 3,
    items: [
      JamItem(id: 1, ownerDeviceId: 'host', title: 'Prima', ext: 'mp3'),
      JamItem(
        id: 2,
        ownerDeviceId: 'peer',
        title: 'Seconda',
        ext: 'mp3',
        artist: 'Band',
      ),
    ],
    currentIndex: 0,
    hostDeviceId: 'host',
    outputDeviceId: 'host',
  ),
);

void main() {
  for (final host in [true, false]) {
    testWidgets(
      'tap on a row opens the info screen as ${host ? 'host' : 'guest'}',
      (tester) async {
        tester.view.physicalSize = const Size(500, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = await Harness.create(tester);
        final fake = _FakeJam(active(host: host));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...h.overrides,
              jamProvider.overrideWith(() => fake),
              jamTrackCoverProvider.overrideWith((ref, id) async => null),
              jamTrackMetaProvider.overrideWith(
                (ref, id) async => id == 2
                    ? const TrackMeta(
                        title: 'Seconda',
                        lyricsPlain: 'parole',
                        curiosities:
                            'Una storia\nhttps://it.wikipedia.org/wiki/X',
                      )
                    : const TrackMeta(),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('it'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const JamScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        // The shared queue opens from «Coda»: every row has its ⋮.
        await tester.tap(find.text('Coda'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Altre azioni'), findsNWidgets(2));

        await tester.tap(find.text('Seconda'));
        await tester.pumpAndSettle();
        expect(find.text('Info sul brano'), findsOneWidget);
        expect(find.text('parole'), findsOneWidget);
        expect(find.text('Una storia'), findsOneWidget);
        expect(find.text('Curiosità'), findsOneWidget);
        // «Salta qui» for everyone (D-160).
        expect(find.text('Salta qui'), findsOneWidget);
        expect(find.text('Vai all’artista'), findsOneWidget);
        await tester.tap(find.text('Salta qui'));
        await tester.pumpAndSettle();
        expect(fake.sent.single.type, JamCommandType.jump);
        expect(fake.sent.single.itemId, 2);
        await tester.pumpWidget(const SizedBox());
        await h.dispose(tester);
      },
    );
  }

  testWidgets('without meta the screen shows the item\'s basic data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...h.overrides,
          jamProvider.overrideWith(() => _FakeJam(active(host: false))),
          jamTrackCoverProvider.overrideWith((ref, id) async => null),
          jamTrackMetaProvider.overrideWith(
            (ref, id) async =>
                const TrackMeta(title: 'Seconda', artist: 'Band'),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const JamScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Coda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seconda'));
    await tester.pumpAndSettle();
    expect(find.text('Band'), findsWidgets);
    expect(find.text('Testo'), findsNothing);
    expect(find.text('Crediti e dettagli'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await h.dispose(tester);
  });

  testWidgets('credits in the received meta show the section', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...h.overrides,
          jamProvider.overrideWith(() => _FakeJam(active(host: false))),
          jamTrackCoverProvider.overrideWith((ref, id) async => null),
          jamTrackMetaProvider.overrideWith(
            (ref, id) async => TrackMeta(
              title: 'Seconda',
              credits: [TrackCredit('Mario Rossi', 'producer', 'deezer')],
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const JamScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Coda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seconda'));
    await tester.pumpAndSettle();
    expect(find.text('Crediti e dettagli'), findsOneWidget);
    expect(find.text('Mario Rossi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await h.dispose(tester);
  });

  testWidgets('remote guest: meta and cover of an item come from its own fields, no host call',
      (tester) async {
    const item = JamItem(
        id: 5, ownerDeviceId: 'peer', title: 'Remota', ext: 'mp3', artist: 'Band', ref: '12',
        videoId: 'abcdefghijk');
    final h = await Harness.create(tester);
    final c = ProviderContainer(overrides: [
      ...h.overrides,
      lyricsChainProvider.overrideWithValue(_FakeChain()),
      curiosityServiceProvider.overrideWithValue(_FakeCurio()),
      jamProvider.overrideWith(() => _RemoteJam(const JamUiState(
          phase: JamPhase.active,
          role: JamRole.guest,
          remote: true,
          jam: JamState(version: 1, items: [item], hostDeviceId: 'host', outputDeviceId: 'host')))),
    ]);
    addTearDown(c.dispose);
    final ctrl = c.read(jamProvider.notifier);
    final meta = await ctrl.fetchMeta(item);
    expect((meta.title, meta.artist), ('Remota', 'Band'));
    expect(meta.lyricsPlain, 'parole remote');
    expect(jamTriviaText(meta.curiosities), 'storia remota');
    expect(await ctrl.fetchCover(item), isNull);
    await h.dispose(tester);
  });

  testWidgets('the host\'s unreachable mark comes from JamUiState', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final base = active(host: true);
    final st = base.copyWith(
      unreachable: ['peer'],
      jam: base.jam!.copyWith(participants: const [
        JamParticipant(id: 'host', name: 'Io', host: '', port: 0),
        JamParticipant(id: 'peer', name: 'Telefono', host: '', port: 0),
      ]),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [...h.overrides, jamProvider.overrideWith(() => _FakeJam(st))],
      child: MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const JamScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Telefono (', findRichText: true), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await h.dispose(tester);
  });

  testWidgets('remote guest: a failing lyrics or curiosity source still gives title and artist',
      (tester) async {
    const item = JamItem(
        id: 5, ownerDeviceId: 'peer', title: 'Remota', ext: 'mp3', artist: 'Band',
        videoId: 'abcdefghijk');
    final h = await Harness.create(tester);
    final c = ProviderContainer(overrides: [
      ...h.overrides,
      lyricsChainProvider.overrideWithValue(_FakeChain(fail: true)),
      curiosityServiceProvider.overrideWithValue(_FakeCurio(fail: true)),
      jamProvider.overrideWith(() => _RemoteJam(const JamUiState(
          phase: JamPhase.active,
          role: JamRole.guest,
          remote: true,
          jam: JamState(version: 1, items: [item], hostDeviceId: 'host', outputDeviceId: 'host')))),
    ]);
    addTearDown(c.dispose);
    final meta = await c.read(jamProvider.notifier).fetchMeta(item);
    expect((meta.title, meta.artist, meta.lyricsPlain, meta.curiosities), ('Remota', 'Band', null, null));
    await h.dispose(tester);
  });

  testWidgets('remote guest: an own item with no local row falls back to the lookups, done once',
      (tester) async {
    // The test hub has no device id: '' is this device.
    const item = JamItem(
        id: 6, ownerDeviceId: '', title: 'Mia', ext: 'mp3', artist: 'Io',
        ref: 'yt:youtube:abcdefghijk', partKey: '99', videoId: 'abcdefghijk');
    final h = await Harness.create(tester);
    final chain = _FakeChain();
    final idx = DownloadIndex(File('${Directory.systemTemp.path}/no-such-downloads.json'));
    final c = ProviderContainer(overrides: [
      ...h.overridesWith([downloadIndexProvider.overrideWith((ref) async => idx)]),
      lyricsChainProvider.overrideWithValue(chain),
      curiosityServiceProvider.overrideWithValue(_FakeCurio()),
      jamProvider.overrideWith(() => _RemoteJam(const JamUiState(
          phase: JamPhase.active,
          role: JamRole.guest,
          remote: true,
          jam: JamState(version: 1, items: [item], hostDeviceId: 'host', outputDeviceId: 'host')))),
    ]);
    addTearDown(c.dispose);
    final ctrl = c.read(jamProvider.notifier);
    // The DB lookup is real async work: outside the test's fake clock.
    final first = (await tester.runAsync(() => ctrl.fetchMeta(item)))!;
    await tester.runAsync(() => ctrl.fetchMeta(item));
    expect(first.lyricsPlain, 'parole remote');
    expect(chain.calls, 1);
    await h.dispose(tester);
  });

  testWidgets('remote guest: a refused (limited) lookup is not remembered, searched again',
      (tester) async {
    const item = JamItem(id: 7, ownerDeviceId: 'peer', title: 'Remota', ext: 'mp3');
    final h = await Harness.create(tester);
    final chain = _FakeChain(limited: true);
    final c = ProviderContainer(overrides: [
      ...h.overrides,
      lyricsChainProvider.overrideWithValue(chain),
      curiosityServiceProvider.overrideWithValue(_FakeCurio()),
      jamProvider.overrideWith(() => _RemoteJam(const JamUiState(
          phase: JamPhase.active,
          role: JamRole.guest,
          remote: true,
          jam: JamState(version: 1, items: [item], hostDeviceId: 'host', outputDeviceId: 'host')))),
    ]);
    addTearDown(c.dispose);
    final ctrl = c.read(jamProvider.notifier);
    await ctrl.fetchMeta(item);
    await ctrl.fetchMeta(item);
    expect(chain.calls, 2);
    await h.dispose(tester);
  });

  testWidgets('LAN host: a remote guest\'s track (no route to the owner) gets the local lookups',
      (tester) async {
    const item = JamItem(id: 9, ownerDeviceId: 'peer', title: 'Remota', ext: 'mp3', artist: 'Band');
    final h = await Harness.create(tester);
    final chain = _FakeChain();
    final c = ProviderContainer(overrides: [
      ...h.overrides,
      lyricsChainProvider.overrideWithValue(chain),
      curiosityServiceProvider.overrideWithValue(_FakeCurio()),
      jamProvider.overrideWith(() => _RemoteJam(const JamUiState(
          phase: JamPhase.active,
          role: JamRole.host,
          jam: JamState(version: 1, items: [item], hostDeviceId: 'host', outputDeviceId: 'host',
              participants: [JamParticipant(id: 'peer', name: 'Remoto')])))),
    ]);
    addTearDown(c.dispose);
    final meta = await c.read(jamProvider.notifier).fetchMeta(item);
    expect(meta.lyricsPlain, 'parole remote');
    expect(meta.curiosities, startsWith('storia remota'));
    expect(chain.calls, 1);
    await h.dispose(tester);
  });

  testWidgets('remote guest: an own item is found through its part key, with its local lyrics',
      (tester) async {
    const item = JamItem(
        id: 8, ownerDeviceId: '', title: 'Mia', ext: 'mp3', ref: 'yt:youtube:abcdefghijk',
        partKey: '1', videoId: 'abcdefghijk');
    final h = await Harness.create(tester);
    await h.db.into(h.db.tracks).insert(TracksCompanion.insert(
        path: '/m/a.mp3', title: 'Mia', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1,
        addedAt: 1, lyricsPlain: const Value('parole locali')));
    final chain = _FakeChain();
    final idx = DownloadIndex(File('${Directory.systemTemp.path}/no-such-downloads.json'));
    final c = ProviderContainer(overrides: [
      ...h.overridesWith([downloadIndexProvider.overrideWith((ref) async => idx)]),
      lyricsChainProvider.overrideWithValue(chain),
      curiosityServiceProvider.overrideWithValue(_FakeCurio()),
      jamProvider.overrideWith(() => _RemoteJam(const JamUiState(
          phase: JamPhase.active,
          role: JamRole.guest,
          remote: true,
          jam: JamState(version: 1, items: [item], hostDeviceId: 'host', outputDeviceId: 'host')))),
    ]);
    addTearDown(c.dispose);
    final meta = (await tester.runAsync(() => c.read(jamProvider.notifier).fetchMeta(item)))!;
    expect(meta.lyricsPlain, 'parole locali');
    expect(chain.calls, 0);
    await h.dispose(tester);
  });

  for (final (name, ref, remote, asks) in [
    ('a LAN library item with a video id', '12', false, 0),
    ('a remote guest\'s item with a video id', '12', true, 1),
    ('an online item', 'yt:youtube:abcdefghijk', false, 1),
  ]) {
    testWidgets('curiosity card: $name asks online recognition $asks time(s)', (tester) async {
      final item = JamItem(
          id: 9, ownerDeviceId: 'peer', title: 'T', ext: 'mp3', ref: ref, videoId: 'abcdefghijk');
      final h = await Harness.create(tester);
      final asked = <String>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...h.overrides,
          jamProvider.overrideWith(() => _FakeJam(JamUiState(
              phase: JamPhase.active,
              role: JamRole.guest,
              remote: remote,
              jam: JamState(version: 1, items: [item], hostDeviceId: 'host', outputDeviceId: 'host')))),
          jamTrackMetaProvider.overrideWith((ref, id) async => const TrackMeta()),
          onlineRecognitionProvider.overrideWith((ref, v) async {
            asked.add(v);
            return null;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: JamInfoCard(item: item)),
        ),
      ));
      await tester.pump();
      expect(asked.length, asks);
      await tester.pumpWidget(const SizedBox());
      await h.dispose(tester);
    });
  }
}

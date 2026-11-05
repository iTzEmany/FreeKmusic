import 'dart:io';

import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/youtube_providers.dart' show downloadIndexProvider;
import 'package:codecore/services/online/download_index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/ui/screens/jam/jam_queue_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _FakeJam extends JamController {
  _FakeJam(this.initial);
  final JamUiState initial;
  final sent = <JamCommand>[];
  final _seen = <String, String>{};
  void set(JamUiState s) {
    _remember(s);
    state = s;
  }

  void _remember(JamUiState s) {
    for (final p in s.jam?.participants ?? const <JamParticipant>[]) {
      if (p.name.isNotEmpty) _seen[p.id] = p.name;
    }
  }

  @override
  String? seenName(String id) => _seen[id];

  @override
  JamUiState build() {
    _remember(initial);
    return initial;
  }

  @override
  Future<JamError?> send(JamCommand cmd) async {
    sent.add(cmd);
    return null;
  }
}

JamUiState _state({required bool host, JamMode mode = JamMode.host}) => JamUiState(
      phase: JamPhase.active,
      role: host ? JamRole.host : JamRole.guest,
      peerName: 'Telefono',
      peerId: 'peer',
      jam: JamState(
        version: 3,
        mode: mode,
        items: const [
          JamItem(id: 1, ownerDeviceId: 'host', title: 'Prima', ext: 'mp3', durationMs: 1000),
          JamItem(id: 2, ownerDeviceId: 'peer', title: 'Seconda', ext: 'mp3',
              durationMs: 1000, suggested: true),
        ],
        currentIndex: 0,
        hostDeviceId: 'host',
        outputDeviceId: 'host',
      ),
    );

Future<(_FakeJam, Harness)> _open(WidgetTester tester, JamUiState s) async {
  final h = await Harness.create(tester);
  final fake = _FakeJam(s);
  await h.pump(
    tester,
    Scaffold(
      body: CustomScrollView(slivers: const [JamQueueSliver()]),
    ),
    extraOverrides: [jamProvider.overrideWith(() => fake)],
  );
  return (fake, h);
}

JamUiState _people(List<JamParticipant> people) => JamUiState(
      phase: JamPhase.active,
      role: JamRole.host,
      jam: JamState(
        version: 3,
        items: const [
          JamItem(id: 2, ownerDeviceId: 'peer', title: 'Seconda', ext: 'mp3', durationMs: 1000),
        ],
        participants: people,
        currentIndex: 0,
        hostDeviceId: 'host',
        outputDeviceId: 'host',
      ),
    );

const _host = JamParticipant(id: 'host', name: 'PC');
const _peer = JamParticipant(id: 'peer', name: 'Mi A3');

void main() {
  testWidgets('chi è uscito resta col nome visto prima', (tester) async {
    final (fake, h) = await _open(tester, _people([_host, _peer]));
    expect(find.textContaining('Mi A3'), findsOneWidget);
    fake.set(_people([_host]));
    await tester.pump();
    expect(find.textContaining('Mi A3'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('chi è uscito e non si è mai visto: «Ospite»', (tester) async {
    final (_, h) = await _open(tester, _people([_host]));
    expect(find.textContaining('Ospite'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('il nome resta anche chiudendo e riaprendo il foglio', (tester) async {
    final h = await Harness.create(tester);
    final fake = _FakeJam(_people([_host, _peer]));
    final open = ValueNotifier(true);
    await h.pump(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: open,
        builder: (_, o, _) => Scaffold(
          body: o ? CustomScrollView(slivers: const [JamQueueSliver()]) : const SizedBox(),
        ),
      ),
      extraOverrides: [jamProvider.overrideWith(() => fake)],
    );
    expect(find.textContaining('Mi A3'), findsOneWidget);
    open.value = false;
    await tester.pump();
    fake.set(_people([_host]));
    await tester.pump();
    open.value = true;
    await tester.pump();
    expect(find.textContaining('Mi A3'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('host: la riga della modalità cambia la coda', (tester) async {
    final (fake, h) = await _open(tester, _state(host: true));
    expect(find.text("Coda dell'host"), findsOneWidget);
    await tester.tap(find.text('Coda insieme'));
    await tester.pump();
    expect(fake.sent.single.type, JamCommandType.setMode);
    expect(fake.sent.single.mode, JamMode.together);
    await h.dispose(tester);
  });

  testWidgets('ospite: la riga c\'è ma non si tocca', (tester) async {
    final (fake, h) = await _open(tester, _state(host: false));
    expect(find.text('Coda insieme'), findsOneWidget);
    await tester.tap(find.text('Coda insieme'), warnIfMissed: false);
    await tester.pump();
    expect(fake.sent, isEmpty);
    await h.dispose(tester);
  });

  testWidgets('in «Coda insieme» niente maniglie; «Suggerito» sull\'item suggerito', (tester) async {
    final (_, h) = await _open(tester, _state(host: true, mode: JamMode.together));
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    expect(find.textContaining('Suggerito'), findsOneWidget);
    await h.dispose(tester);
    final (_, h2) = await _open(tester, _state(host: true));
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    await h2.dispose(tester);
  });

  group('«Scarica» nel ⋮ (D-181)', () {
    const online = JamItem(id: 1, ownerDeviceId: 'host', title: 'Web', ext: 'm4a',
        ref: 'yt:youtube:abcdefghijk', videoId: 'abcdefghijk');
    const local = JamItem(id: 2, ownerDeviceId: 'host', title: 'Locale', ext: 'mp3', ref: '7');

    Future<(DownloadIndex, Harness)> openMenu(WidgetTester tester, JamItem it) async {
      final idx = DownloadIndex(File('${Directory.systemTemp.path}/no-such-downloads.json'));
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        Scaffold(body: CustomScrollView(slivers: const [JamQueueSliver()])),
        extraOverrides: [
          downloadIndexProvider.overrideWith((ref) async => idx),
          jamProvider.overrideWith(() => _FakeJam(JamUiState(
                phase: JamPhase.active,
                role: JamRole.host,
                jam: JamState(version: 1, items: [it], hostDeviceId: 'host', outputDeviceId: 'host'),
              ))),
        ],
      );
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      return (idx, h);
    }

    testWidgets('brano online non in libreria: c\'è; entra in libreria a foglio aperto: sparisce',
        (tester) async {
      final (idx, h) = await openMenu(tester, online);
      expect(find.text('Scarica'), findsOneWidget);
      final f = File('${Directory.systemTemp.path}/jam-dl-test.m4a')..writeAsStringSync('x');
      addTearDown(() => f.existsSync() ? f.deleteSync() : null);
      await tester.runAsync(() => idx.add('abcdefghijk', f.path));
      ProviderScope.containerOf(tester.element(find.byType(JamQueueSliver)))
          .invalidate(downloadIndexProvider);
      await tester.pumpAndSettle();
      expect(find.text('Scarica'), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('brano di libreria: non c\'è', (tester) async {
      final (_, h) = await openMenu(tester, local);
      expect(find.text('Salta qui'), findsOneWidget);
      expect(find.text('Scarica'), findsNothing);
      await h.dispose(tester);
    });
  });
}

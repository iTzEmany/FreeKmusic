import 'dart:io';

import 'package:codecore/providers/jam_media.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:codecore/services/jam/jam_cache.dart';
import 'package:codecore/services/jam/jam_guest_link.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/jam_output.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

JamItem _item(String owner, {int id = 7, String? ref}) =>
    JamItem(id: id, ownerDeviceId: owner, title: 't', ext: 'mp3', ref: ref);

class _FakeJamCache extends JamCache {
  _FakeJamCache() : super(Directory.systemTemp);
  final fetched = <int>[];
  final pruned = <Set<int>>[];
  var cleared = false;

  @override
  Future<File?> fetch(
    JamItem item,
    Uri uri,
    Map<String, String> headers,
  ) async {
    fetched.add(item.id);
    return null;
  }

  @override
  Future<void> prune(Set<int> keepIds) async => pruned.add(keepIds);

  @override
  Future<void> clear() async => cleared = true;

  @override
  JamSource? sourceFor(JamItem item, JamSource? remote) => remote;
}

class _FakeStreamCache implements StreamCache {
  final pins = <String>[], unpins = <String>[];

  @override
  void pin(String key) => pins.add(key);

  @override
  void unpin(String key) => unpins.add(key);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  JamState jamOf({
    List<JamItem> items = const [],
    int index = -1,
    bool synced = false,
  }) => JamState(
    hostDeviceId: 'h',
    outputDeviceId: 'h',
    outputDeviceIds: synced ? const ['h', 'g2'] : const [],
    items: items,
    currentIndex: index,
    participants: const [
      JamParticipant(id: 'h', name: 'host'),
      JamParticipant(id: 'g2', name: 'other', host: '10.0.0.5', port: 4000),
    ],
  );
  const files = JamHostFiles(
    sessionId: 's1',
    hostBase: 'http://10.0.0.1:3000/jam',
    fileToken: 'k',
  );
  final streams = _FakeStreamCache();
  late Ref ref;
  late ProviderContainer container;
  setUp(() {
    streams.pins.clear();
    streams.unpins.clear();
    container = ProviderContainer(
      overrides: [streamCacheProvider.overrideWithValue(streams)],
    );
    ref = container.read(Provider<Ref>((r) => r));
  });
  tearDown(() => container.dispose());

  JamMedia media({JamHostFiles? files, JamState? jam, bool remote = false}) =>
      JamMedia(
        () => ref,
        () => 'me',
        () => JamUiState(
          phase: JamPhase.active,
          role: JamRole.guest,
          jam: jam ?? jamOf(),
          remote: remote,
        ),
        () => null,
        () => files,
      );

  test(
    'a guest reaches the host at hostBase and another guest at its own address',
    () {
      final m = media(files: files);
      expect(
        m.remoteUri(_item('h')).toString(),
        'http://10.0.0.1:3000/jam/s1/file/7',
      );
      expect(
        m.remoteUri(_item('g2')).toString(),
        'http://10.0.0.5:4000/jam/s1/file/7',
      );
    },
  );

  test('no session, no address', () {
    expect(media().remoteUri(_item('h')), isNull);
  });

  test(
    'resolve fetches a remote item into the cache first only in a synced Jam',
    () async {
      for (final synced in [true, false]) {
        final cache = _FakeJamCache();
        final m = media(
          files: files,
          jam: jamOf(synced: synced),
        )..cache = cache;
        await m.resolve(_item('h'));
        expect(cache.fetched, synced ? [7] : isEmpty);
      }
    },
  );

  test('precache keeps the current and the next item', () async {
    final cache = _FakeJamCache();
    final jam = jamOf(
      items: [_item('h', id: 1), _item('h', id: 2), _item('h', id: 3)],
      index: 0,
    );
    media(files: files, jam: jam)
      ..cache = cache
      ..precache(jam);
    await Future<void>.delayed(Duration.zero);
    expect(cache.pruned, [
      {1, 2},
    ]);
  });

  test('syncPins pins the queue keys and unpins those that left it', () {
    final m = media();
    m.syncPins(
      jamOf(
        items: [
          _item('me', id: 1, ref: 'yt:a'),
          _item('me', id: 2, ref: 'yt:b'),
        ],
        index: 0,
      ),
    );
    expect(streams.pins, unorderedEquals(['a', 'b']));
    m.syncPins(jamOf(items: [_item('me', id: 2, ref: 'yt:b')], index: 0));
    expect(streams.unpins, ['a']);
  });

  test('dispose clears the cache and drops it', () async {
    final cache = _FakeJamCache();
    final m = media()..cache = cache;
    await m.dispose();
    expect(cache.cleared, isTrue);
    expect(m.cache, isNull);
  });

  test('a remote guest asks nobody for a cover', () async {
    expect(
      await media(files: files, remote: true).fetchCover(_item('h')),
      isNull,
    );
  });
}

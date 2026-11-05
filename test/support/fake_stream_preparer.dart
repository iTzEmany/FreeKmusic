import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, VoidCallback;
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/stream/stream_preparer.dart';

/// A phases notifier that counts its listeners (hasListeners is protected).
class CountingNotifier extends ValueNotifier<Map<String, StreamPhase>> {
  CountingNotifier() : super({});
  int listeners = 0;
  @override
  void addListener(VoidCallback l) {
    listeners++;
    super.addListener(l);
  }

  @override
  void removeListener(VoidCallback l) {
    listeners--;
    super.removeListener(l);
  }
}

/// A [StreamPreparer] with no network: `ready` writes a tiny file, makes the
/// shadow row like the real one and can be held back or made to fail per key.
class FakeStreamPreparer implements StreamPreparer {
  FakeStreamPreparer(this.tracks, this.dir);

  @override
  final TrackRepository tracks;
  final Directory dir;
  final queues = <List<String>>[];
  final asked = <String>[];
  final failing = <String>{};
  Object failure = StateError('download failed'); // what a failing key throws
  final gates = <String, Completer<void>>{};
  @override
  final CountingNotifier phases = CountingNotifier();

  /// Files already in the cache, by key.
  final cached = <String, File>{};

  @override
  Future<File?> cachedFile(String key, YtResult r) async => cached[key];

  @override
  void setQueue(List<StreamItem> items) => queues.add([for (final i in items) i.key]);

  @override
  Future<File> ready(String key, YtResult r) async {
    asked.add(key);
    final gate = gates[key];
    if (gate != null) await gate.future;
    if (failing.contains(key)) throw failure;
    final file = File('${dir.path}/${key.replaceAll(':', '_')}.m4a')..writeAsStringSync('x');
    await tracks.upsertStreamRow(key, r, file);
    return file;
  }

  /// Keys that start from an address, not the file (what `start` answers).
  final urls = <String, (Uri, Map<String, String>)>{};

  /// The `keep` of every `start` call.
  final keeps = <bool>[];

  /// What `restart` answers per key, in order (an empty list: the file).
  final restarts = <String, List<StreamStart>>{};
  final restarted = <String>[];

  /// Holds `restart` back until completed.
  Completer<void>? restartGate;

  @override
  Future<StreamStart> start(String key, YtResult r, {bool keep = true}) async {
    keeps.add(keep);
    final u = urls[key];
    return u != null ? StreamStart.url(u.$1, u.$2) : StreamStart.file(await ready(key, r));
  }

  @override
  Future<StreamStart> restart(String key, YtResult r, {bool keep = true}) async {
    restarted.add(key);
    await restartGate?.future;
    final next = restarts[key];
    if (next != null && next.isNotEmpty) return next.removeAt(0);
    return StreamStart.file(await ready(key, r));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
